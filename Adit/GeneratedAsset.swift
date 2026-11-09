import ImagePlayground
import SwiftUI

@MainActor
enum GeneratedAsset {
  private static let cache = NSCache<NSUUID, UIImage>()
  private static var directory: URL {
    FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
      .appendingPathComponent("Generated", isDirectory: true)
  }

  static func store(_ temporaryURL: URL) throws -> UUID {
    guard let image = UIImage(contentsOfFile: temporaryURL.path),
      let data = image.pngData()
    else { throw CocoaError(.fileReadCorruptFile) }
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let id = UUID()
    try data.write(to: directory.appendingPathComponent(id.uuidString + ".png"), options: .atomic)
    cache.setObject(image, forKey: id as NSUUID)
    return id
  }

  static func image(_ id: UUID) -> UIImage? {
    if let cached = cache.object(forKey: id as NSUUID) { return cached }
    guard
      let image = UIImage(
        contentsOfFile: directory.appendingPathComponent(id.uuidString + ".png").path)
    else { return nil }
    cache.setObject(image, forKey: id as NSUUID)
    return image
  }
}

@available(iOS 18.2, *)
struct GenerateAssetButton: View {
  @Environment(\.supportsImagePlayground) private var supported
  @State private var presented = false
  @State private var reference: UIImage?
  @State private var failure: String?
  let prompt: String
  let region: Region
  let art: Artwork
  let insert: (UUID) -> Void

  var body: some View {
    if supported {
      Button {
        if let image = shareImage(art)?.cgImage {
          let w = CGFloat(image.width)
          let h = CGFloat(image.height)
          let box = CGRect(
            x: (region.x - region.w / 2) * w, y: (region.y - region.h / 2) * h,
            width: region.w * w, height: region.h * h)
          reference = image.cropping(to: box.integral).map { UIImage(cgImage: $0) }
        }
        presented = true
      } label: {
        Image(systemName: "wand.and.stars")
      }
      .accessibilityLabel("Generate with Image Playground")
      .disabled(prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
      .imagePlaygroundSheet(
        isPresented: $presented, concepts: [.text(prompt)],
        sourceImage: reference.map { Image(uiImage: $0) }
      ) { url in
        do { insert(try GeneratedAsset.store(url)) } catch { failure = error.localizedDescription }
      }
      .alert(
        "Couldn’t keep this image",
        isPresented: Binding(get: { failure != nil }, set: { if !$0 { failure = nil } })
      ) {
        Button("OK") { failure = nil }
      } message: {
        Text(failure ?? "")
      }
    }
  }
}
