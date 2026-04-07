import Foundation
import CryptoKit
import CryptoSwift

/// ECIES implementation for P-256 (secp256r1), compatible with @safeheron/crypto-ecies.
///
/// Wire format: [gR(65)] + [ciphertext] + [MAC(64)] + [IV(16)]
///
/// Encryption:
/// 1. Generate ephemeral P-256 key pair (gR = g * r)
/// 2. ECDH: keyPoint = recipientPublic * r
/// 3. Seed = gR.encode(uncompressed, 65 bytes) + keyPointX (32 bytes)
/// 4. KDF: SHA512-counter(seed) → derive 160 bytes (32 symmKey + 128 macKey)
/// 5. Encrypt: AES-256-CBC(plaintext, symmKey, randomIV) with PKCS7
/// 6. MAC: HMAC-SHA512(macKey, ciphertext + 8 zero bytes)
/// 7. Output: gR(65) || ciphertext || MAC(64) || IV(16)
struct EciesP256R: Encryptable {

    private static let ephemeralKeyLength = 65 // uncompressed P256 point
    private static let ivLength = 16
    private static let macLength = 64  // SHA-512 HMAC
    private static let symmKeyLength = 32
    private static let macKeyLength = 128

    static func encrypt(data: [UInt8], publicKey: [UInt8]) throws -> [UInt8] {
        // Generate ephemeral key pair
        let ephemeralPrivate = P256.KeyAgreement.PrivateKey()
        let gRBytes = Array(ephemeralPrivate.publicKey.x963Representation)

        // Recipient public key
        let recipientPublic = try P256.KeyAgreement.PublicKey(
            compressedRepresentation: publicKey
        )

        // ECDH shared secret - we need the raw shared point x-coordinate
        let sharedSecret = try ephemeralPrivate.sharedSecretFromKeyAgreement(with: recipientPublic)
        let sharedX = sharedSecret.withUnsafeBytes { Array($0) }

        // Build seed: gR.encode(uncompressed) + keyPointX
        // gR is already uncompressed (65 bytes with 0x04 prefix)
        let seed = gRBytes + sharedX

        // KDF: SHA512-counter mode
        let derived = sha512KDF(seed, outputLength: symmKeyLength + macKeyLength)
        let symmKey = Array(derived[0..<symmKeyLength])
        let macKey = Array(derived[symmKeyLength...])

        // Encrypt: AES-256-CBC with PKCS7
        let iv = generateRandomBytes(ivLength)
        let ciphertext = try AES(key: symmKey, blockMode: CBC(iv: iv), padding: .pkcs7).encrypt(data)

        // MAC: HMAC-SHA512(macKey, ciphertext + 8_zero_bytes)
        // The "macIVLen" is "0" padded to 16 hex chars = 8 bytes of zeros
        let macInput = ciphertext + [UInt8](repeating: 0, count: 8)
        let hmac = CryptoKit.HMAC<SHA512>.authenticationCode(
            for: Data(macInput),
            using: SymmetricKey(data: Data(macKey))
        ).withUnsafeBytes { Array($0) }

        // Wire format: gR(65) || ciphertext || MAC(64) || IV(16)
        return gRBytes + ciphertext + hmac + iv
    }

    static func decrypt(data: [UInt8], privateKey: [UInt8]) throws -> [UInt8] {
        // Minimum: 65 (gR) + 64 (MAC) + 16 (IV) = 145 + at least some ciphertext
        guard data.count > ephemeralKeyLength + macLength + ivLength else {
            throw EncryptionError.invalidCiphertext
        }

        // Parse wire format
        let gRBytes = Array(data[0..<ephemeralKeyLength])
        guard gRBytes[0] == 0x04 else {
            throw EncryptionError.invalidEphemeralKey
        }

        let iv = Array(data[(data.count - ivLength)...])
        let receivedMac = Array(data[(data.count - ivLength - macLength)..<(data.count - ivLength)])
        let ciphertext = Array(data[ephemeralKeyLength..<(data.count - ivLength - macLength)])

        // ECDH
        let privateKeyObj = try P256.KeyAgreement.PrivateKey(rawRepresentation: privateKey)
        let ephemeralPublic = try P256.KeyAgreement.PublicKey(x963Representation: gRBytes)

        let sharedSecret = try privateKeyObj.sharedSecretFromKeyAgreement(with: ephemeralPublic)
        let sharedX = sharedSecret.withUnsafeBytes { Array($0) }

        // Build seed and derive keys
        let seed = gRBytes + sharedX
        let derived = sha512KDF(seed, outputLength: symmKeyLength + macKeyLength)
        let symmKey = Array(derived[0..<symmKeyLength])
        let macKey = Array(derived[symmKeyLength...])

        // Verify MAC
        let macInput = ciphertext + [UInt8](repeating: 0, count: 8)
        let expectedMac = CryptoKit.HMAC<SHA512>.authenticationCode(
            for: Data(macInput),
            using: SymmetricKey(data: Data(macKey))
        ).withUnsafeBytes { Array($0) }

        guard expectedMac == receivedMac else {
            throw EncryptionError.hmacVerificationFailed
        }

        // Decrypt AES-256-CBC
        let plaintext = try AES(key: symmKey, blockMode: CBC(iv: iv), padding: .pkcs7).decrypt(ciphertext)
        return plaintext
    }

    /// SHA512-based counter mode KDF (compatible with safeheron)
    /// output = SHA512(seed || counter_4bytes_be) for counter 1, 2, ...
    private static func sha512KDF(_ seed: [UInt8], outputLength: Int) -> [UInt8] {
        let digestBytes = 64 // SHA-512 output size
        let numBlocks = (outputLength + digestBytes - 1) / digestBytes

        var result = [UInt8]()
        for i in 1...numBlocks {
            // Counter as 4 bytes big-endian (matching Hex.pad8 which pads to 8 hex chars = 4 bytes)
            let counterBytes = withUnsafeBytes(of: UInt32(i).bigEndian) { Array($0) }
            let input = seed + counterBytes
            let hash = SHA512.hash(data: Data(input)).withUnsafeBytes { Array($0) }
            result.append(contentsOf: hash)
        }

        return Array(result.prefix(outputLength))
    }

    private static func generateRandomBytes(_ count: Int) -> [UInt8] {
        var bytes = [UInt8](repeating: 0, count: count)
        _ = SecRandomCopyBytes(kSecRandomDefault, count, &bytes)
        return bytes
    }
}
