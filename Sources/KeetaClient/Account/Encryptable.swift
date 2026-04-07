import Foundation

protocol Encryptable {
    static func encrypt(data: [UInt8], publicKey: [UInt8]) throws -> [UInt8]
    static func decrypt(data: [UInt8], privateKey: [UInt8]) throws -> [UInt8]
}

public enum EncryptionError: Error {
    case noPrivateKey
    case encryptionNotSupported
    case invalidCiphertext
    case hmacVerificationFailed
    case invalidPublicKeyFormat
    case invalidEphemeralKey
    case decryptionFailed
}
