import CryptoSwift
import Foundation

public struct Hash {
    
    public static var digestLength: Int { sha3_256().digestLength }
    
    public static let oid: OID = .sha3_256
    
    private static func sha3_256() -> SHA3 { CryptoSwift.SHA3(variant: .sha256) }
    
    public static func create(from bytes: [UInt8], length: Int? = nil) -> String {
        String(bytes: create(from: bytes, length: length)).uppercased()
    }
    
    public static func create(from data: Data, length: Int? = nil) -> Data {
        Data(create(from: data.bytes, length: length))
    }
    
    public static func create(from bytes: [UInt8], length: Int? = nil) -> [UInt8] {
        let hash = sha3_256().calculate(for: bytes)
        if let length = length {
            return Array(hash.prefix(length))
        } else {
            return hash
        }
    }
    
    static func hkdf(_ prk: [UInt8], length: Int = 32, info: [UInt8] = []) throws -> String {
        let numBlocks = Int(ceil(Double(length / digestLength)))
        let hmac = HMAC(key: prk, variant: .sha3(.sha256))
        
        var ret = Array<UInt8>()
        ret.reserveCapacity(numBlocks * digestLength)
        var value = Array<UInt8>()
        
        for i in 1...numBlocks {
          value.append(contentsOf: info)
          value.append(UInt8(i))

          let bytes = try hmac.authenticate(value)
          ret.append(contentsOf: bytes)

          value = bytes
        }

        return String(bytes: ret).uppercased()
    }
}
