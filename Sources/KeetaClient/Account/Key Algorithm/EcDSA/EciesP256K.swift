import Foundation
import P256K
import CryptoSwift
import CryptoKit

/// ECIES implementation for secp256k1, compatible with the ecies-geth npm library.
///
/// Wire format: [ephemeralPubKey(65)] + [IV(16) + ciphertext] + [HMAC(32)]
///
/// Encryption:
/// 1. Generate ephemeral secp256k1 key pair
/// 2. ECDH: Px = x-coordinate of (ephemeralPrivate × recipientPublic)
/// 3. KDF: hash = SHA256-counter-KDF(Px, 32 bytes)
/// 4. encKey = hash[0:16], macKey = SHA256(hash[16:32])
/// 5. Encrypt: AES-128-CTR(plaintext, encKey, randomIV)
/// 6. MAC: HMAC-SHA256(macKey, IV + ciphertext)
/// 7. Output: ephemPubKey || (IV + ciphertext) || HMAC
struct EciesP256K: Encryptable {

    private static let ephemeralKeyLength = 65  // uncompressed
    private static let ivLength = 16
    private static let macLength = 32
    private static let encKeyLength = 16
    private static let kdfOutputLength = 32

    static func encrypt(data: [UInt8], publicKey: [UInt8]) throws -> [UInt8] {
        // Generate ephemeral key pair (uncompressed format for 65-byte public key)
        let ephemeralPrivate = try P256K.KeyAgreement.PrivateKey(format: .uncompressed)
        let ephemeralPublicBytes = Array(ephemeralPrivate.publicKey.dataRepresentation)

        // Recipient public key (convert from compressed to KeyAgreement format)
        let recipientPublic = try P256K.KeyAgreement.PublicKey(
            dataRepresentation: publicKey,
            format: .compressed
        )

        // ECDH shared secret — extract only the x-coordinate (Px, 32 bytes)
        // to match ecies-geth which uses keyA.derive(keyB.getPublic()) returning Px
        let sharedSecret = try ephemeralPrivate.sharedSecretFromKeyAgreement(
            with: recipientPublic,
            format: .compressed
        )
        let sharedCompressed = sharedSecret.withUnsafeBytes { Array($0) }
        let sharedPx = Array(sharedCompressed.dropFirst()) // strip version byte → 32-byte x-coordinate

        // Derive keys using SHA256 counter-mode KDF (Geth style)
        let derived = sha256KDF(sharedPx, outputLength: kdfOutputLength)

        let encKey = Array(derived[0..<encKeyLength])
        let macKeyInput = Array(derived[encKeyLength..<kdfOutputLength])
        let macKey = CryptoKit.SHA256.hash(data: Data(macKeyInput)).withUnsafeBytes { Array($0) }

        // Encrypt with AES-128-CTR
        let iv = generateRandomBytes(ivLength)
        let ciphertext = try AES(key: encKey, blockMode: CTR(iv: iv), padding: .noPadding).encrypt(data)

        // HMAC-SHA256 over IV + ciphertext
        let hmacInput = iv + ciphertext
        let hmac = CryptoKit.HMAC<CryptoKit.SHA256>.authenticationCode(
            for: Data(hmacInput),
            using: SymmetricKey(data: Data(macKey))
        ).withUnsafeBytes { Array($0) }

        // Wire format: ephemPubKey(65) || IV(16) + ciphertext || HMAC(32)
        return ephemeralPublicBytes + iv + ciphertext + hmac
    }

    static func decrypt(data: [UInt8], privateKey: [UInt8]) throws -> [UInt8] {
        // Minimum length: 65 (ephemKey) + 16 (IV) + 32 (HMAC) = 113
        guard data.count > ephemeralKeyLength + ivLength + macLength else {
            throw EncryptionError.invalidCiphertext
        }

        // Parse wire format
        let ephemPubKeyBytes = Array(data[0..<ephemeralKeyLength])
        guard ephemPubKeyBytes[0] == 0x04 else {
            throw EncryptionError.invalidEphemeralKey
        }

        let ivAndCiphertext = Array(data[ephemeralKeyLength..<(data.count - macLength)])
        let receivedHmac = Array(data[(data.count - macLength)...])

        let iv = Array(ivAndCiphertext[0..<ivLength])
        let ciphertext = Array(ivAndCiphertext[ivLength...])

        // ECDH
        let privateKeyObj = try P256K.KeyAgreement.PrivateKey(dataRepresentation: privateKey)
        let ephemeralPublic = try P256K.KeyAgreement.PublicKey(
            dataRepresentation: ephemPubKeyBytes,
            format: .uncompressed
        )

        // ECDH — extract only x-coordinate (Px, 32 bytes) to match ecies-geth
        let sharedSecret = try privateKeyObj.sharedSecretFromKeyAgreement(
            with: ephemeralPublic,
            format: .compressed
        )
        let sharedCompressed = sharedSecret.withUnsafeBytes { Array($0) }
        let sharedPx = Array(sharedCompressed.dropFirst()) // strip version byte

        // Derive keys
        let derived = sha256KDF(sharedPx, outputLength: kdfOutputLength)

        let encKey = Array(derived[0..<encKeyLength])
        let macKeyInput = Array(derived[encKeyLength..<kdfOutputLength])
        let macKey = CryptoKit.SHA256.hash(data: Data(macKeyInput)).withUnsafeBytes { Array($0) }

        // Verify HMAC
        let expectedHmac = CryptoKit.HMAC<CryptoKit.SHA256>.authenticationCode(
            for: Data(ivAndCiphertext),
            using: SymmetricKey(data: Data(macKey))
        ).withUnsafeBytes { Array($0) }

        guard expectedHmac == receivedHmac else {
            throw EncryptionError.hmacVerificationFailed
        }

        // Decrypt
        let plaintext = try AES(key: encKey, blockMode: CTR(iv: iv), padding: .noPadding).decrypt(ciphertext)
        return plaintext
    }

    /// SHA256-based counter mode KDF (compatible with ecies-geth / Ethereum)
    /// counter starts at 1, output = SHA256(counter_be32 || shared) truncated to outputLength
    private static func sha256KDF(_ shared: [UInt8], outputLength: Int) -> [UInt8] {
        var result = [UInt8]()
        var counter: UInt32 = 1

        while result.count < outputLength {
            let counterBytes = withUnsafeBytes(of: counter.bigEndian) { Array($0) }
            let input = counterBytes + shared
            let hash = CryptoKit.SHA256.hash(data: Data(input)).withUnsafeBytes { Array($0) }
            result.append(contentsOf: hash)
            counter += 1
        }

        return Array(result.prefix(outputLength))
    }

    private static func generateRandomBytes(_ count: Int) -> [UInt8] {
        var bytes = [UInt8](repeating: 0, count: count)
        _ = SecRandomCopyBytes(kSecRandomDefault, count, &bytes)
        return bytes
    }
}
