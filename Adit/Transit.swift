import Foundation

/// Only the GTFS-RT fields used by this app. Unknown protobuf fields are skipped.
private struct Fields {
  var bytes: [Int: [Data.SubSequence]] = [:]
  var integers: [Int: UInt64] = [:]

  init(_ input: Data.SubSequence) throws {
    var cursor = input.startIndex
    func varint() throws -> UInt64 {
      var result: UInt64 = 0
      for shift in stride(from: 0, through: 63, by: 7) {
        guard cursor < input.endIndex else { throw TransitError.invalidFeed }
        let byte = input[cursor]
        cursor += 1
        guard shift < 63 || byte <= 1 else { throw TransitError.invalidFeed }
        result |= UInt64(byte & 127) << shift
        if byte < 128 { return result }
      }
      throw TransitError.invalidFeed
    }
    while cursor < input.endIndex {
      let tag = try varint()
      guard tag > 0, tag >> 3 <= UInt32.max else { throw TransitError.invalidFeed }
      let key = Int(tag >> 3)
      switch tag & 7 {
      case 0: integers[key] = try varint()
      case 1, 5:
        let length = tag & 7 == 1 ? 8 : 4
        guard length <= input.endIndex - cursor else { throw TransitError.invalidFeed }
        cursor += length
      case 2:
        let length = try varint()
        guard length <= input.endIndex - cursor else { throw TransitError.invalidFeed }
        let end = cursor + Int(length)
        bytes[key, default: []].append(input[cursor..<end])
        cursor = end
      default: throw TransitError.invalidFeed
      }
    }
  }
  func child(_ key: Int) throws -> Fields? { try bytes[key]?.first.map(Fields.init) }
  func string(_ key: Int) -> String? {
    bytes[key]?.first.flatMap { String(data: $0, encoding: .utf8) }
  }
}

enum TransitError: Error { case invalidFeed, stale, noTrain }
struct TrainWindow {
  let depart: Date
  let arrive: Date

  static func prediction(in data: Data, from: String, to: String, now: Date) throws -> Self {
    let root = try Fields(data[...])
    guard let stamp = try root.child(1)?.integers[3],
      abs(now.timeIntervalSince1970 - Double(stamp)) < 180
    else { throw TransitError.stale }
    var candidates: [Self] = []
    for item in root.bytes[2] ?? [] {
      guard let trip = try Fields(item).child(3),
        try trip.child(1)?.string(5) == "6"
      else { continue }
      var departure: Date?
      for raw in trip.bytes[2] ?? [] {
        let stop = try Fields(raw)
        if stop.string(4) == from, let time = try (stop.child(3) ?? stop.child(2))?.integers[2] {
          departure = Date(timeIntervalSince1970: Double(time))
        }
        if stop.string(4) == to, let departure, let time = try stop.child(2)?.integers[2] {
          let arrival = Date(timeIntervalSince1970: Double(time))
          if arrival > now && arrival > departure && departure >= now.addingTimeInterval(-90) {
            candidates.append(Self(depart: departure, arrive: arrival))
          }
          break
        }
      }
    }
    guard let first = candidates.min(by: { $0.depart < $1.depart }) else {
      throw TransitError.noTrain
    }
    return first
  }

  static func load(from: String, to: String) async throws -> Self {
    let endpoint = URL(
      string: "https://api-endpoint.mta.info/Dataservice/mtagtfsfeeds/nyct%2Fgtfs")!
    let (data, response) = try await URLSession.shared.data(
      for: URLRequest(url: endpoint, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 6)
    )
    guard (response as? HTTPURLResponse)?.statusCode == 200, data.count < 4_000_000 else {
      throw TransitError.invalidFeed
    }
    return try prediction(in: data, from: from, to: to, now: Date())
  }
}
