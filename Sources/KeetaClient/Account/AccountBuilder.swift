import Foundation
import BigInt

public enum AccountBuilderError: Error {
    case seedIndexNegative
    case seedIndexTooLarge
    case invalidPublicKeyPrefix
    case invalidPublicKeyChecksum
}

public struct AccountBuilder {
    
    public static func create(
        fromSeed seed: String,
        index: Int,
        algorithm: Account.KeyAlgorithm = .ECDSA_SECP256K1
    ) throws -> Account {
        try create(fromSeed: try seed.toBytes(), index: index, algorithm: algorithm)
    }
    
    public static func create(
        fromSeed seed: [UInt8],
        index: Int,
        algorithm: Account.KeyAlgorithm = .ECDSA_SECP256K1
    ) throws -> Account {
        let seedBase = try combine(seed: seed, and: index)
        let keyPair = try algorithm.utils.create(from: seedBase)
        return try .init(keyPair: keyPair, keyAlgorithm: algorithm)
    }
    
    public static func create(for config: NetworkConfig) throws -> Account {
        let seed = config.network.id.toData(length: 32).toBytes()
        return try create(fromSeed: seed, index: 0, algorithm: .NETWORK)
    }
    
    public static func create(fromPublicKey publicKey: String) throws -> Account {
        var key = publicKey
        
        /*
         * Remove any of the acceptable prefixes
         */
        var prefixMatched = false
        
        for keyPrefix in Account.accountPrefixes {
            if let updateKey = key.removePrefix(keyPrefix) {
                key = updateKey
                prefixMatched = true
                break
            }
        }
        
        if (!prefixMatched) {
            throw AccountBuilderError.invalidPublicKeyPrefix
        }
        
        /*
         * Verify key length
         */
        guard let pubKeySize = Account.publicKeyLengths[key.count] else {
            throw AccountError.invalidPublicKeyLength(length: key.count)
        }
        
        /*
         * Verify the embedded checksum
         */
        let pubKeyValues = try Base32Decoder.decode(key, length: pubKeySize)
        let checksumOf = Array(pubKeyValues.prefix(pubKeyValues.count - Account.checksumLength))
        let checksum = Array(pubKeyValues.suffix(Account.checksumLength)).toHexString()
        let checksumCheckBytes: [UInt8] = Hash.create(from: checksumOf, length: Account.checksumLength)
        let checksumCheck = checksumCheckBytes.toHexString()
        
        if checksum != checksumCheck {
            throw AccountBuilderError.invalidPublicKeyChecksum
        }
        
        /*
         * Parse out the relevant parts
         */
        let pubKey = Array(pubKeyValues[1..<pubKeyValues.count - Account.checksumLength]).toHexString()
        let keyType = Int(pubKeyValues[0])
        
        guard let algo = Account.KeyAlgorithm(rawValue: keyType) else {
            throw AccountError.invalidPublicKeyAlgo(key: String(keyType))
        }
        
        return try .init(keyPair: .init(publicKey: pubKey, privateKey: nil), keyAlgorithm: algo)
    }
    
    public static func create(fromPrivateKey privateKey: String, algorithm: Account.KeyAlgorithm) throws -> Account {
        let keyPair = try algorithm.utils.keypair(from: privateKey)
        return try .init(keyPair: keyPair, keyAlgorithm: algorithm)
    }
    
    // MARK: - Internal
    
    static func combine(seed: String, and index: Int) throws -> String {
        try combine(seed: try seed.toBytes(), and: index)
    }
    
    static func combine(seed: [UInt8], and index: Int) throws -> String {
        guard index >= 0 else {
            throw AccountBuilderError.seedIndexNegative
        }
        
        let indexValue = BigInt(index)
        
        guard indexValue >> BigInt(32) == 0 else {
            throw AccountBuilderError.seedIndexTooLarge
        }
        
        var mutableSeed = seed
        
        mutableSeed.append(UInt8(indexValue >> BigInt(24) & BigInt(0xff)))
        mutableSeed.append(UInt8(indexValue >> BigInt(16) & BigInt(0xff)))
        mutableSeed.append(UInt8(indexValue >> BigInt(8)  & BigInt(0xff)))
        mutableSeed.append(UInt8(indexValue               & BigInt(0xff)))
        
        return .init(bytes: mutableSeed).uppercased()
    }
    
}
