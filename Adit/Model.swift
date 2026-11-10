import SwiftUI

struct Station: RawRepresentable, Codable, CaseIterable, Hashable {
  let rawValue: String
  init(rawValue: String) { self.rawValue = rawValue }
  // Preserve existing on-device drafts, which stored these three names as strings.
  static let grand = Station(rawValue: "Grand Central-42 Street Station")
  static let thirty = Station(rawValue: "33 Street Station")
  static let avenue = Station(rawValue: "23 Street Station")
  init(boardID: String) {
    let legacy = ["631": Self.grand.rawValue, "632": Self.thirty.rawValue, "634": Self.avenue.rawValue]
    self.init(rawValue: legacy[boardID] ?? boardID)
  }
  var boardID: String {
    switch self {
    case .grand: "631"
    case .thirty: "632"
    case .avenue: "634"
    default: rawValue
    }
  }
  var board: StationBoards.Board { StationBoards.byID[boardID] ?? StationBoards.all[0] }
  var title: String { board.title }
  var short: String { self == .grand ? "Grand Central" : board.name }
  static let allCases: [Station] = [.grand, .thirty, .avenue] + StationBoards.all
    .filter { !["631", "632", "634"].contains($0.id) }.map { Station(boardID: $0.id) }
  var nextStop: (name: String, from: String, to: String)? {
    switch self {
    case .grand: ("33 St", "631S", "632S")
    case .thirty: ("28 St", "632S", "633S")
    case .avenue: ("14 St–Union Sq", "634S", "635S")
    default: nil
    }
  }
  init(from decoder: Decoder) throws {
    rawValue = try decoder.singleValueContainer().decode(String.self)
  }
  func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encode(rawValue)
  }
}

