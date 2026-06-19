import Foundation

enum FirestoreDecoding {
    static func int(_ value: Any?, default defaultValue: Int = 0) -> Int {
        if let value = value as? Int { return value }
        if let value = value as? Int64 { return Int(value) }
        if let value = value as? Double { return Int(value) }
        if let value = value as? NSNumber { return value.intValue }
        return defaultValue
    }

    static func bool(_ value: Any?, default defaultValue: Bool = false) -> Bool {
        if let value = value as? Bool { return value }
        if let value = value as? NSNumber { return value.boolValue }
        return defaultValue
    }

    static func int64(_ value: Any?, default defaultValue: Int64 = 0) -> Int64 {
        if let value = value as? Int64 { return value }
        if let value = value as? Int { return Int64(value) }
        if let value = value as? Double { return Int64(value) }
        if let value = value as? NSNumber { return value.int64Value }
        return defaultValue
    }

    static func intMap(_ value: Any?) -> [String: Int] {
        guard let raw = value as? [String: Any] else {
            return (value as? [String: Int]) ?? [:]
        }
        return raw.reduce(into: [String: Int]()) { result, entry in
            result[entry.key] = int(entry.value)
        }
    }

    static func stringMap(_ value: Any?) -> [String: String] {
        guard let raw = value as? [String: Any] else {
            return (value as? [String: String]) ?? [:]
        }
        return raw.reduce(into: [String: String]()) { result, entry in
            if let stringValue = entry.value as? String {
                result[entry.key] = stringValue
            }
        }
    }
}
