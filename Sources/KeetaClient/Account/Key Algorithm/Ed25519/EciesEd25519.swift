import Foundation
import CryptoKit
import CryptoSwift
import BigInt

/// ECIES implementation for Ed25519 keys, compatible with the ecies-25519 npm library.
///
/// Ed25519 keys are converted to X25519 (Curve25519) for key agreement.
///
/// Wire format: [IV(16)] + [ephemeralPubKey(32)] + [MAC(32)] + [ciphertext]
///
/// Encryption:
/// 1. Generate ephemeral X25519 key pair
/// 2. ECDH: shared = X25519(ephemeralPrivate, recipientX25519Public)
/// 3. KDF: hash = SHA-512(shared) → 64 bytes
/// 4. encKey = hash[0:32], macKey = hash[32:64]
/// 5. Encrypt: AES-256-CBC(plaintext, encKey, randomIV) with PKCS7
/// 6. MAC: HMAC-SHA256(macKey, IV + ephemPubKey + ciphertext)
/// 7. Output: IV || ephemPubKey || MAC || ciphertext
struct EciesEd25519: Encryptable {

    private static let ivLength = 16
    private static let publicKeyLength = 32
    private static let macLength = 32

    static func encrypt(data: [UInt8], publicKey: [UInt8]) throws -> [UInt8] {
        // Convert Ed25519 public key to X25519
        let x25519Public = try ed25519PublicToX25519(publicKey)
        let recipientKey = try Curve25519.KeyAgreement.PublicKey(rawRepresentation: x25519Public)

        // Generate ephemeral X25519 key pair
        let ephemeralPrivate = Curve25519.KeyAgreement.PrivateKey()
        let ephemeralPublicBytes = Array(ephemeralPrivate.publicKey.rawRepresentation)

        // ECDH
        let sharedSecret = try ephemeralPrivate.sharedSecretFromKeyAgreement(with: recipientKey)
        let sharedBytes = sharedSecret.withUnsafeBytes { Array($0) }

        // KDF: SHA-512(sharedSecret) — compatible with ecies-25519 / iso-crypto
        let derived = Array(SHA512.hash(data: Data(sharedBytes)).withUnsafeBytes { Array($0) })
        let encKey = Array(derived[0..<32])
        let macKey = Array(derived[32..<64])

        // Encrypt AES-256-CBC with PKCS7
        let iv = generateRandomBytes(ivLength)
        let ciphertext = try AES(key: encKey, blockMode: CBC(iv: iv), padding: .pkcs7).encrypt(data)

        // HMAC-SHA256(macKey, IV + ephemPubKey + ciphertext)
        let hmacInput = iv + ephemeralPublicBytes + ciphertext
        let hmac = CryptoKit.HMAC<SHA256>.authenticationCode(
            for: Data(hmacInput),
            using: SymmetricKey(data: Data(macKey))
        ).withUnsafeBytes { Array($0) }

        // Wire format: IV(16) || ephemPubKey(32) || MAC(32) || ciphertext
        return iv + ephemeralPublicBytes + hmac + ciphertext
    }

