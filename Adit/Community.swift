import SwiftUI

private let awardIcons = ["trophy.fill", "flame.fill", "skull"]
private let awardTints = [Color(hex: "FFC900"), Color(hex: "F13630"), Color(hex: "0039AB")]
struct Award: View {
  var index: Int
  var size: CGFloat = 36
  var body: some View {
    ZStack {
      Circle().fill(awardTints[index])
      if index == 2 {
        Skull().fill(.white).frame(width: size * 0.47, height: size * 0.49)
      } else {
        Image(systemName: awardIcons[index]).font(.system(size: size * 0.43, weight: .bold))
          .foregroundStyle(index == 0 ? .black : .white)
      }
    }.frame(width: size, height: size)
  }
}
private struct Skull: Shape {
  func path(in r: CGRect) -> Path {
    let w = r.width
    let h = r.height
    var p = Path()
    p.addEllipse(in: CGRect(x: 0, y: 0, width: w, height: h * 0.78))
    for i in 0..<3 {
      p.addRoundedRect(
        in: CGRect(x: w * (0.17 + Double(i) * 0.23), y: h * 0.58, width: w * 0.17, height: h * 0.4),
        cornerSize: CGSize(width: 1, height: 1))
    }
    for x in [0.16, 0.58] {
      p.addPath(
        Path(ellipseIn: CGRect(x: w * x, y: h * 0.33, width: w * 0.25, height: h * 0.24))
          .reversedPath)
    }
    return p
  }
}
extension Path {
  fileprivate var reversedPath: Path { Path(UIBezierPath(cgPath: cgPath).reversing().cgPath) }
}
struct ExploreView: View {
  @EnvironmentObject var store: Store
  let select: (Selection) -> Void
  @State private var showInfo = false
  var body: some View {
    VStack(spacing: 0) {
      Button {
        showInfo = true
      } label: {
        Sign(title: "Explore", badge: "adit", tint: Color(hex: "FF6810"))
      }.buttonStyle(.plain).padding(.horizontal, 15).padding(.top, 14)
      ScrollView {
        GeometryReader { g in
          let w = g.size.width
          ZStack {
            ForEach(Array(Entry.awards.enumerated()), id: \.element.id) { i, e in
              Button {
                open(e)
              } label: {
                VStack(alignment: .leading, spacing: 4) {
                  Text(e.author).font(.system(size: 15, weight: .medium))
                  ZStack(alignment: .topTrailing) {
                    PosterFace(asset: e.asset).aspectRatio(e.ratio, contentMode: .fit).padding(5.5)
                      .background(
                        LinearGradient(
                          colors: [
                            Color(hex: "BBA347"), Color(hex: "EBD987"), Color(hex: "987F3F"),
                          ], startPoint: .topLeading, endPoint: .bottomTrailing)
                      )
                      .shadow(color: .black.opacity(0.33), radius: 6, y: 7)
                    Award(index: [0, 2, 1][i], size: 36).offset(x: 9, y: -14)
                  }
                }.frame(width: w * [0.49, 0.38, 0.43][i])
              }.buttonStyle(.plain).rotationEffect(.degrees([-2.5, 4, -3][i]))
                .position(x: w * [0.29, 0.74, 0.305][i], y: w * [0.29, 0.51, 0.86][i])
            }
          }
        }.aspectRatio(0.81, contentMode: .fit)
        Text("Latest Adits").font(.headline).padding(.vertical, 16)
        LazyVStack(spacing: 14) {
          ForEach(store.data.documents.filter(\.published).sorted { $0.updated > $1.updated }) {
            art in
            feedRow(art: art, key: art.id.uuidString, user: store.data.handle, count: 0)
          }
          ForEach(Entry.feed) { entry in
            feedRow(art: store.art(entry), key: entry.id, user: entry.author, count: entry.count)
          }
        }.padding(.horizontal, 12)
        Color.clear.frame(height: 86)
      }.scrollIndicators(.hidden)
    }.alert("adit", isPresented: $showInfo) {
      Button("Done") {}
    } message: {
      Text(
        "Ad editing in transit. Explore the original community examples and the reframes published on this device."
      )
    }
  }
  func open(_ e: Entry) {
    select(Selection(id: e.id, art: store.art(e), title: e.author, count: e.count))
  }
  func feedRow(art: Artwork, key: String, user: String, count: Int) -> some View {
    VStack(alignment: .leading, spacing: 0) {
      HStack {
        if let avatar = [
          "svsd.fan": "fanAvatar", "nabubu_enthusiast": "nabubuAvatar",
          "ZZZzzzZZz": "sandwichAvatar", "aNticapitAlist": "cameraAvatar",
          "whereissvsdmerch": "heardAvatar",
        ][user] {
          Image(avatar).resizable().scaledToFill().frame(width: 24, height: 24).clipShape(Circle())
        } else {
          Circle().fill(awardTints[user.count % 3]).frame(width: 24, height: 24).overlay {
            Text(String(user.prefix(1)).uppercased()).font(.caption.bold()).foregroundStyle(.white)
          }
        }
        Text(user).font(.subheadline.weight(.medium))
        Spacer()
        Label("\(count)", systemImage: "repeat").font(.caption.bold())
      }.padding(9)
      Button {
        select(Selection(id: key, art: art, title: user, count: count))
      } label: {
        ArtworkSurface(art: art)
      }.accessibilityLabel("Open art by \(user)")
      HStack {
        ForEach([0, 2], id: \.self) { i in
          let vote = i == 0 ? "fame" : "cray"
          let active = store.data.votes[key] == vote
          Button {
            store.toggleVote(vote, for: key)
          } label: {
            if active {
              Award(index: i, size: 31)
            } else {
              Group {
                if i == 0 {
                  Image(systemName: "trophy")
                } else {
                  Skull().fill(.primary).frame(width: 14, height: 15)
                }
              }.frame(width: 31, height: 31).background(Color(white: 0.95), in: Circle())
            }
          }.accessibilityLabel(i == 0 ? "Vote hall of fame" : "Vote hall of cray")
            .accessibilityValue(active ? "Selected" : "Unselected")
        }
        Spacer()
        Button {
          store.toggleSave(art, key: key)
        } label: {
          Image(systemName: store.data.saved.contains(key) ? "bookmark.fill" : "bookmark").frame(
            width: 40, height: 36)
        }.accessibilityLabel("Save \(user) poster")
      }.padding(6)
    }.buttonStyle(.plain).background(.white)
  }
}
struct ProfileView: View {
  @EnvironmentObject var store: Store
  let select: (Selection) -> Void, resume: (Artwork) -> Void
  enum Page: String, CaseIterable {
    case adits = "Adits"
    case drafts = "Drafts"
    case saved = "Saved"
  }
  @State private var page = Page.adits
  @State private var editing = false
  @State private var handle = ""
  @State private var removal: Artwork?
  var published: [Artwork] {
    store.data.documents.filter(\.published).sorted { $0.updated > $1.updated }
  }
  var drafts: [Artwork] {
    store.data.documents.filter { !$0.published }.sorted { $0.updated > $1.updated }
  }
  var votes: Int {
    store.data.votes.filter { key, _ in published.contains { $0.id.uuidString == key } }.count
  }
  var body: some View {
    VStack(spacing: 0) {
      Button {
        handle = store.data.handle
        editing = true
      } label: {
        HStack {
          Text(store.data.handle).font(.title3.bold())
          Image(systemName: "pencil").font(.caption)
          Spacer()
          Image("artistTag").resizable().scaledToFit().frame(width: 114, height: 48)
            .accessibilityHidden(true)
        }.padding(.horizontal, 11).padding(.vertical, 3).frame(minHeight: 54).background(.white)
          .overlay(alignment: .top) {
            Rectangle().fill(.black).frame(height: 1)
          }.overlay(alignment: .bottom) { Rectangle().fill(.black).frame(height: 1) }.shadow(
            color: .black.opacity(0.2), radius: 6, y: 6)
      }.buttonStyle(.plain).accessibilityLabel("Edit artist name").padding(.horizontal, 15).padding(
        .top, 14)
      ScrollView {
        HStack(spacing: 12) {
          ForEach(0..<3) { i in
            Award(index: i, size: 46).overlay(alignment: .topTrailing) {
              Text(["3", "2", "5"][i]).font(.caption2.bold()).padding(5).background(
                awardTints[i].opacity(0.25), in: Circle()
              ).offset(x: 6, y: -5)
            }
          }
        }.padding(.top, 43)
        HStack(spacing: 26) {
          stat(56 + published.count, "adits")
          stat(583 + votes, "votes")
          stat(23 + published.filter { !Campaign.all.map(\.id).contains($0.base) }.count, "remixes")
        }.padding(.top, 8)
        Picker("Collection", selection: $page) {
          ForEach(Page.allCases, id: \.self) { p in Text(p.rawValue).tag(p) }
        }.pickerStyle(.segmented).padding(.horizontal, 20).padding(.vertical, 20)
        switch page {
        case .adits:
          ForEach(published) { art in card(art, key: art.id.uuidString, title: store.data.handle) }
          HStack(alignment: .top, spacing: 12) {
            profileSample("nabubu", index: 2).rotationEffect(.degrees(-5))
            profileSample("lion", index: nil).rotationEffect(.degrees(4)).padding(.top, 96)
          }.padding(.horizontal, 15)
        case .drafts:
          if drafts.isEmpty {
            ContentUnavailableView(
              "No drafts yet", systemImage: "pencil",
              description: Text("Start a reframe on the station wall."))
          }
          ForEach(drafts) { art in
            VStack(alignment: .leading) {
              Button {
                resume(art)
              } label: {
                MetalFrame { ArtworkSurface(art: art) }.frame(height: 210)
                  .contentShape(Rectangle())
              }.accessibilityLabel("Resume draft")
              HStack {
                Text(Campaign.get(art.campaign).name).font(.caption)
                Spacer()
                Button {
                  removal = art
                } label: {
                  Image(systemName: "trash").frame(width: 44, height: 44).contentShape(Rectangle())
                }.accessibilityLabel("Delete draft")
              }
            }.padding(.horizontal, 32).padding(.bottom, 16)
          }
        case .saved:
          if store.data.savedEntries.isEmpty {
            ContentUnavailableView(
              "No saved posters", systemImage: "bookmark",
              description: Text("Bookmark a poster to keep it here."))
          }
          ForEach(store.data.savedEntries.keys.sorted(), id: \.self) { key in
            if let art = store.data.savedEntries[key] {
              card(art, key: key, title: "Saved reframe")
            }
          }
        }
        Color.clear.frame(height: 88)
      }.scrollIndicators(.hidden)
    }.buttonStyle(.plain).alert("Artist name", isPresented: $editing) {
      TextField("Name", text: $handle)
      Button("Cancel", role: .cancel) {}
      Button("Save") {
        let value = String(handle.trimmingCharacters(in: .whitespacesAndNewlines).prefix(30))
        if !value.isEmpty { store.change { $0.handle = value } }
      }.disabled(handle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }
    .confirmationDialog(
      "Delete this draft?",
      isPresented: Binding(get: { removal != nil }, set: { if !$0 { removal = nil } })
    ) {
      Button("Delete draft", role: .destructive) {
        let id = removal?.id
        store.change { $0.documents.removeAll { $0.id == id && !$0.published } }
        removal = nil
      }
    }
  }
  func stat(_ n: Int, _ title: String) -> some View {
    VStack(spacing: 0) {
      Text("\(n)").font(.system(size: 38, weight: .semibold)).tracking(-1.8)
      Text(title).font(.subheadline).foregroundStyle(.secondary)
    }
  }
  func card(_ art: Artwork, key: String, title: String) -> some View {
    Button {
      select(Selection(id: key, art: art, title: title, count: 0))
    } label: {
      MetalFrame { ArtworkSurface(art: art) }.frame(maxHeight: 215).padding(12)
    }.accessibilityLabel("Open \(title)")
  }
  func profileSample(_ name: String, index: Int?) -> some View {
    let art = Artwork(campaign: "friend", base: name, ratio: 0.91, station: .grand)
    return Button {
      select(
        Selection(id: name, art: art, title: store.data.handle, count: name == "lion" ? 23 : 17))
    } label: {
      MetalFrame { ArtworkSurface(art: art) }.overlay(alignment: .topTrailing) {
        if let index { Award(index: index, size: 32).offset(x: 4, y: -9) }
      }
    }.accessibilityLabel("Open \(name) poster")
  }
}
