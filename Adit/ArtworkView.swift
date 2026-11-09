import CoreMotion
import SwiftUI

struct PosterFace: View {
  let asset: String
  var body: some View {
    ZStack {
      Color.white
      GeometryReader { geometry in
        Image(asset).resizable().scaledToFit()
          .frame(width: geometry.size.width, height: geometry.size.height)
      }
      Image("paper").resizable().opacity(0.14).blendMode(.multiply).allowsHitTesting(false)
    }.clipped()
  }
}
struct MetalFrame<Content: View>: View {
  var thickness: CGFloat = 6
  @ViewBuilder var content: Content
  var body: some View {
    content.padding(thickness).background(
      LinearGradient(
        colors: [Color(white: 0.53), Color(white: 0.36), Color(white: 0.49), Color(white: 0.28)],
        startPoint: .topLeading, endPoint: .bottomTrailing)
    )
    .modifier(FloatingSurface(depth: 5, strength: 0.65))
  }
}
struct Mark: View {
  var layer: Layer
  let canvas: CGSize
  let now: Date
  var body: some View {
    switch layer.kind {
    case .ink:
      Path { path in
        guard let first = layer.points.first else { return }
        path.move(to: first.at(canvas))
        if layer.points.count == 1 {
          let p = first.at(canvas)
          path.addLine(to: CGPoint(x: p.x + 0.1, y: p.y))
        }
        for p in layer.points.dropFirst() { path.addLine(to: p.at(canvas)) }
      }.stroke(
        Color(hex: layer.color),
        style: StrokeStyle(lineWidth: layer.brush * canvas.width, lineCap: .round, lineJoin: .round)
      )
    case .text:
      Text(layer.value).font(
        .system(
          size: canvas.width * layer.size, weight: layer.serif ? .regular : .bold,
          design: layer.serif ? .serif : .default)
      )
      .foregroundStyle(Color(hex: layer.color)).lineLimit(3).minimumScaleFactor(0.5).fixedSize(
        horizontal: false, vertical: true
      )
      .padding(.horizontal, layer.backing ? 4 : 0).background(
        layer.backing ? Color.white : Color.clear)
    case .asset:
      if layer.value == "YOU" {
        Text("YOU").font(.system(size: canvas.width * layer.size * 0.46, design: .serif))
          .foregroundStyle(Color(hex: "581010"))
      } else {
        Image(layer.value).resizable().aspectRatio(
          contentMode: layer.value == "necklace" ? .fit : .fill
        )
        .frame(width: canvas.width * layer.size, height: canvas.width * layer.size)
        .clipShape(AnyShape(layer.value == "necklace" ? AnyShape(Rectangle()) : AnyShape(Circle())))
      }
    case .request:
      let w = canvas.width * layer.size
      let h = canvas.height * layer.height
      ZStack {
        if layer.pending(at: now) {
          Canvas { context, size in
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Color(white: 0.87)))
            for row in 0..<6 {
              let y = CGFloat(row) * size.height / 6
              context.fill(
                Path(
                  CGRect(
                    x: row.isMultiple(of: 2) ? 0 : size.width * 0.2, y: y, width: size.width * 0.82,
                    height: size.height / 8)),
                with: .color(row.isMultiple(of: 2) ? .gray.opacity(0.32) : .white.opacity(0.7)))
            }
          }
        } else {
          LocalResult(prompt: layer.value, asset: layer.generatedAsset)
        }
      }.frame(width: w, height: h).clipShape(Ellipse())
        .overlay {
          if layer.pending(at: now) {
            Ellipse().strokeBorder(.indigo, style: StrokeStyle(lineWidth: 1.4, dash: [5, 4]))
          }
        }
    }
  }
}
struct LocalResult: View {
  var prompt: String
  var asset: UUID? = nil
  var body: some View {
    let lower = prompt.lowercased()
    if let asset, let image = GeneratedAsset.image(asset) {
      Image(uiImage: image).resizable().scaledToFill()
    } else if lower.contains("joe") || lower.contains("goldberg") || lower.contains("portrait")
      || lower.contains("face")
    {
      Image("joe").resizable().scaledToFill()
    } else if lower.contains("pendant") || lower.contains("necklace") {
      Image("pendant").resizable()
    } else {
      let hash = prompt.utf8.reduce(UInt32(2_166_136_261)) { ($0 ^ UInt32($1)) &* 16_777_619 }
      let hue = Double(hash % 360) / 360
      let motif: [(String, String)] = [
        ("cat", "cat.fill"), ("dog", "dog.fill"), ("heart", "heart.fill"), ("train", "tram.fill"),
        ("star", "star.fill"), ("flower", "camera.macro"), ("moon", "moon.stars.fill"),
        ("sun", "sun.max.fill"), ("eye", "eye.fill"), ("apple", "apple.logo"),
        ("skull", "xmark.circle.fill"),
      ]
      ZStack {
        LinearGradient(
          colors: [
            Color(hue: hue, saturation: 0.8, brightness: 0.48),
            Color(
              hue: (hue + 0.14).truncatingRemainder(dividingBy: 1), saturation: 0.85, brightness: 1),
          ], startPoint: .topLeading, endPoint: .bottomTrailing)
        if let symbol = motif.first(where: { lower.contains($0.0) })?.1 {
          Image(systemName: symbol).resizable().scaledToFit().padding(7).foregroundStyle(.white)
        } else {
          Text(prompt.uppercased()).font(.system(size: 38, weight: .black, design: .rounded))
            .minimumScaleFactor(0.16).lineLimit(3).multilineTextAlignment(.center).padding(4)
            .foregroundStyle(.white)
        }
      }
    }
  }
}
struct ArtworkSurface: View, Equatable {
  static func == (lhs: Self, rhs: Self) -> Bool {
    lhs.art == rhs.art
      && lhs.art.layers.allSatisfy {
        $0.pending(at: lhs.now) == $0.pending(at: rhs.now)
      }
  }

