import SwiftUI
import UserNotifications

@main struct AditApp: App {
  @StateObject private var store = Store()
  @StateObject private var motion = SurfaceMotion()
  @Environment(\.scenePhase) private var phase
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  init() { UNUserNotificationCenter.current().delegate = NotificationHandler.shared }
  var body: some Scene {
    WindowGroup {
      Shell().environmentObject(store).environmentObject(motion).preferredColorScheme(.light)
        .task(id: "\(phase)-\(reduceMotion)") {
          if phase == .active && !reduceMotion { motion.start() } else { motion.stop() }
        }
    }
  }
}
enum Destination: String, CaseIterable {
  case wall = "Station wall"
  case explore = "Explore"
  case profile = "Artist profile"
  var symbol: String {
    switch self {
    case .wall: "house"
    case .explore: "rectangle.topthird.inset.filled"
    case .profile: "person"
    }
  }
}
struct Selection: Identifiable {
  var id: String, art: Artwork, title: String, count: Int
  var carousel = false
}
struct Shell: View {
  @EnvironmentObject var store: Store
  @Environment(\.accessibilityReduceMotion) var reduce
  @State private var tab = Destination.wall
  @State private var selected: Selection?
  @State private var editing: Artwork?
  @State private var finished: Artwork?
  @State private var stationPicker = false
  @State private var launch = true
  @State private var stationPulse = 0
  @Namespace private var space
  var body: some View {
    ZStack {
      WallTiles().ignoresSafeArea()
      if let result = finished {
        ResultView(art: result, space: space) {
          withAnimation(reduce ? nil : .spring(response: 0.56, dampingFraction: 0.86)) {
            finished = nil
            tab = .wall
            stationPulse += 1
          }
        }
      } else {
        TabView(selection: $tab) {
          VStack(spacing: 0) {
            Button {
              stationPicker = true
            } label: {
              Sign(
                title: store.data.station == .grand
                  ? "Grand Central-42\nStreet Station" : store.data.station.rawValue)
            }.buttonStyle(.plain).accessibilityLabel("Choose station")
              .padding(.horizontal, 15).padding(.top, 14)
            WallView(
              space: space, pulse: stationPulse,
              rotating: selected == nil && editing == nil && tab == .wall, select: { selected = $0 }
            )
          }.background(WallTiles().ignoresSafeArea()).toolbar(.hidden, for: .tabBar).tag(
            Destination.wall
          ).tabItem {
            Label("Station wall", systemImage: "house")
          }
          ExploreView(select: { selected = $0 })
            .background(WallTiles().ignoresSafeArea())
            .toolbar(.hidden, for: .tabBar)
            .tag(Destination.explore).tabItem {
              Label("Explore", systemImage: "rectangle.topthird.inset.filled")
            }
          ProfileView(select: { selected = $0 }, resume: { editing = $0 })
            .background(WallTiles().ignoresSafeArea())
            .toolbar(.hidden, for: .tabBar)
            .tag(Destination.profile).tabItem { Label("Artist profile", systemImage: "person") }
        }
        .toolbar(.hidden, for: .tabBar)
        .safeAreaInset(edge: .bottom, spacing: 0) {
          NavigationPill(selection: $tab).padding(.top, 8).padding(.bottom, 6)
        }
      }
      if launch && !reduce {
        ZStack {
          Color.black.ignoresSafeArea()
          Image("routes").resizable().scaledToFill().opacity(0.64).ignoresSafeArea()
          VStack(alignment: .leading, spacing: 3) {
            Image("wordmark").resizable().scaledToFit().frame(width: 114)
            Text("Ad editing in transit").foregroundStyle(.white).font(.headline)
          }.padding(22).background(.black)
        }.transition(.opacity).accessibilityHidden(true)
      }
    }
    .task {
      try? await Task.sleep(for: .milliseconds(800))
      withAnimation(.easeOut(duration: 0.3)) { launch = false }
    }
    .sheet(item: $selected) { item in
      CampaignSheet(item: item) { art in
        var draft = art
        draft.id = UUID()
        draft.published = false
        draft.station = store.data.station
        draft.updated = Date()
        store.save(draft)
        selected = nil
        editing = draft
      }
    }
    .fullScreenCover(item: $editing) { art in
      EditorView(
        initial: art, onExit: { editing = nil },
        onPublish: { output in
          store.save(output)
          finished = output
          tab = .wall
          editing = nil
        })
    }
    .sheet(isPresented: $stationPicker) { StationSelector() }
    .alert(
      "Couldn’t save your library",
      isPresented: Binding(get: { store.error != nil }, set: { if !$0 { store.error = nil } })
    ) {
      Button("OK") { store.error = nil }
    } message: {
      Text(store.error ?? "")
    }
    .onReceive(NotificationCenter.default.publisher(for: .openNearbyAd)) { _ in
      tab = .wall
      let c = Campaign.all[0]
      selected = Selection(
        id: c.id,
        art: Artwork(campaign: c.id, base: c.id, ratio: c.ratio, station: store.data.station),
        title: c.name, count: c.count, carousel: true)
    }
  }
}
extension Notification.Name { static let openNearbyAd = Notification.Name("OpenNearbyAd") }
final class NotificationHandler: NSObject, UNUserNotificationCenterDelegate {
  static let shared = NotificationHandler()
  func userNotificationCenter(
    _ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    DispatchQueue.main.async {
      NotificationCenter.default.post(name: .openNearbyAd, object: nil)
      completionHandler()
    }
  }
  func userNotificationCenter(
    _ center: UNUserNotificationCenter, willPresent notification: UNNotification,
    withCompletionHandler done: @escaping (UNNotificationPresentationOptions) -> Void
  ) { done([.banner, .sound]) }
}
struct StationSelector: View {
  @EnvironmentObject var store: Store
  @Environment(\.dismiss) var dismiss
  @State private var notice = ""
  @AppStorage("liveTrainTimes") private var liveTimes = false
  var body: some View {
    NavigationStack {
      List {
        Section("6 train") {
          ForEach(Station.allCases, id: \.self) { s in
            Button {
              store.change { $0.station = s }
              dismiss()
            } label: {
              HStack {
                Circle().fill(Color.transitGreen).frame(width: 12, height: 12)
                Text(s.rawValue)
                Spacer()
                if store.data.station == s { Image(systemName: "checkmark") }
              }
            }
          }
        }
        Section("Train timing") {
          Toggle("Use live 6-train arrivals", isOn: $liveTimes)
          Text(
            liveTimes
              ? "Requests follow the next southbound train forecast by MTA. A preview ride is available when forecasts are unavailable."
              : "Use a 16-second preview ride while editing offline."
          ).font(.footnote).foregroundStyle(.secondary)
        }
        Section("Nearby invitation") {
          Button("Try a nearby-ad notification") { Task { await remind() } }
          Text(
            notice.isEmpty
              ? "Try the original nearby-ad invitation on this device." : notice
          ).font(.footnote).foregroundStyle(.secondary)
        }
      }.navigationTitle("Stations").toolbar { Button("Done") { dismiss() } }
    }.tint(.black).presentationDetents([.medium, .large])
  }
  func remind() async {
    let center = UNUserNotificationCenter.current()
    do {
      guard try await center.requestAuthorization(options: [.alert, .sound]) else {
        notice = "Enable notifications in Settings to try the invitation."
        return
      }
      let content = UNMutableNotificationContent()
      content.title = "adit"
      content.body = "596 people have reframed the friend ad near you. What’s your take?"
      try await center.add(
        UNNotificationRequest(
          identifier: "nearby-ad", content: content,
          trigger: UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)))
      notice = "Your local invitation arrives in five seconds."
    } catch { notice = error.localizedDescription }
  }
}
struct WallView: View {
  @EnvironmentObject var store: Store
  @Environment(\.accessibilityReduceMotion) var reduce
  @Environment(\.scenePhase) private var scenePhase
  let space: Namespace.ID, pulse: Int
  let rotating: Bool
  let select: (Selection) -> Void
  @State private var entered = false
  @State private var alternate = false
  var local: [Artwork] {
    store.data.documents.filter { $0.published && $0.station == store.data.station }.sorted {
      $0.updated > $1.updated
    }
  }
  var olderPosts: [Artwork] {
    let displayed = Set(
      campaigns.compactMap { campaign in local.first(where: { $0.campaign == campaign.id })?.id })
    return local.filter { !displayed.contains($0.id) }
  }
  var campaigns: [Campaign] {
    let offset = Station.allCases.firstIndex(of: store.data.station) ?? 0
    return Array(Campaign.all[offset...]) + Array(Campaign.all.prefix(offset))
  }
  var body: some View {
    GeometryReader { geo in
      let width = geo.size.width
      VStack(spacing: 0) {
        Text("Latest Local Reframes").font(.custom("HelveticaNeue-Medium", size: 16))
          .foregroundStyle(.secondary).padding(.top, 30).padding(.bottom, 14)
        ScrollView {
          VStack(spacing: 0) {
            ZStack(alignment: .topLeading) {
              ForEach(Array(campaigns.enumerated()), id: \.element.id) { i, c in
                let doc = local.first(where: { $0.campaign == c.id })
                let variant = alternate && c.variants.count == 2 ? c.variants[1] : c.id
                let art =
                  doc
                  ?? Artwork(
                    campaign: c.id, base: variant, ratio: c.ratio, station: store.data.station)
                let count = c.count + local.filter { $0.campaign == c.id }.count
                Button {
                  select(
                    Selection(
                      id: doc?.id.uuidString ?? c.id, art: art, title: c.name, count: count,
                      carousel: doc == nil))
                } label: {
                  ZStack(alignment: i == 0 ? .topTrailing : .bottomLeading) {
                    MetalFrame {
                      ZStack {
                        ArtworkSurface(art: art).id(art.base)
                          .transition(
                            reduce
                              ? .identity
                              : .asymmetric(
                                insertion: .move(edge: .bottom), removal: .move(edge: .top)))
                      }.aspectRatio(art.ratio, contentMode: .fit).clipped()
                    }
                    HStack(spacing: 3) {
                      Image("reframe").renderingMode(.template).resizable().frame(
                        width: 16, height: 16)
                      Text("\(count)")
                    }.font(.system(size: 15, weight: .semibold))
                      .foregroundStyle(i == 1 ? .black : .white).padding(.horizontal, 7).padding(
                        .vertical, 3
                      )
                      .background(
                        [Color.orange, Color.yellow, .transitGreen, .blue][i], in: Capsule()
                      )
                      .offset(x: i == 0 ? 10 : -3, y: i == 0 ? -10 : 8)
                  }.matchedGeometryEffect(id: doc?.id.uuidString ?? c.id, in: space)
                }.buttonStyle(.plain)
                  .frame(
                    width: width * [0.49, 0.4, 0.39, 0.455][i],
                    height: (width * [0.49, 0.4, 0.39, 0.455][i] - 12) / c.ratio + 12
                  )
                  .contentShape(Rectangle())
                  .accessibilityElement(children: .ignore)
                  .accessibilityAddTraits(.isButton)
                  .rotationEffect(.degrees([-7, 9, -5.5, 7.5][i]))
                  .position(
                    x: width * [0.31, 0.72, 0.27, 0.69][i],
                    y: width * [0.25, 0.552, 0.897, 1.24][i]
                  )
                  .opacity(entered ? 1 : 0).offset(y: entered ? 0 : 19)
                  .animation(
                    reduce ? nil : .spring(duration: 0.45).delay(Double(i) * 0.09), value: entered
                  )
                  .accessibilityLabel("\(c.name), \(count) reframes")
                  .accessibilityValue(art.base)
              }
            }.frame(width: width, height: width * 1.56)
            if !olderPosts.isEmpty {
              ForEach(olderPosts) { art in
                Button {
                  select(
                    Selection(
                      id: art.id.uuidString, art: art, title: Campaign.get(art.campaign).name,
                      count: 0)
                  )
                } label: {
                  MetalFrame { ArtworkSurface(art: art) }.frame(width: width * 0.6).padding(12)
                }
              }
            }
            Color.clear.frame(height: 65)
          }
        }.scrollIndicators(.hidden)
      }
    }.onAppear { entered = true }
      .task(id: "\(store.data.station.rawValue)-\(scenePhase)-\(reduce)-\(rotating)") {
        guard !reduce, scenePhase == .active, rotating else { return }
        while !Task.isCancelled {
          do { try await Task.sleep(for: .seconds(7)) } catch { return }
          withAnimation(.timingCurve(0.65, 0, 0.25, 1, duration: 0.85)) { alternate.toggle() }
        }
      }
  }
}
struct CampaignSheet: View {
  @EnvironmentObject var store: Store
  var item: Selection
  let begin: (Artwork) -> Void
  @State private var index = 0
  var variants: [String] {
    item.carousel ? Campaign.get(item.art.campaign).variants : [item.art.base]
  }
  var current: Artwork {
    var art = item.art
    if item.carousel {
      art.base = variants[index]
      art.ratio =
        art.base == "wide"
        ? 1.94 : (art.base == "pendantPoster" ? 0.68 : Campaign.get(art.campaign).ratio)
    }
    return art
  }
  var body: some View {
    VStack(spacing: 15) {
      HStack {
        Text(item.title)
        Spacer()
        Label {
          Text("\(item.count) reframes")
        } icon: {
          Image("reframe").resizable().frame(width: 16, height: 16)
        }
      }.font(.system(size: 16, weight: .medium)).padding(.horizontal, 22).padding(.top, 27)
      TabView(selection: $index) {
        ForEach(variants.indices, id: \.self) { i in
          var art: Artwork {
            var a = item.art
            a.base = variants[i]
            a.ratio = a.base == "wide" ? 1.94 : a.base == "pendantPoster" ? 0.68 : item.art.ratio
            return a
          }
          ArtworkSurface(art: art).padding(4).background(.gray).frame(maxHeight: 200).padding(10)
            .tag(i)
        }
      }.tabViewStyle(.page(indexDisplayMode: .never)).frame(height: 225)
      if variants.count > 1 {
        HStack(spacing: 6) {
          ForEach(variants.indices, id: \.self) { i in
            Circle().fill(index == i ? .black : .gray.opacity(0.3)).frame(width: 5, height: 5)
          }
        }
      }
      HStack {
        Button {
          store.toggleSave(current, key: item.id)
        } label: {
          Image(systemName: store.data.saved.contains(item.id) ? "bookmark.fill" : "bookmark")
            .frame(width: 45, height: 45)
        }.accessibilityLabel("Save poster")
        BlackButton(title: "Reframe") { begin(current) }
      }.padding(.horizontal)
    }.padding(.bottom, 12).foregroundStyle(.black).presentationDragIndicator(.visible)
      .presentationCornerRadius(36)
      .presentationDetents([.height(385)]).onAppear {
        index = variants.firstIndex(of: item.art.base) ?? 0
      }
  }
}
struct ResultView: View {
  @EnvironmentObject var store: Store
  let art: Artwork, space: Namespace.ID, done: () -> Void
  @State private var share: UIImage?
  var body: some View {
    VStack(spacing: 18) {
      Sign(title: art.station == .grand ? "Grand Central-42\nStreet Station" : art.station.rawValue)
        .padding(.horizontal, 15).padding(.top, 14)
      HStack {
        Text("\(Campaign.get(art.campaign).name) reframe by \(store.data.handle)").font(.caption)
          .foregroundStyle(.secondary)
        Button {
          share = shareImage(art)
        } label: {
          Image(systemName: "square.and.arrow.up")
        }.accessibilityLabel("Share artwork")
      }
      Spacer().frame(maxHeight: 65)
      MetalFrame { ArtworkSurface(art: art) }.matchedGeometryEffect(
        id: art.id.uuidString, in: space
      ).padding(.horizontal, 16)
      Spacer()
      BlackButton(title: "Reframe", action: done).padding(.horizontal)
    }.padding(.bottom, 8).tint(.black).sheet(
      isPresented: Binding(get: { share != nil }, set: { if !$0 { share = nil } })
    ) { if let share { SharePanel(image: share) } }
  }
}

