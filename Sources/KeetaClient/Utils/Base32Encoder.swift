import Foundation
import Base32

struct Base32Encoder {
    static func encode(bytes: [UInt8]) -> String {
        var encoded = base32Encode(Data(bytes))
        // remove padding
        while encoded.last == "=" {
            encoded.removeLast()
        }
        return encoded.lowercased()
    }
}