  let art: Artwork
  var now = Date()
  var body: some View {
    GeometryReader { viewport in
      let source = UIImage(named: art.base)?.size ?? viewport.size
      let scale = min(
        viewport.size.width / max(1, source.width),
        viewport.size.height / max(1, source.height))
      let size = CGSize(width: source.width * scale, height: source.height * scale)
      ZStack {
        Color.white
        composition(size: size).frame(width: size.width, height: size.height)
      }
    }.aspectRatio(art.ratio, contentMode: .fit)
  }

  private func composition(size: CGSize) -> some View {
    ZStack(alignment: .topLeading) {
      PosterFace(asset: art.base)
      if art.base == "friend" && art.layers.contains(where: { $0.replacesHeadline == true }) {
        Rectangle().fill(Color(white: 0.993))
          .frame(width: size.width * 0.56, height: size.height * 0.245)
          .position(x: size.width * 0.348, y: size.height * 0.187)
      }
      ForEach(art.layers) { layer in
        if layer.kind == .ink {
          Mark(layer: layer, canvas: size, now: now)
        } else {
          Mark(layer: layer, canvas: size, now: now)
            .rotationEffect(.degrees(layer.rotation)).position(layer.position.at(size))
        }
      }
    }.clipped()
  }
}
@MainActor func shareImage(_ art: Artwork) -> UIImage? {
  let renderer = ImageRenderer(
    content: ArtworkSurface(art: art).frame(width: 1000, height: 1000 / art.ratio).environment(
      \.colorScheme, .light))
  renderer.scale = 2
  return renderer.uiImage
}
struct SharePanel: UIViewControllerRepresentable {
  let image: UIImage
  func makeUIViewController(context: Context) -> UIActivityViewController {
    UIActivityViewController(activityItems: [image], applicationActivities: nil)
  }
  func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
struct WallTiles: View {
  var body: some View {
    Canvas { ctx, s in
      ctx.fill(Path(CGRect(origin: .zero, size: s)), with: .color(Color(white: 0.965)))
      let h: CGFloat = 30
      let w: CGFloat = 94
      for row in 0...Int(s.height / h) {
        let y = CGFloat(row) * h
        ctx.fill(
          Path(CGRect(x: 0, y: y, width: s.width, height: 1.8)), with: .color(.white.opacity(0.34)))
        for col in -1...Int(s.width / w) {
          let x = CGFloat(col) * w + (row.isMultiple(of: 2) ? 0 : w / 2)
          ctx.fill(
            Path(CGRect(x: x, y: y, width: 1.4, height: h)), with: .color(.white.opacity(0.31)))
        }
      }
    }.accessibilityHidden(true)
  }
}
struct Sign: View {
  let title: String
  var badge = "6"
  var tint = Color.transitGreen
  var body: some View {
    HStack {
      Text(title).font(.custom("HelveticaNeue-Medium", size: 21, relativeTo: .headline)).tracking(
        -0.5
      ).lineSpacing(-3).multilineTextAlignment(.leading)
      Spacer()
      ZStack {
        Circle().fill(tint)
        if badge == "adit" {
          Image("wordmark").resizable().scaledToFit().padding(4)
        } else {
          Text(badge).font(.system(size: 24, weight: .bold))
        }
      }.frame(width: 33, height: 33)
    }.foregroundStyle(.white).padding(.horizontal, 9).padding(.top, 14).padding(.bottom, 8)
      .frame(maxWidth: .infinity, alignment: .leading).background(Color(white: 0.14))
      .overlay(alignment: .top) { Rectangle().fill(.white).frame(height: 1).padding(.top, 9) }
      .modifier(FloatingSurface(depth: 7, strength: 1))
  }
}
struct BlackButton: View {
  let title: String
  let action: () -> Void
  var body: some View {
    Button(action: action) {
      Text(title).font(.headline).foregroundStyle(.white).frame(maxWidth: .infinity).padding(
        .vertical, 13
      ).background(.black, in: Capsule())
    }.buttonStyle(.plain)
  }
}

/// One shared motion stream for the scene, stopped when inactive or motion is reduced.
@MainActor final class SurfaceMotion: ObservableObject {
  @Published private(set) var tilt = CGSize.zero
  private let manager = CMMotionManager()
  private var reference: CMAttitude?

