import Foundation

struct FeatureStateStore {
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load<T: Decodable>(_ type: T.Type, key: String, fallback: T) -> T {
        guard let data = defaults.data(forKey: key),
              let decoded = try? JSONDecoder().decode(type, from: data) else {
            return fallback
        }
        return decoded
    }

    func save<T: Encodable>(_ value: T, key: String) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        defaults.set(data, forKey: key)
    }
}
