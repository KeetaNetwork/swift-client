import Foundation
import PotentASN1
import CryptoKit
import CryptoSwift

public enum SensitiveAttributeError: Error {
    case invalidASN1Structure
    case unsupportedVersion(Int)
    case unsupportedCipherAlgorithm(String)
    case unsupportedHashAlgorithm(String)
    case missingOctetString
    case missingOID
    case decryptionFailed
    case invalidGCMData
}

/// A proof that a sensitive attribute has a given value.
/// Can be validated by a third party using the certificate.
public struct SensitiveAttributeProof {
    /// Base64-encoded plaintext value
    public let value: String
    /// Base64-encoded salt used in the hash
    public let salt: String

    public init(value: String, salt: String) {
        self.value = value
        self.salt = salt
    }
}

/* Represents a sensitive (encrypted) attribute from a KYC certificate extension.

 SensitiveAttribute ::= SEQUENCE {
     version        INTEGER { v1(0) },
     cipher         SEQUENCE {
         algorithm    OBJECT IDENTIFIER,
         ivOrNonce    OCTET STRING,
         key          OCTET STRING
     },
     hashedValue    SEQUENCE {
         encryptedSalt  OCTET STRING,
         algorithm      OBJECT IDENTIFIER,
         value          OCTET STRING
     },
     encryptedValue OCTET STRING
 }
 */


public struct SensitiveAttribute {

    let cipherAlgorithmOID: OID
    let iv: [UInt8]
    let encryptedKey: [UInt8]
    let encryptedSalt: [UInt8]
    let hashAlgorithmOID: OID
    let hash: [UInt8]
    let encryptedValue: [UInt8]

    /// Parse a SensitiveAttribute from DER-encoded data.
    public init(data: Data) throws {
        let asn1 = try ASN1Serialization.asn1(fromDER: data)

        guard let sequence = asn1.first?.sequenceValue, sequence.count == 4 else {
            throw SensitiveAttributeError.invalidASN1Structure
        }

        // Version (INTEGER, 0 = v1)
        guard let version = sequence[0].integerValue else {
            throw SensitiveAttributeError.invalidASN1Structure
        }
        guard version == 0 else {
            throw SensitiveAttributeError.unsupportedVersion(Int(version) + 1)
        }

        // Cipher SEQUENCE { algorithm OID, iv OCTET_STRING, key OCTET_STRING }
        guard let cipherSeq = sequence[1].sequenceValue, cipherSeq.count == 3 else {
            throw SensitiveAttributeError.invalidASN1Structure
        }

        guard let cipherOidValue = cipherSeq[0].objectIdentifierValue,
              let cipherOid = OID(rawValue: cipherOidValue.description) else {
            throw SensitiveAttributeError.missingOID
        }
        guard let ivData = cipherSeq[1].octetStringValue else {
            throw SensitiveAttributeError.missingOctetString
        }
        guard let encryptedKeyData = cipherSeq[2].octetStringValue else {
            throw SensitiveAttributeError.missingOctetString
        }

        // HashedValue SEQUENCE { encryptedSalt OCTET_STRING, algorithm OID, hash OCTET_STRING }
        guard let hashSeq = sequence[2].sequenceValue, hashSeq.count == 3 else {
            throw SensitiveAttributeError.invalidASN1Structure
        }

        guard let encryptedSaltData = hashSeq[0].octetStringValue else {
            throw SensitiveAttributeError.missingOctetString
        }
        guard let hashOidValue = hashSeq[1].objectIdentifierValue,
              let hashOid = OID(rawValue: hashOidValue.description) else {
            throw SensitiveAttributeError.missingOID
        }
        guard let hashData = hashSeq[2].octetStringValue else {
            throw SensitiveAttributeError.missingOctetString
        }

        // EncryptedValue OCTET_STRING
        guard let encryptedValueData = sequence[3].octetStringValue else {
            throw SensitiveAttributeError.missingOctetString
        }

        self.cipherAlgorithmOID = cipherOid
        self.iv = ivData.bytes
        self.encryptedKey = encryptedKeyData.bytes
        self.encryptedSalt = encryptedSaltData.bytes
        self.hashAlgorithmOID = hashOid
        self.hash = hashData.bytes
        self.encryptedValue = encryptedValueData.bytes
    }

    /// Decrypt a value using the account's private key and the cipher parameters.
    private func decryptValue(_ encrypted: [UInt8], account: Account) throws -> [UInt8] {
        // Decrypt the symmetric key using the account's ECIES decryption
        let decryptedKey = try account.decrypt(data: encryptedKey)

        switch cipherAlgorithmOID {
        case .aes256GCM:
            return try decryptAES256GCM(encrypted, key: decryptedKey, nonce: iv)
        default:
            throw SensitiveAttributeError.unsupportedCipherAlgorithm(cipherAlgorithmOID.rawValue)
        }
    }

    /// Decrypt AES-256-GCM data where the last 16 bytes are the authentication tag.
    private func decryptAES256GCM(_ data: [UInt8], key: [UInt8], nonce: [UInt8]) throws -> [UInt8] {
        guard data.count > 16 else {
            throw SensitiveAttributeError.invalidGCMData
        }

        let ciphertext = Array(data[0..<(data.count - 16)])
        let tag = Array(data[(data.count - 16)...])

        let sealedBox = try CryptoKit.AES.GCM.SealedBox(
            nonce: AES.GCM.Nonce(data: nonce),
            ciphertext: ciphertext,
            tag: tag
        )

        let decrypted = try CryptoKit.AES.GCM.open(sealedBox, using: SymmetricKey(data: key))
        return Array(decrypted)
    }

    /// Get the decrypted plaintext value.
    public func value(_ account: Account) throws -> [UInt8] {
        try decryptValue(encryptedValue, account: account)
    }

    /// Generate a proof that this sensitive attribute has a given value.
    /// The proof can be validated by a third party using `validateProof`.
    public func proof(_ account: Account) throws -> SensitiveAttributeProof {
        let value = try decryptValue(encryptedValue, account: account)
        let salt = try decryptValue(encryptedSalt, account: account)

        return SensitiveAttributeProof(
            value: Data(value).base64EncodedString(),
            salt: Data(salt).base64EncodedString()
        )
    }

    /// Validate a proof against the stored hash.
    ///
    /// Reconstructs: `hash = SHA3-256(salt || publicKey || encryptedValue || plaintextValue)`
    /// and compares against the stored hash.
    public func validateProof(_ proof: SensitiveAttributeProof, publicKey: [UInt8]) throws -> Bool {
        guard hashAlgorithmOID == .sha3_256 else {
            throw SensitiveAttributeError.unsupportedHashAlgorithm(hashAlgorithmOID.rawValue)
        }

        guard let plaintextValue = Data(base64Encoded: proof.value),
              let proofSalt = Data(base64Encoded: proof.salt) else {
            return false
        }

        let hashInput = Array(proofSalt) + publicKey + encryptedValue + Array(plaintextValue)
        let computedHash: [UInt8] = Hash.create(from: hashInput)

        return computedHash == hash
    }
}
