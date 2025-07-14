import BigInt
import Base32

enum Base32Error: Error {
    case invalidInput
    case invalidLength
}

struct Base32Decoder {
    
    static func decode(_ value: String, length: Int) throws -> [UInt8] {
        guard let result = base32Decode(value) else {
            throw Base32Error.invalidInput
        }
        guard result.count == length else {
            throw Base32Error.invalidLength
        }
        return result
    }
}
