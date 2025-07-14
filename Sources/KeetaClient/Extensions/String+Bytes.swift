import Foundation
import P256K

extension String {
    public func toBytes() throws -> [UInt8] {
        let hasPadding = hasPrefix("0x")
        let cleanedHex = hasPadding ? String(dropFirst(2)) : self
        
        guard cleanedHex.count % 2 == 0 else {
            throw NSError(domain: "Hex string has an odd number of characters", code: 0)
        }
        
        let bytes = try cleanedHex.bytes
        
        return hasPadding ? [0] + bytes : bytes
    }
}