  func start() {
    guard manager.isDeviceMotionAvailable, !manager.isDeviceMotionActive else { return }
    reference = nil
    manager.deviceMotionUpdateInterval = 1.0 / 30
    manager.startDeviceMotionUpdates(using: .xArbitraryZVertical, to: .main) {
      [weak self] sample, _ in
      guard let self, let sample else { return }
      guard let reference = self.reference else {
        self.reference = sample.attitude.copy() as? CMAttitude
        return
      }
      guard let attitude = sample.attitude.copy() as? CMAttitude else { return }
      attitude.multiply(byInverseOf: reference)
      let x = max(-1, min(1, attitude.roll / 0.45))
      let y = max(-1, min(1, attitude.pitch / 0.45))
      let next = CGSize(
        width: self.tilt.width * 0.82 + x * 0.18,
        height: self.tilt.height * 0.82 + y * 0.18)
      if abs(next.width - self.tilt.width) + abs(next.height - self.tilt.height) > 0.002 {
        self.tilt = next
      }
    }
  }

  func stop() {
    manager.stopDeviceMotionUpdates()
    reference = nil
    tilt = .zero
  }
}

private struct FloatingSurface: ViewModifier {
  @EnvironmentObject private var motion: SurfaceMotion
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var preview = CGSize.zero
  let depth: CGFloat
  let strength: Double

  func body(content: Content) -> some View {
    let tilt =
      reduceMotion
      ? CGSize.zero
      : CGSize(
        width: (motion.tilt.width + preview.width) * strength,
        height: (motion.tilt.height + preview.height) * strength)
    content
      .overlay {
        LinearGradient(
          colors: [.white.opacity(0.10 + max(0, tilt.width) * 0.10), .clear, .black.opacity(0.05)],
          startPoint: .topLeading, endPoint: .bottomTrailing
        )
        .allowsHitTesting(false)
      }
      .background {
        ForEach(1...Int(depth), id: \.self) { step in
          Rectangle()
            .fill(
              LinearGradient(
                colors: [Color(white: 0.42), Color(white: 0.12)],
                startPoint: .topLeading, endPoint: .bottomTrailing)
            )
            .offset(
              x: tilt.width * CGFloat(step) * 0.8,
              y: CGFloat(step) * (0.65 + tilt.height * 0.45))
        }
      }
      .rotation3DEffect(.degrees(-tilt.height * 7), axis: (x: 1, y: 0, z: 0), perspective: 0.35)
      .rotation3DEffect(.degrees(tilt.width * 9), axis: (x: 0, y: 1, z: 0), perspective: 0.35)
      .offset(x: tilt.width * 2, y: tilt.height * 2)
      .shadow(
        color: .black.opacity(0.24), radius: depth + 3,
        x: 2 - tilt.width * 7, y: depth + 4 - tilt.height * 5
      )
      .simultaneousGesture(previewGesture)
  }

  private var previewGesture: some Gesture {
    DragGesture(minimumDistance: 12)
      .onChanged { value in
        #if targetEnvironment(simulator)
          guard !reduceMotion else { return }
          preview = CGSize(
            width: max(-1, min(1, value.translation.width / 100)),
            height: max(-1, min(1, value.translation.height / 100)))
        #endif
      }
      .onEnded { _ in
        withAnimation(reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.8)) {
          preview = .zero
        }
      }
  }
}