    static func decrypt(data: [UInt8], privateKey: [UInt8]) throws -> [UInt8] {
        // Minimum: 16 (IV) + 32 (pubkey) + 32 (MAC) = 80 bytes + at least 1 block
        guard data.count > ivLength + publicKeyLength + macLength else {
            throw EncryptionError.invalidCiphertext
        }

        // Parse wire format
        let iv = Array(data[0..<ivLength])
        let ephemPubKeyBytes = Array(data[ivLength..<(ivLength + publicKeyLength)])
        let receivedMac = Array(data[(ivLength + publicKeyLength)..<(ivLength + publicKeyLength + macLength)])
        let ciphertext = Array(data[(ivLength + publicKeyLength + macLength)...])

        // Convert Ed25519 private key to X25519
        // Ed25519 private key is 64 bytes (seed + public), we need the 32-byte seed
        let seed = Array(privateKey.prefix(32))
        let x25519Private = try ed25519PrivateToX25519(seed)
        let x25519PrivateKey = try Curve25519.KeyAgreement.PrivateKey(rawRepresentation: x25519Private)

        // Ephemeral key is already X25519
        let ephemeralPublic = try Curve25519.KeyAgreement.PublicKey(rawRepresentation: ephemPubKeyBytes)

        // ECDH
        let sharedSecret = try x25519PrivateKey.sharedSecretFromKeyAgreement(with: ephemeralPublic)
        let sharedBytes = sharedSecret.withUnsafeBytes { Array($0) }

        // KDF: SHA-512(sharedSecret) — compatible with ecies-25519 / iso-crypto
        let derived = Array(SHA512.hash(data: Data(sharedBytes)).withUnsafeBytes { Array($0) })
        let encKey = Array(derived[0..<32])
        let macKey = Array(derived[32..<64])

        // Verify HMAC
        let hmacInput = iv + ephemPubKeyBytes + ciphertext
        let expectedMac = CryptoKit.HMAC<SHA256>.authenticationCode(
            for: Data(hmacInput),
            using: SymmetricKey(data: Data(macKey))
        ).withUnsafeBytes { Array($0) }

        guard expectedMac == receivedMac else {
            throw EncryptionError.hmacVerificationFailed
        }

        // Decrypt AES-256-CBC
        let plaintext = try AES(key: encKey, blockMode: CBC(iv: iv), padding: .pkcs7).decrypt(ciphertext)
        return plaintext
    }

    // MARK: - Ed25519 → X25519 Key Conversion (ed2curve)

    /// Convert an Ed25519 public key (32 bytes) to an X25519 public key (32 bytes).
    /// This uses the birational map from the Edwards curve to the Montgomery curve.
    /// Formula: u = (1 + y) / (1 - y) mod p
    /// where p = 2^255 - 19
    static func ed25519PublicToX25519(_ edPublicKey: [UInt8]) throws -> [UInt8] {
        guard edPublicKey.count == 32 else {
            throw EncryptionError.invalidPublicKeyFormat
        }

        // Decode the y coordinate (little-endian, clear top bit)
        var yBytes = edPublicKey
        yBytes[31] &= 0x7F

        let y = bytesToFieldElement(yBytes)
        let p = fieldPrime

        // u = (1 + y) * modInverse(1 - y, p) mod p
        let numerator = (y + 1) % p
        let denominator = (p + 1 - y) % p
        let u = (numerator * denominator.inverse(p)!) % p

        return fieldElementToBytes(u)
    }

    /// Convert an Ed25519 private key seed (32 bytes) to an X25519 private key (32 bytes).
    /// The Ed25519 private key is hashed with SHA-512, then the first 32 bytes are clamped.
    static func ed25519PrivateToX25519(_ seed: [UInt8]) throws -> [UInt8] {
        guard seed.count == 32 else {
            throw EncryptionError.noPrivateKey
        }

        let hash = Array(SHA512.hash(data: Data(seed)).withUnsafeBytes { Array($0) })
        var x25519Key = Array(hash[0..<32])

        // Clamp
        x25519Key[0] &= 248
        x25519Key[31] &= 127
        x25519Key[31] |= 64

        return x25519Key
    }

    // MARK: - Field Arithmetic for Curve25519 (using BigInt)

    /// p = 2^255 - 19
    private static let fieldPrime: BigUInt = {
        BigUInt(1) << 255 - 19
    }()

    private static func bytesToFieldElement(_ bytes: [UInt8]) -> BigUInt {
        // Little-endian bytes to BigUInt
        BigUInt(Data(bytes.reversed()))
    }

    private static func fieldElementToBytes(_ value: BigUInt) -> [UInt8] {
        // BigUInt to 32 little-endian bytes
        let bigEndianBytes = value.serialize()
        var result = [UInt8](repeating: 0, count: 32)
        for (i, byte) in bigEndianBytes.reversed().enumerated() where i < 32 {
            result[i] = byte
        }
        return result
    }

    private static func generateRandomBytes(_ count: Int) -> [UInt8] {
        var bytes = [UInt8](repeating: 0, count: count)
        _ = SecRandomCopyBytes(kSecRandomDefault, count, &bytes)
        return bytes
    }
}