struct Campaign: Identifiable {
  let id: String, name: String, variants: [String], count: Int, palette: [String]
  let ratio: Double
  static let all = [
    Campaign(
      id: "friend", name: "Friend.com", variants: ["wide", "friend", "pendantPoster"], count: 596,
      palette: ["101010", "FFFFFF", "808080", "BEBEBE", "E6E6E6"], ratio: 1.17),
    Campaign(
      id: "watch", name: "Back Market", variants: ["watch", "watchYellow"], count: 318,
      palette: ["131C13", "E6F59B", "FFF081", "B89C3C", "1B6063"], ratio: 0.72),
    Campaign(
      id: "apple", name: "Back Market", variants: ["apple", "appleBlue"], count: 223,
      palette: ["1D1A19", "CFE184", "5D9ED4", "F58862", "EDCC59"], ratio: 0.96),
    Campaign(
      id: "tip", name: "New York City", variants: ["tip", "van"], count: 157,
      palette: ["162831", "CDD886", "F4E18C", "D98141", "FFFFFF"], ratio: 0.94),
  ]
  static func get(_ id: String) -> Self { all.first { $0.id == id } ?? all[0] }
}
struct Point: Codable, Equatable {
  var x: Double, y: Double
  static let center = Point(x: 0.5, y: 0.5)
  func at(_ size: CGSize) -> CGPoint { CGPoint(x: x * size.width, y: y * size.height) }
  static func normalized(_ p: CGPoint, _ size: CGSize) -> Point {
    Point(x: min(1, max(0, p.x / max(1, size.width))), y: min(1, max(0, p.y / max(1, size.height))))
  }
}
struct Region: Codable, Equatable {
  var x, y, w, h: Double
  init(_ points: [Point]) {
    let left = points.map(\.x).min() ?? 0.36
    let right = points.map(\.x).max() ?? 0.64
    let top = points.map(\.y).min() ?? 0.36
    let bottom = points.map(\.y).max() ?? 0.64
    w = min(1, max(0.10, right - left))
    h = min(1, max(0.10, bottom - top))
    x = max(w / 2, min(1 - w / 2, (left + right) / 2))
    y = max(h / 2, min(1 - h / 2, (top + bottom) / 2))
  }
}
enum LayerKind: String, Codable { case ink, text, asset, request }
struct Layer: Identifiable, Codable, Equatable {
  var id = UUID()
  var replacesHeadline: Bool?
  var liveTiming: Bool?
  var generatedAsset: UUID?
  var kind: LayerKind
  init(kind: LayerKind) { self.kind = kind }
  var position = Point.center, points: [Point] = [], value = "", color = "111111"
  var size = 0.23, height = 0.23, brush = 0.011, rotation = 0.0
  var serif = true, backing = false, started: Date?, due: Date?
  func pending(at date: Date) -> Bool { due.map { $0 > date } ?? false }
}
struct Artwork: Identifiable, Codable, Equatable {
  var id = UUID()
  var campaign: String
  var base: String
  var ratio: Double
  var station: Station
  var layers: [Layer] = [], updated = Date(), published = false
}
struct Entry: Identifiable {
  let id: String, asset: String, author: String, count: Int, ratio: Double
  static let feed = [
    Entry(id: "ketchup", asset: "ketchup", author: "svsd.fan", count: 45, ratio: 0.94),
    Entry(id: "duo", asset: "duo", author: "nabubu_enthusiast", count: 23, ratio: 1.7),
    Entry(id: "sandwich", asset: "sandwich", author: "ZZZzzzZZz", count: 8, ratio: 1.28),
    Entry(id: "camera", asset: "camera", author: "aNticapitAlist", count: 23, ratio: 1),
    Entry(id: "heard", asset: "heard", author: "whereissvsdmerch", count: 12, ratio: 1.18),
    Entry(id: "you", asset: "you", author: "Naheel.io", count: 596, ratio: 1.17),
    Entry(id: "french", asset: "french", author: "svsd.fan", count: 19, ratio: 0.67),
    Entry(id: "box", asset: "box", author: "svsd.fan", count: 12, ratio: 0.81),
  ]
  static let awards = [
    Entry(id: "beer", asset: "beer", author: "Hall of fame", count: 78, ratio: 1.17),
    Entry(id: "grammar", asset: "grammar", author: "Hall of cray", count: 52, ratio: 0.71),
    Entry(id: "bundle", asset: "bundle", author: "Most remixed", count: 86, ratio: 0.9),
  ]
}
struct Library: Codable {
  var handle = "ilovesvsdteam3", station = Station.grand
  var documents: [Artwork] = [], votes: [String: String] = [:], saved: Set<String> = [],
    savedEntries: [String: Artwork] = [:]
}
@MainActor final class Store: ObservableObject {
  @Published private(set) var data: Library
  @Published var error: String?
  private let url: URL
  init() {
    let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
    let testMode = ProcessInfo.processInfo.arguments.contains("--ui-test")
    url = dir.appendingPathComponent(testMode ? "ui-test-library.json" : "library-v1.json")
    if testMode && ProcessInfo.processInfo.arguments.contains("--reset-test-library") {
      try? FileManager.default.removeItem(at: url)
    }
    do {
      try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
      data =
        FileManager.default.fileExists(atPath: url.path)
        ? try JSONDecoder().decode(Library.self, from: Data(contentsOf: url)) : Library()
    } catch {
      data = Library()
      self.error = error.localizedDescription
    }
  }
  func change(_ update: (inout Library) -> Void) {
    var next = data
    update(&next)
    do {
      try JSONEncoder().encode(next).write(to: url, options: .atomic)
      data = next
    } catch { self.error = error.localizedDescription }
  }
  func save(_ document: Artwork) {
    change { lib in
      if let i = lib.documents.firstIndex(where: { $0.id == document.id }) {
        lib.documents[i] = document
      } else {
        lib.documents.insert(document, at: 0)
      }
    }
  }
  func toggleVote(_ vote: String, for id: String) {
    change { $0.votes[id] = $0.votes[id] == vote ? nil : vote }
  }
  func toggleSave(_ art: Artwork, key: String) {
    change { lib in
      if lib.saved.remove(key) != nil {
        lib.savedEntries[key] = nil
      } else {
        lib.saved.insert(key)
        lib.savedEntries[key] = art
      }
    }
  }
  func art(_ entry: Entry) -> Artwork {
    Artwork(campaign: "friend", base: entry.asset, ratio: entry.ratio, station: data.station)
  }
}
extension Color {
  init(hex: String) {
    let n = UInt32(hex, radix: 16) ?? 0
    self.init(
      red: Double(n >> 16 & 255) / 255, green: Double(n >> 8 & 255) / 255,
      blue: Double(n & 255) / 255)
  }
  static let transitGreen = Color(hex: "008D40")
}
