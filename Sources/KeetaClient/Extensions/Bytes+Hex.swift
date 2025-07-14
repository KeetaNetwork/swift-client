extension Array where Element == UInt64 {
    func toHex() -> String {
        map { String(format: "%02X", $0) }.joined()
    }
}
