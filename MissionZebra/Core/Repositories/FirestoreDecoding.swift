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
        if let value = value as? String {
            switch value.lowercased() {
            case "true", "1", "yes": return true
            case "false", "0", "no": return false
            default: break
            }
        }
        return defaultValue
    }

    static func optionalBool(_ value: Any?) -> Bool? {
        if value == nil { return nil }
        if value is NSNull { return nil }
        return bool(value)
    }

    static func int64(_ value: Any?, default defaultValue: Int64 = 0) -> Int64 {
        if let value = value as? Int64 { return value }
        if let value = value as? Int { return Int64(value) }
        if let value = value as? Double { return Int64(value) }
        if let value = value as? NSNumber { return value.int64Value }
        return defaultValue
    }

    static func intMap(_ value: Any?) -> [String: Int] {
        guard let raw = rawMap(value) else { return (value as? [String: Int]) ?? [:] }
        return raw.reduce(into: [String: Int]()) { result, entry in
            result[entry.key] = int(entry.value)
        }
    }

    static func stringMap(_ value: Any?) -> [String: String] {
        guard let raw = rawMap(value) else { return (value as? [String: String]) ?? [:] }
        return raw.reduce(into: [String: String]()) { result, entry in
            if let stringValue = entry.value as? String {
                result[entry.key] = stringValue
            } else if let numberValue = entry.value as? NSNumber {
                result[entry.key] = numberValue.stringValue
            }
        }
    }

    static func stringArray(_ value: Any?) -> [String] {
        if let value = value as? [String] { return value }
        return (value as? [Any])?.compactMap { $0 as? String } ?? []
    }

    static func rawMap(_ value: Any?) -> [String: Any]? {
        if let value = value as? [String: Any] { return value }
        if let value = value as? [String: Int] { return value.mapValues { $0 } }
        if let value = value as? [String: String] { return value.mapValues { $0 } }
        if let value = value as? NSDictionary {
            var result: [String: Any] = [:]
            value.forEach { key, val in
                if let key = key as? String {
                    result[key] = val
                }
            }
            return result
        }
        return nil
    }
}
