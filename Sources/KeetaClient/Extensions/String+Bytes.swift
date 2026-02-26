import Foundation

extension String {
    public func toBytes() throws -> [UInt8] {
        let hasPadding = hasPrefix("0x")
        let cleanedHex = hasPadding ? String(dropFirst(2)) : self
        
        guard cleanedHex.count % 2 == 0 else {
            throw NSError(domain: "Hex string has an odd number of characters", code: 0)
        }
        
        let bytes = try Array(hexString: cleanedHex.lowercased())
        
        return hasPadding ? [0] + bytes : bytes
    }
}

extension Array where Element == UInt8 {
    init(hexString: String) throws {
        self.init()
        
        guard hexString.count.isMultiple(of: 2), !hexString.isEmpty else {
            throw ByteHexEncodingErrors.incorrectString
        }

        let stringBytes: [UInt8] = Array(hexString.data(using: String.Encoding.utf8)!)

        for i in stride(from: stringBytes.startIndex, to: stringBytes.endIndex - 1, by: 2) {
            let char1 = stringBytes[i]
            let char2 = stringBytes[i + 1]

            try self.append(htoi(char1) << 4 + htoi(char2))
        }
    }

}

enum ByteHexEncodingErrors: Error {
    case incorrectHexValue
    case incorrectString
}

let charA = UInt8(UnicodeScalar("a").value)
let char0 = UInt8(UnicodeScalar("0").value)

private func htoi(_ value: UInt8) throws -> UInt8 {
    switch value {
    case char0...char0 + 9:
        return value - char0
    case charA...charA + 5:
        return value - charA + 10
    default:
        throw ByteHexEncodingErrors.incorrectHexValue
    }
}
