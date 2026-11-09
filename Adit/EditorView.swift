import SwiftUI

private enum Tool: String, CaseIterable {
  case magic = "AI brush"
  case assets = "Asset library"
  case type = "Add text"
  case ink = "Brush"
  var icon: String {
    switch self {
    case .magic: "paintbrush.pointed"
    case .assets: "photo"
    case .type: "textformat"
    case .ink: "scribble.variable"
    }
  }
}
struct EditorView: View {
  @EnvironmentObject var store: Store
  @State private var art: Artwork
  @State private var tool = Tool.magic
  @State private var undoStack: [[Layer]] = []
  @State private var redoStack: [[Layer]] = []
  @State private var trace: [Point] = []
  @State private var selection: Region?
  @State private var selected: UUID?
  @State private var color = "111111"
  @State private var thickness = 0.012
  @State private var prompt = ""
  @State private var textValue = ""
  @State private var typeSize = 0.13
  @State private var serif = true
  @State private var backing = false
  @State private var replaceHeadline = false
  @State private var typing = false
  @State private var assetShelf = false
  @State private var help = false
  @State private var replacing: UUID?
  @State private var startLayers: [Layer]?
  @State private var moving: UUID?
  @State private var now = Date()
  @State private var tripStart = Date()
  @AppStorage("liveTrainTimes") private var liveTimes = false
  @State private var prediction: TrainWindow?
  @State private var checkingTrain = false
  var liveRide: TrainWindow? {
    guard let prediction, prediction.arrive > now else { return nil }
    return prediction
  }
  @FocusState private var promptFocused: Bool
  let onExit: () -> Void, onPublish: (Artwork) -> Void
  init(initial: Artwork, onExit: @escaping () -> Void, onPublish: @escaping (Artwork) -> Void) {
    _art = State(initialValue: initial)
    self.onExit = onExit
    self.onPublish = onPublish
  }
  var campaign: Campaign { Campaign.get(art.campaign) }
  var pending: [Layer] { art.layers.filter { $0.pending(at: now) } }
  var activeJob: Layer? {
    pending.sorted { ($0.started ?? .distantPast) < ($1.started ?? .distantPast) }.first
  }
  var body: some View {
    VStack(spacing: 0) {
      train.padding(.horizontal, 16).padding(.top, 9)
      HStack(spacing: 13) {
        Button {
          save()
          onExit()
        } label: {
          Image(systemName: "chevron.left")
        }.accessibilityLabel("Save draft and close")
        Spacer()
        Button {
          undo()
        } label: {
          Image(systemName: "arrow.uturn.backward")
        }.disabled(undoStack.isEmpty).accessibilityLabel("Undo")
        Button {
          redo()
        } label: {
          Image(systemName: "arrow.uturn.forward")
        }.disabled(redoStack.isEmpty).accessibilityLabel("Redo")
        Button("Finish") {
          art.published = true
          art.updated = Date()
          onPublish(art)
        }.font(.system(size: 13, weight: .semibold)).foregroundStyle(.white).padding(
          .horizontal, 14
        ).padding(.vertical, 7).background(.black, in: Capsule()).disabled(!pending.isEmpty)
          .opacity(pending.isEmpty ? 1 : 0.35)
      }.padding(.horizontal, 16).frame(height: 44)
      GeometryReader { g in
        let width = min(g.size.width - 28, max(90, (g.size.height - 30) * art.ratio))
        let h = width / art.ratio
        VStack(spacing: 0) {
          Spacer(minLength: 0)
          ZStack {
            ArtworkSurface(art: art, now: now).shadow(color: .black.opacity(0.18), radius: 7, y: 5)
            if moving != nil {
              Canvas { context, bounds in
                var grid = Path()
                for division in 1...3 {
                  let fraction = CGFloat(division) / 4
                  grid.move(to: CGPoint(x: bounds.width * fraction, y: 0))
                  grid.addLine(to: CGPoint(x: bounds.width * fraction, y: bounds.height))
                  grid.move(to: CGPoint(x: 0, y: bounds.height * fraction))
                  grid.addLine(to: CGPoint(x: bounds.width, y: bounds.height * fraction))
                }
                context.stroke(
                  grid, with: .color(.gray.opacity(0.5)),
                  style: StrokeStyle(lineWidth: 0.7, dash: [2, 2]))
              }.allowsHitTesting(false)
            }
            if selection != nil { Color.white.opacity(0.66) }
            if !trace.isEmpty {
              Path { p in
                p.move(to: trace[0].at(CGSize(width: width, height: h)))
                for point in trace.dropFirst() {
                  p.addLine(to: point.at(CGSize(width: width, height: h)))
                }
              }.stroke(
                tool == .ink ? Color(hex: color) : .indigo,
                style: StrokeStyle(
                  lineWidth: tool == .ink ? width * thickness : 1.6, lineCap: .round,
                  lineJoin: .round, dash: tool == .ink ? [] : [4, 3]))
            }
            if let r = selection {
              Ellipse().stroke(.indigo, style: StrokeStyle(lineWidth: 2, dash: [5, 4])).frame(
                width: r.w * width, height: r.h * h
              ).position(x: r.x * width, y: r.y * h)
            }
            if let l = art.layers.first(where: { $0.id == selected && $0.kind != .ink }) {
              RoundedRectangle(cornerRadius: 4).strokeBorder(
                .indigo, style: StrokeStyle(lineWidth: 1, dash: [3, 3])
              )
              .frame(width: layerWidth(l) * width, height: layerHeight(l) * h)
              .position(l.position.at(CGSize(width: width, height: h)))
            }
          }.frame(width: width, height: h).contentShape(Rectangle())
            .gesture(canvasGesture(CGSize(width: width, height: h))).accessibilityElement(
              children: .ignore
            ).accessibilityLabel("Poster canvas").accessibilityIdentifier("canvas")
          Spacer(minLength: 0)
        }.frame(maxWidth: .infinity)
      }
      if selection != nil {
        HStack {
          Button {
            cancelRequest()
          } label: {
            Image(systemName: "xmark.circle.fill")
          }.accessibilityLabel("Cancel prompt")
          if #available(iOS 18.2, *), let selection {
            GenerateAssetButton(prompt: prompt, region: selection, art: art) { asset in
              queue(asset: asset)
            }
          }
          TextField("Describe an asset…", text: $prompt).focused($promptFocused).onSubmit {
            queue()
          }
          Button {
            queue()
          } label: {
            Image(systemName: "arrow.up.circle.fill").font(.title).foregroundStyle(.indigo)
          }.disabled(prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .accessibilityLabel("Queue prompt")
        }.padding().background(.white).shadow(radius: 3)
      } else {
        HStack(alignment: .center) {
          Text(status).font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(2)
          Spacer()
          Button {
            help = true
          } label: {
            Image(systemName: "questionmark.circle").padding(8)
          }.accessibilityLabel("Editor help")
        }.padding(.horizontal, 13)
        if let l = art.layers.first(where: { $0.id == selected && $0.kind != .ink }) {
          layerControls(l)
        }
        if assetShelf { shelf }
        if tool == .ink { brushControls }
        HStack(spacing: 0) {
          ForEach(Tool.allCases, id: \.self) { t in
            Button {
              choose(t)
            } label: {
              Image(systemName: t.icon).font(.system(size: 22, weight: .medium)).frame(
                maxWidth: .infinity
              ).frame(height: 53).foregroundStyle(tool == t ? .white : Color(white: 0.58))
            }.accessibilityLabel(t.rawValue).accessibilityAddTraits(tool == t ? .isSelected : [])
          }
        }.background(Color(white: 0.10).ignoresSafeArea(edges: .bottom))
      }
    }.background(Color(white: 0.985)).tint(.black).onAppear {
      tripStart = activeJob?.started ?? Date()
    }
    .task {
      while !Task.isCancelled {
        now = Date()
        do { try await Task.sleep(for: .milliseconds(180)) } catch { return }
      }
    }
    .task(id: liveTimes) {
      guard liveTimes else { return }
      let stops = art.station.nextStop
      while !Task.isCancelled {
        checkingTrain = true
        do { prediction = try await TrainWindow.load(from: stops.from, to: stops.to) } catch {
          if prediction?.arrive ?? .distantPast < Date() { prediction = nil }
        }
        checkingTrain = false
        do { try await Task.sleep(for: .seconds(60)) } catch { return }
      }
    }
    .sheet(isPresented: $typing) { textForm }
    .alert("Editing in transit", isPresented: $help) {
      Button("Got it") {}
    } message: {
      Text(
        "Circle an area with the AI brush, then describe an asset. The local generator uses bundled artwork and illustrated or typographic stamps. Choose preview or live MTA timing from the station sign. Draw, add text, or place assets while you wait. Tap a placed layer to move, resize or remove it."
      )
    }
  }
  var status: String {
    if let departure = activeJob?.started, departure > now {
      return "Queued for departure · " + departure.formatted(date: .omitted, time: .shortened)
    }
    if !pending.isEmpty {
      return
        "Creating \(pending.count == 1 ? "your asset" : "\(pending.count) assets") · Keep editing until the next stop"
    }
    if moving != nil { return "Drag into place · Snap to center" }
    return switch tool {
    case .magic: "Circle an object to generate an asset"
    case .ink: "Draw on your poster"
    case .type: "Tap a text layer to edit it"
    case .assets: "Tap an asset, then drag it into place"
    }
  }
  var train: some View {
    let start = activeJob?.started ?? liveRide?.depart ?? tripStart
    let end = activeJob?.due ?? liveRide?.arrive ?? start.addingTimeInterval(16)
    let progress = min(
      1, max(0, now.timeIntervalSince(start) / max(1, end.timeIntervalSince(start))))
    return VStack(spacing: 3) {
      GeometryReader { geo in
        ZStack(alignment: .leading) {
          Capsule().fill(Color(white: 0.93)).frame(height: 6)
          Capsule().fill(Color.transitGreen).frame(
            width: max(12, geo.size.width * progress), height: 6)
          Image("train").resizable().frame(width: 29, height: 13).offset(
            x: min(geo.size.width - 29, max(0, geo.size.width * progress - 27)), y: -9)
        }.frame(maxHeight: .infinity, alignment: .bottom)
      }.frame(height: 21)
      HStack {
        Text(art.station.short)
        Spacer()
        if liveTimes {
          Text(
            checkingTrain
              ? "Checking MTA…"
              : (activeJob?.liveTiming ?? (liveRide != nil)) ? "Live MTA" : "Offline preview"
          )
          .font(.system(size: 9)).foregroundStyle(.secondary)
          Spacer()
        }
        Text(art.station.nextStop.name).foregroundStyle(.secondary)
      }.font(.system(size: 10, weight: .bold))
    }.accessibilityLabel("Train from \(art.station.short) to \(art.station.nextStop.name)")
  }
  var shelf: some View {
    VStack(alignment: .leading, spacing: 7) {
      let originals =
        art.campaign == "friend"
        ? ["necklace", "pendant", "wide"] : [art.base] + campaign.variants.filter { $0 != art.base }
      assetRow("Original Assets", originals)
      assetRow("User Generated", ["joe", "YOU", "beer", "camera"])
      if !finishedPrompts.isEmpty {
        Text("Your assets").font(.caption)
        ScrollView(.horizontal, showsIndicators: false) {
          HStack {
            ForEach(finishedPrompts) { source in
              Button {
                var layer = Layer(kind: .request)
                layer.value = source.value
                layer.generatedAsset = source.generatedAsset
                layer.size = 0.26
                layer.height = 0.26 * art.ratio
                append(layer)
                selected = layer.id
                assetShelf = false
              } label: {
                LocalResult(prompt: source.value, asset: source.generatedAsset).frame(
                  width: 44, height: 44
                ).clipShape(Circle())
              }.accessibilityLabel("Place generated asset " + source.value)
            }
          }
        }
      }
    }.padding(12).background(Color(white: 0.94)).transition(
      .move(edge: .bottom).combined(with: .opacity))
  }
  var finishedPrompts: [Layer] {
    var seen = Set<String>()
    return store.data.documents.flatMap(\.layers).filter { layer in
      layer.kind == .request && !layer.pending(at: now)
        && seen.insert(layer.generatedAsset?.uuidString ?? layer.value).inserted
    }
  }
  func assetRow(_ name: String, _ assets: [String]) -> some View {
    VStack(alignment: .leading, spacing: 3) {
      Text(name).font(.caption)
      ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: 20) {
          ForEach(assets, id: \.self) { s in
            Button {
              var layer = Layer(kind: .asset)
              layer.value = s
              layer.size = 0.28
              append(layer)
              assetShelf = false
              selected = layer.id
            } label: {
              if s == "YOU" {
                Text("YOU").font(.system(size: 29, design: .serif)).frame(width: 67, height: 48)
              } else {
                if s == "joe" {
                  Image(s).resizable().scaledToFill().frame(width: 48, height: 48).clipShape(
                    Circle()
                  ).frame(width: 67)
                } else {
                  Image(s).resizable().scaledToFit().frame(width: 67, height: 48)
                }
              }
            }.accessibilityLabel("Place \(s)")
          }
        }
      }
    }
  }
  var brushControls: some View {
    VStack(spacing: 5) {
      HStack {
        Image(systemName: "pencil.tip")
        Slider(value: $thickness, in: 0.004...0.055).accessibilityLabel("Brush width")
      }.padding(.horizontal)
      HStack(spacing: 7) {
        ColorPicker(
          "Custom ink", selection: Binding(get: { Color(hex: color) }, set: { color = $0.rgbHex }),
          supportsOpacity: false
        ).labelsHidden()
        ForEach(campaign.palette, id: \.self) { c in
          Button {
            color = c
          } label: {
            RoundedRectangle(cornerRadius: 5).fill(Color(hex: c)).frame(maxWidth: .infinity).frame(
              height: 22
            ).overlay {
              RoundedRectangle(cornerRadius: 5).stroke(
                color == c ? .indigo : .gray.opacity(0.2), lineWidth: color == c ? 2 : 1)
            }
          }.accessibilityLabel("Ink \(c)")
        }
      }.padding(.horizontal, 12).padding(.bottom, 5)
    }.background(.white)
  }
  func layerControls(_ layer: Layer) -> some View {
    HStack(spacing: 19) {
      Button {
        adjust(layer, scale: 0.85)
      } label: {
        Image(systemName: "minus.magnifyingglass")
      }.accessibilityLabel("Shrink layer")
      Button {
        adjust(layer, scale: 1.15)
      } label: {
        Image(systemName: "plus.magnifyingglass")
      }.accessibilityLabel("Enlarge layer")
      Button {
        modify(layer.id) { $0.rotation += 15 }
      } label: {
        Image(systemName: "rotate.right")
      }.accessibilityLabel("Rotate layer")
      if layer.kind == .text {
        Button {
          openType(layer)
        } label: {
          Image(systemName: "pencil")
        }.accessibilityLabel("Edit text")
      }
      Button {
        checkpoint()
        art.layers.removeAll { $0.id == layer.id }
        selected = nil
        save()
      } label: {
        Image(systemName: "trash")
      }.accessibilityLabel("Delete layer")
      Spacer()
      Button("Done") { selected = nil }
    }.font(.subheadline).padding(.horizontal).frame(height: 40)
  }
  var textForm: some View {
    NavigationStack {
      Form {
        TextField("Your text", text: $textValue, axis: .vertical).accessibilityIdentifier(
          "typeInput")
        Picker("Typeface", selection: $serif) {
          Text("Serif").tag(true)
          Text("Sans").tag(false)
        }.pickerStyle(.segmented)
        Slider(value: $typeSize, in: 0.04...0.28) { Text("Type size") }
        ColorPicker(
          "Text color", selection: Binding(get: { Color(hex: color) }, set: { color = $0.rgbHex }),
          supportsOpacity: false)
        if art.base == "friend" {
          Toggle("Replace original headline", isOn: $replaceHeadline)
        }
        Toggle("Paper backing", isOn: $backing)
        Text(textValue.isEmpty ? "Aa" : textValue).font(
          .system(
            size: typeSize * 260, weight: serif ? .regular : .bold,
            design: serif ? .serif : .default)
        ).foregroundStyle(Color(hex: color)).lineLimit(3)
      }.navigationTitle("Add text").navigationBarTitleDisplayMode(.inline)
        .toolbar {
          ToolbarItem(placement: .cancellationAction) { Button("Cancel") { typing = false } }
          ToolbarItem(placement: .confirmationAction) {
            Button("Place") { placeText() }.disabled(
              textValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
          }
        }
    }.presentationDetents([.medium, .large])
  }
  private func choose(_ t: Tool) {
    tool = t
    selected = nil
    withAnimation(.easeOut(duration: 0.18)) { assetShelf = t == .assets ? !assetShelf : false }
    if t == .type { openType(nil) }
  }
  func openType(_ l: Layer?) {
    replacing = l?.id
    textValue = l?.value ?? ""
    serif = l?.serif ?? true
    backing = l?.backing ?? false
    replaceHeadline =
      l?.replacesHeadline
      ?? (l == nil && art.base == "friend" && !art.layers.contains { $0.replacesHeadline == true })
    typeSize = l?.size ?? (replaceHeadline ? 0.195 : 0.13)
    if let l { color = l.color }
    typing = true
  }
  func placeText() {
    var l = art.layers.first(where: { $0.id == replacing }) ?? Layer(kind: .text)
    l.value = textValue.trimmingCharacters(in: .whitespacesAndNewlines)
    l.color = color
    l.size = typeSize
    l.serif = serif
    l.backing = backing
    l.replacesHeadline = replaceHeadline
    if replacing == nil && replaceHeadline {
      l.position = Point(x: 0.315, y: 0.195)
    }
    checkpoint()
    if let i = art.layers.firstIndex(where: { $0.id == l.id }) {
      art.layers[i] = l
    } else {
      art.layers.append(l)
    }
    selected = l.id
    typing = false
    save()
  }
  func cancelRequest() {
    selection = nil
    prompt = ""
    promptFocused = false
  }
  func queue(asset: UUID? = nil) {
    guard let region = selection else { return }
    let value = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !value.isEmpty else { return }
    let start = Date()
    var l = Layer(kind: .request)
    l.value = value
    l.generatedAsset = asset
    l.position = Point(x: region.x, y: region.y)
    l.size = region.w
    l.height = region.h
    l.liveTiming = liveRide != nil
    l.started = liveRide?.depart ?? start
    l.due = liveRide?.arrive ?? start.addingTimeInterval(16)
    tripStart = start
    append(l)
    cancelRequest()
  }
  func canvasGesture(_ size: CGSize) -> some Gesture {
    DragGesture(minimumDistance: 0, coordinateSpace: .local).onChanged { v in
      guard selection == nil else { return }
      let p = Point.normalized(v.location, size)
      if startLayers == nil {
        startLayers = art.layers
        trace = []
        let hit = art.layers.reversed().first { l in
          l.kind != .ink && !l.pending(at: now) && abs(l.position.x - p.x) <= layerWidth(l) / 2
            && abs(l.position.y - p.y) <= layerHeight(l) / 2
        }
        moving = (tool == .assets || tool == .type || selected == hit?.id) ? hit?.id : nil
        if let moving {
          selected = moving
          assetShelf = false
        }
      }
      if let moving, let i = art.layers.firstIndex(where: { $0.id == moving }),
        let old = startLayers?.first(where: { $0.id == moving })
      {
        let x = old.position.x + v.translation.width / size.width
        let y = old.position.y + v.translation.height / size.height
        art.layers[i].position = Point(
          x: abs(x - 0.5) < 0.018 ? 0.5 : min(1, max(0, x)),
          y: abs(y - 0.5) < 0.018 ? 0.5 : min(1, max(0, y)))
      } else {
        trace.append(p)
      }
    }.onEnded { v in
      guard let before = startLayers else { return }
      defer {
        trace = []
        startLayers = nil
        moving = nil
      }
      if moving != nil {
        if before != art.layers {
          undoStack.append(before)
          redoStack = []
          save()
        }
        return
      }
      if tool == .ink {
        var l = Layer(kind: .ink)
        l.points = trace
        l.color = color
        l.brush = thickness
        append(l)
        selected = nil
      } else if tool == .magic {
        if abs(v.translation.width) + abs(v.translation.height) < 5 && trace.count < 5 {
          let p = Point.normalized(v.location, size)
          selection = Region([
            Point(x: p.x - 0.11, y: p.y - 0.11), Point(x: p.x + 0.11, y: p.y + 0.11),
          ])
        } else {
          selection = Region(trace)
        }
        selected = nil
        prompt = ""
        promptFocused = true
      } else {
        selected = nil
        assetShelf = false
      }
    }
  }
  func layerWidth(_ l: Layer) -> Double {
    l.kind == .text ? min(1, max(0.15, l.size * Double(l.value.count) * 0.62)) : l.size
  }
  func layerHeight(_ l: Layer) -> Double {
    l.kind == .request ? l.height : (l.kind == .text ? l.size * 1.2 : l.size) * art.ratio
  }
  func adjust(_ layer: Layer, scale: Double) {
    modify(layer.id) {
      $0.size = min(1, max(0.035, $0.size * scale))
      $0.height = min(1, max(0.035, $0.height * scale))
    }
  }
  func modify(_ id: UUID, _ update: (inout Layer) -> Void) {
    guard let i = art.layers.firstIndex(where: { $0.id == id }) else { return }
    checkpoint()
    update(&art.layers[i])
    save()
  }
  func append(_ l: Layer) {
    checkpoint()
    art.layers.append(l)
    save()
  }
  func checkpoint() {
    undoStack.append(art.layers)
    redoStack = []
  }
  func undo() {
    guard let prior = undoStack.popLast() else { return }
    redoStack.append(art.layers)
    art.layers = prior
    selected = nil
    save()
  }
  func redo() {
    guard let next = redoStack.popLast() else { return }
    undoStack.append(art.layers)
    art.layers = next
    selected = nil
    save()
  }
  func save() {
    art.updated = Date()
    store.save(art)
  }
}
extension Color {
  fileprivate var rgbHex: String {
    var r: CGFloat = 0
    var g: CGFloat = 0
    var b: CGFloat = 0
    var a: CGFloat = 0
    UIColor(self).getRed(&r, green: &g, blue: &b, alpha: &a)
    return String(format: "%02X%02X%02X", Int(r * 255), Int(g * 255), Int(b * 255))
  }
}
