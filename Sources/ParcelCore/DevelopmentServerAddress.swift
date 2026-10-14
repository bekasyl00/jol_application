import Foundation

/// LAN-only destination for the separately compiled development client.
public enum DevelopmentServerAddress {
    public static func isAllowed(_ host: String) -> Bool {
        if host == "localhost" || host == "127.0.0.1" { return true }
        let parts = host.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 4 else { return false }
        let numbers = parts.compactMap { UInt8($0) }
        guard numbers.count == 4, zip(parts, numbers).allSatisfy({ String($0.1) == String($0.0) }) else { return false }
        return numbers[0] == 10 || (numbers[0] == 192 && numbers[1] == 168) ||
            (numbers[0] == 172 && (16...31).contains(numbers[1]))
    }
}
