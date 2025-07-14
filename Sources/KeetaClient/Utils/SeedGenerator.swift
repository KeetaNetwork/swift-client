import Foundation
import CommonCrypto
import BIP39

public enum SeedGeneratorError: Error, Equatable {
    case seedCreationFailed
    case seedPhraseCreationFailed
    case invalidSeedPhrase
    case mnemonicWordIndexToLarge
    case mnemonicWordInvalidIndex
    case invalidPassphrase
    case weakPassphrase(count: Int, required: Int)
    case invalidPhraseEntropy(String)
    case invalidPassword(String)
    case cryptoError(code: Int32)
    case invalidSeedData
}

public struct SeedGenerator {
    
    static let maxWordIndex = 2047
    
    public static func generate() throws -> String {
        let count = 32
        var bytes = [Int8](repeating: 0, count: count)

        let status = SecRandomCopyBytes(kSecRandomDefault, count, &bytes)
        
        guard status == errSecSuccess else {
            throw SeedGeneratorError.seedCreationFailed
        }
        
        let data = Data(bytes: bytes, count: count)
        
        return data.hexString
    }
    
    public static func randomWord() throws -> String {
        guard let index = (0...maxWordIndex).randomElement() else {
            throw SeedGeneratorError.mnemonicWordInvalidIndex
        }
        return BIP39Util.mnemonicFromWord(UInt16(index))
    }
    
    public static func randomWords(count: Int) throws -> [String] {
        guard count <= maxWordIndex else {
            throw SeedGeneratorError.mnemonicWordIndexToLarge
        }
        
        var result = Set<String>()
        
        while result.count < count {
            result.insert(try randomWord())
        }
        
        return Array(result)
    }
    
    public static func from(phrase: [String]) throws -> String {
        try from(phrase: phrase.joined(separator: " "))
    }
    
    public static func from(phrase: String) throws -> String {
        let minPassphraseLength = 60
        
        let cleanPhrase = phrase.lowercased().replacingOccurrences(of: " ", with: "")
        guard let phraseData = cleanPhrase.data(using: .utf8) else {
            throw SeedGeneratorError.invalidPassphrase
        }
        
        if phraseData.count < minPassphraseLength {
            throw SeedGeneratorError.weakPassphrase(count: phraseData.count, required: minPassphraseLength)
        }
        
        let salt = phraseData
        let seedData = try pbkdf2(password: cleanPhrase, saltData: salt, keyByteCount: 32, rounds: 64000)
        
        return seedData.toHexString()
    }
    
    public static func from(bip39Phrase: [String]) throws -> String {
        guard let seed = BIP39Util.secretFromMnemonics(bip39Phrase) else {
            throw SeedGeneratorError.invalidSeedPhrase
        }
        return seed.hexString
    }
    
    public static func bip39Passphrase(using seed: String? = nil) throws -> [String] {
        let seed = try seed ?? generate()
        guard let phrase = BIP39Util.mnemonicsFromSecret(.init(hex: seed)) else {
            throw SeedGeneratorError.seedPhraseCreationFailed
        }
        return phrase
    }
    
    private static func pbkdf2(password: String, saltData: Data, keyByteCount: Int, rounds: Int) throws -> Data {
        guard let passwordData = password.data(using: .utf8) else {
            throw SeedGeneratorError.invalidPassword(password)
        }
        
        var derivedKeyData = Data(repeating: 0, count: keyByteCount)
        let derivedCount = derivedKeyData.count
        
        let derivationStatus: Int32 = derivedKeyData.withUnsafeMutableBytes { derivedKeyBytes in
            let keyBuffer: UnsafeMutablePointer<UInt8> =
                derivedKeyBytes.baseAddress!.assumingMemoryBound(to: UInt8.self)
            return saltData.withUnsafeBytes { saltBytes -> Int32 in
                let saltBuffer: UnsafePointer<UInt8> = saltBytes.baseAddress!.assumingMemoryBound(to: UInt8.self)
                return CCKeyDerivationPBKDF(
                    CCPBKDFAlgorithm(kCCPBKDF2),
                    password,
                    passwordData.count,
                    saltBuffer,
                    saltData.count,
                    CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256),
                    UInt32(rounds),
                    keyBuffer,
                    derivedCount)
            }
        }
        
        guard derivationStatus == kCCSuccess else {
            throw SeedGeneratorError.cryptoError(code: derivationStatus)
        }
        return derivedKeyData
    }
}

extension String {
    fileprivate func splitCompat(
        separator: Character,
        maxSplits: Int = .max,
        omittingEmptySubsequences: Bool = true
    ) -> [Substring] {
        return self.split(
            maxSplits: maxSplits,
            omittingEmptySubsequences: omittingEmptySubsequences,
            whereSeparator: { $0 == separator }
        )
    }
}