struct NavigationPill: View {
  @Binding var selection: Destination
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Namespace private var highlight
  private let segmentWidth: CGFloat = 76

  var body: some View {
    HStack(spacing: 0) {
      ForEach(Destination.allCases, id: \.self) { destination in
        Button {
          selection = destination
        } label: {
          Image(systemName: destination.symbol)
            .font(.system(size: 22, weight: selection == destination ? .semibold : .regular))
            .foregroundStyle(selection == destination ? .primary : .secondary)
            .frame(width: segmentWidth, height: 48)
            .background {
              if selection == destination {
                Capsule().fill(.white.opacity(0.6))
                  .overlay { Capsule().strokeBorder(.white.opacity(0.65), lineWidth: 0.5) }
                  .matchedGeometryEffect(id: "selection", in: highlight)
              }
            }
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(destination.rawValue)
        .accessibilityAddTraits(selection == destination ? .isSelected : [])
      }
    }
    .padding(5)
    .modifier(NavigationGlass())
    .animation(
      reduceMotion ? nil : .spring(response: 0.32, dampingFraction: 0.82), value: selection
    )
    .simultaneousGesture(
      DragGesture(minimumDistance: 8).onChanged { value in
        let index = min(2, max(0, Int((value.location.x - 5) / segmentWidth)))
        let destination = Destination.allCases[index]
        if selection != destination { selection = destination }
      }
    )
    .accessibilityElement(children: .contain)
    .accessibilityIdentifier("navigationPill")
  }
}

private struct NavigationGlass: ViewModifier {
  @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

  @ViewBuilder func body(content: Content) -> some View {
    if reduceTransparency {
      content.background(Color(.systemBackground), in: Capsule())
        .overlay { Capsule().strokeBorder(Color(.separator), lineWidth: 0.5) }
    } else if #available(iOS 26.0, *) {
      content.glassEffect(.regular.interactive(), in: Capsule())
    } else {
      content.background(.ultraThinMaterial, in: Capsule())
        .overlay { Capsule().strokeBorder(.white.opacity(0.75), lineWidth: 0.7) }
        .shadow(color: .black.opacity(0.12), radius: 12, y: 5)
    }
  }
}
