import Foundation

/// Last successful response for a screen, kept on disk so a cold launch can
/// paint real content before the network answers.
///
/// This is deliberately not `URLCache`: the protocol cache only helps when the
/// server sent a still-fresh `Cache-Control`, and it only saves the round trip,
/// not the wait. A snapshot is rendered immediately and then replaced by the
/// live response (stale-while-revalidate), which is what removes the spinner
/// from the first frame of every launch after the first.
actor SnapshotStore {
    static let shared = SnapshotStore()

    /// Snapshots are a rendering optimisation, never a source of truth, so they
    /// belong in Caches where the system may reclaim them.
    private let directory: URL
    private let decoder: JSONDecoder = .viveLoja
    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        // `.viveLoja` accepts ISO8601 with or without fractional seconds.
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    /// Anything older than this is discarded rather than shown: a day-old home
    /// screen is still a reasonable first paint, a stale week is not.
    private static let maximumAge: TimeInterval = 24 * 60 * 60
    private static let publicKeys: Set<String> = [Key.home, Key.today]

    init(directory: URL? = nil) {
        let base = directory ?? FileManager.default
            .urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appending(path: "Snapshots", directoryHint: .isDirectory)
        self.directory = base
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
    }

    private func url(for key: String) -> URL {
        directory.appending(path: "\(key).json", directoryHint: .notDirectory)
    }

    func read<Value: Decodable & Sendable>(_ key: String) -> Value? {
        guard Self.publicKeys.contains(key) else { return nil }
        let file = url(for: key)
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: file.path(percentEncoded: false)),
              let modified = attributes[.modificationDate] as? Date,
              Date().timeIntervalSince(modified) >= 0,
              Date().timeIntervalSince(modified) < Self.maximumAge,
              let data = try? Data(contentsOf: file, options: .mappedIfSafe)
        else { return nil }
        return try? decoder.decode(Value.self, from: data)
    }

    func write<Value: Encodable & Sendable>(_ value: Value, for key: String) {
        guard Self.publicKeys.contains(key) else { return }
        guard let data = try? encoder.encode(value) else { return }
        try? data.write(to: url(for: key), options: .atomic)
    }
}

extension SnapshotStore {
    enum Key {
        static let home = "home"
        static let today = "today"
    }
}
