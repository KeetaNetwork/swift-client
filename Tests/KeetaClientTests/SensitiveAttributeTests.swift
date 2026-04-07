import XCTest
import CryptoKit
import PotentASN1
@testable import KeetaClient


final class SensitiveAttributeTests: XCTestCase {

    /// Same seed used in the anchor test suite
    let seed = "D6986115BE7334E50DA8D73B1A4670A510E8BF47E8C5C9960B8F5248EC7D6E3D"

    /// Contact details matching anchor's test value
    let contactDetailsJSON = #"{"fullName":"Test User","emailAddress":"test@example.com","phoneNumber":"+1 555 911 3808"}"#

    // MARK: - Helpers

    /// Build a SensitiveAttribute DER blob that mirrors the anchor SensitiveAttributeBuilder.
    /// Uses the account's public key for encryption (works with public-key-only accounts).
    ///
    /// 1. Generate random salt (32 bytes), AES key (32 bytes), nonce (12 bytes)
    /// 2. Encrypt the AES key with account.encrypt() (only needs public key)
    /// 3. Encrypt value and salt with AES-256-GCM (ciphertext + 16-byte auth tag appended)
    /// 4. Compute hash = SHA3-256(salt || publicKeyBytes || encryptedValue || plaintext)
    /// 5. Encode as ASN.1 DER
    private func buildSensitiveAttribute(
        value: String,
        account: Account
    ) throws -> Data {
        let salt = randomBytes(32)
        let aesKey = randomBytes(32)
        let nonce = randomBytes(12)

        // Encrypt the symmetric key with ECIES (only needs public key)
        let encryptedKey = try account.encrypt(data: aesKey)

        // AES-256-GCM encrypt: value
        let plaintextBytes = Array(value.utf8)
        let encryptedValue = try aesGCMEncrypt(plaintextBytes, key: aesKey, nonce: nonce)

        // AES-256-GCM encrypt: salt
        let encryptedSalt = try aesGCMEncrypt(salt, key: aesKey, nonce: nonce)

        // Hash = SHA3-256(salt || publicKey || encryptedValue || plaintext)
        let publicKeyBytes = try account.keyPair.publicKey.toBytes()
        let hashInput = salt + publicKeyBytes + encryptedValue + plaintextBytes
        let hash: [UInt8] = Hash.create(from: hashInput)

        // Build ASN.1 DER (broken into sub-expressions to help the type checker)
        let aesGCMOid: [UInt64] = [2, 16, 840, 1, 101, 3, 4, 1, 46]
        let sha3OID: [UInt64] = [2, 16, 840, 1, 101, 3, 4, 2, 8]

        let cipherSeq: ASN1 = .sequence([
            .objectIdentifier(aesGCMOid),
            .octetString(Data(nonce)),
            .octetString(Data(encryptedKey))
        ])

        let hashSeq: ASN1 = .sequence([
            .octetString(Data(encryptedSalt)),
            .objectIdentifier(sha3OID),
            .octetString(Data(hash))
        ])

        let asn1: ASN1 = .sequence([
            .integer(0),
            cipherSeq,
            hashSeq,
            .octetString(Data(encryptedValue))
        ])

        return try ASN1Serialization.der(from: asn1)
    }

    /// AES-256-GCM encrypt, returning ciphertext + 16-byte auth tag (matching anchor convention).
    private func aesGCMEncrypt(_ plaintext: [UInt8], key: [UInt8], nonce: [UInt8]) throws -> [UInt8] {
        let sealedBox = try AES.GCM.seal(
            Data(plaintext),
            using: SymmetricKey(data: key),
            nonce: AES.GCM.Nonce(data: nonce)
        )
        // ciphertext + tag
        return Array(sealedBox.ciphertext) + Array(sealedBox.tag)
    }

    private func randomBytes(_ count: Int) -> [UInt8] {
        var bytes = [UInt8](repeating: 0, count: count)
        _ = SecRandomCopyBytes(kSecRandomDefault, count, &bytes)
        return bytes
    }

    // MARK: - Tests matching anchor's "Sensitive Attributes" test (certificates.test.ts lines 65-143)

    func test_getValueReturnsCorrectPlaintext() throws {
        let account = try AccountBuilder.create(fromSeed: seed, index: 0, algorithm: .ECDSA_SECP256K1)
        let accountNoPrivate = try AccountBuilder.create(fromPublicKey: account.publicKeyString)

        let derData = try buildSensitiveAttribute(value: contactDetailsJSON, account: accountNoPrivate)
        let attr = try SensitiveAttribute(data: derData)

        let decryptedBytes = try attr.value(account)
        let decryptedString = String(bytes: decryptedBytes, encoding: .utf8)

        XCTAssertEqual(decryptedString, contactDetailsJSON)
    }

    func test_getProofRoundTrip() throws {
        let account = try AccountBuilder.create(fromSeed: seed, index: 0, algorithm: .ECDSA_SECP256K1)
        let accountNoPrivate = try AccountBuilder.create(fromPublicKey: account.publicKeyString)

        let derData = try buildSensitiveAttribute(value: contactDetailsJSON, account: accountNoPrivate)
        let attr = try SensitiveAttribute(data: derData)

        let proof = try attr.proof(account)

        XCTAssertFalse(proof.value.isEmpty)
        XCTAssertFalse(proof.salt.isEmpty)
    }

    func test_validateProofSucceeds() throws {
        let account = try AccountBuilder.create(fromSeed: seed, index: 0, algorithm: .ECDSA_SECP256K1)
        let accountNoPrivate = try AccountBuilder.create(fromPublicKey: account.publicKeyString)

        let derData = try buildSensitiveAttribute(value: contactDetailsJSON, account: accountNoPrivate)
        let attr = try SensitiveAttribute(data: derData)

        let proof = try attr.proof(account)
        let publicKeyBytes = try accountNoPrivate.keyPair.publicKey.toBytes()
        let valid = try attr.validateProof(proof, publicKey: publicKeyBytes)

        XCTAssertTrue(valid)
    }

    func test_publicKeyOnlyCannotGetValue() throws {
        let account = try AccountBuilder.create(fromSeed: seed, index: 0, algorithm: .ECDSA_SECP256K1)
        let accountNoPrivate = try AccountBuilder.create(fromPublicKey: account.publicKeyString)

        let derData = try buildSensitiveAttribute(value: contactDetailsJSON, account: accountNoPrivate)
        let attr = try SensitiveAttribute(data: derData)

        XCTAssertThrowsError(try attr.value(accountNoPrivate))
    }

    func test_publicKeyOnlyCannotGetProof() throws {
        let account = try AccountBuilder.create(fromSeed: seed, index: 0, algorithm: .ECDSA_SECP256K1)
        let accountNoPrivate = try AccountBuilder.create(fromPublicKey: account.publicKeyString)

        let derData = try buildSensitiveAttribute(value: contactDetailsJSON, account: accountNoPrivate)
        let attr = try SensitiveAttribute(data: derData)

        XCTAssertThrowsError(try attr.proof(accountNoPrivate))
    }

    func test_wrongAccountCannotGetProof() throws {
        let account = try AccountBuilder.create(fromSeed: seed, index: 0, algorithm: .ECDSA_SECP256K1)
        let accountNoPrivate = try AccountBuilder.create(fromPublicKey: account.publicKeyString)
        let wrongAccount = try AccountBuilder.create(fromSeed: seed, index: 1, algorithm: .ECDSA_SECP256K1)

        let derData = try buildSensitiveAttribute(value: contactDetailsJSON, account: accountNoPrivate)
        let attr = try SensitiveAttribute(data: derData)

        XCTAssertThrowsError(try attr.proof(wrongAccount))
    }

    func test_validateProofFailsWithWrongValue() throws {
        let account = try AccountBuilder.create(fromSeed: seed, index: 0, algorithm: .ECDSA_SECP256K1)
        let accountNoPrivate = try AccountBuilder.create(fromPublicKey: account.publicKeyString)

        let derData = try buildSensitiveAttribute(value: contactDetailsJSON, account: accountNoPrivate)
        let attr = try SensitiveAttribute(data: derData)

        let proof = try attr.proof(account)

        // Tamper with the value (matching anchor: { ...proof, value: 'Something' })
        let tamperedProof = SensitiveAttributeProof(
            value: "Something",
            salt: proof.salt
        )

        let publicKeyBytes = try accountNoPrivate.keyPair.publicKey.toBytes()
        let valid = try attr.validateProof(tamperedProof, publicKey: publicKeyBytes)

        XCTAssertFalse(valid)
    }

    func test_validateProofFailsWithWrongPublicKey() throws {
        let account = try AccountBuilder.create(fromSeed: seed, index: 0, algorithm: .ECDSA_SECP256K1)
        let accountNoPrivate = try AccountBuilder.create(fromPublicKey: account.publicKeyString)
        let wrongAccount = try AccountBuilder.create(fromSeed: seed, index: 1, algorithm: .ECDSA_SECP256K1)

        let derData = try buildSensitiveAttribute(value: contactDetailsJSON, account: accountNoPrivate)
        let attr = try SensitiveAttribute(data: derData)

        let proof = try attr.proof(account)

        // Validate with wrong public key
        let wrongPublicKeyBytes = try wrongAccount.keyPair.publicKey.toBytes()
        let valid = try attr.validateProof(proof, publicKey: wrongPublicKeyBytes)

        XCTAssertFalse(valid)
    }

    /// Tampered DER fails validation (matching anchor: attributeBuffer.set([0x00], attributeBuffer.length - 3))
    func test_tamperedDERFailsValidation() throws {
        let account = try AccountBuilder.create(fromSeed: seed, index: 0, algorithm: .ECDSA_SECP256K1)
        let accountNoPrivate = try AccountBuilder.create(fromPublicKey: account.publicKeyString)

        let derData = try buildSensitiveAttribute(value: contactDetailsJSON, account: accountNoPrivate)
        let attr = try SensitiveAttribute(data: derData)

        let proof = try attr.proof(account)

        // Tamper with DER data (matching anchor: attributeBuffer.set([0x00], attributeBuffer.length - 3))
        var tamperedDER = Array(derData)
        tamperedDER[tamperedDER.count - 3] = 0x00
        let tamperedAttr = try SensitiveAttribute(data: Data(tamperedDER))

        let publicKeyBytes = try accountNoPrivate.keyPair.publicKey.toBytes()
        let valid = try tamperedAttr.validateProof(proof, publicKey: publicKeyBytes)

        XCTAssertFalse(valid)
    }

    // MARK: - Rust Certificate Interoperability (matching anchor certificates.test.ts lines 309-413)

    func test_rustCertificateInteroperability() throws {
        // Rust certificate DER from anchor test (certificates.test.ts)
        let rustCertBase64 = "MIIEODCCA96gAwIBAgICMDkwCgYIKoZIzj0EAwIwFzEVMBMGA1UEAxYMVGVzdCBTdWJqZWN0MCIYDzIwMjUxMDA3MjE1NzU4WhgPMjAyNjEwMDcyMTU3NThaMBcxFTATBgNVBAMWDFRlc3QgU3ViamVjdDA2MBAGByqGSM49AgEGBSuBBAAKAyIAAqZBYih/ucvv3LGVEj0SGcDjdOtWrBo62nM7M19Sy9h7o4IDNzCCAzMwDgYDVR0PAQH/BAQDAgDAMIIDHwYKKwYBBAGD6VMAAASCAw8wggMLMIIBjQYKKwYBBAGD6VMBCYGCAX0wggF5AgEAMIGtBglghkgBZQMEAS4EDKl0BkdjJD6B/4ewlwSBkQTo+AvA2SsdwRFOiyVLo/2URA9O1JaGBUx+/swbjp5R1U2Nc2EZonF4L1Ta/+7xsxw1dUG16nt/B4DtFIrwd/DqKrQgtg9ZlqgtlrUPI5OimyMwqvhYgmrxthon41veu2d0Lq8b48OV4inNgVo01a1Lu8KZnGzGqHIZM86CX5IzT/7EgZ58gdh+t+Vw6WxLHZgwXwQwRb1IRFDk7djvLMSPxKCbaURUpBbYMNMrdV/lt+q2MxaY+BuW/l5/9wblnrb/cKeQBglghkgBZQMEAggEIIBWsv91eXu1XCB7/v6odgKw5qLbKVekcu6b/BPIRzoRBGPZmphyZS8UrcGk6nIqI5xrk1P/H2QNqbNB3SxE1F7GsFk+xKTWisIgXspdQk4U5Pcwqj9egteRYBgErVM2nVazQ4H2OEyWo2xH6mouJmK3vytD4+cF7O4f+TyKFPzjoCHt1qkwggF2BgorBgEEAYPpUwECgYIBZjCCAWICAQAwga0GCWCGSAFlAwQBLgQMbuAJFU5ttXMNG4bSBIGRBC51qyxBugOTJPd1A3y2DwJWARHVp2qXZL/zsLebEIC82Jk40e9g84+f3kD5NAh49wLESDCaqfOwL2WjjgXoMR5Tvw+0wVekCpzRbYILWMfiSTdtmiu5IK+NKSaGysvlExzEH9HxUbpGkW26SJup1gPWqEg6AcKHhOysSvfTcvYBMzynlvn1G/JElLsykopYFDBfBDA8jfyuWU3zUqNJ0vjTZQV7kn7X9qIe/G8l5am1p+ro1rh7buEOR0bwpWPrQd72lOIGCWCGSAFlAwQCCAQgtqzKw4tADo1xuV0hdzTR2Q8LJQqwUHY83z5QqkrKDoIETHGeGhq2sYWdsLG/+3oM6Y+6k6MskFoY3E/G8u9RW4lHx2d4EW7NWZtehw8sQKjw2Awpul30ruSwYqFAKoPFfVczfYleYrS5Db3UehEwCgYIKoZIzj0EAwIDSAAwRQIhANHzR2nlfPL3W/Jtdajg5jJErppTvnZk70J4duzRPfWJAiBIyd5/QYMkHKXsZAnkyc8u9VsEQFr5wxa7nOVhbOJO2Q=="

        // Same account as Rust test (seed index 0, ECDSA_SECP256K1)
        let account = try AccountBuilder.create(fromSeed: seed, index: 0, algorithm: .ECDSA_SECP256K1)

        // Parse raw DER to extract the KYC extension data
        // (bypassing Certificate.create which doesn't support ecdsaWithSHA256 signature OID)
        let certDER = Data(base64Encoded: rustCertBase64)!
        let asn1 = try ASN1Serialization.asn1(fromDER: certDER)

        guard let certSequence = asn1.first?.sequenceValue,
              let tbsCert = certSequence[0].sequenceValue,
              let extensionsTagged = tbsCert[7].taggedValue else {
            XCTFail("Invalid certificate structure")
            return
        }

        let extASN1 = try ASN1Serialization.asn1(fromDER: extensionsTagged.data)
        guard let extSequence = extASN1.first?.sequenceValue else {
            XCTFail("Invalid extensions")
            return
        }

        // Find KYC extension and parse attributes using CertificateAttribute
        var kycExtensionData: ASN1?
        for ext in extSequence {
            guard let extSeq = ext.sequenceValue,
                  let oid = extSeq[0].objectIdentifierValue,
                  oid.description == OID.kyc.rawValue else { continue }
            kycExtensionData = extSeq.last
            break
        }

        guard let kycExtensionData else {
            XCTFail("KYC extension not found")
            return
        }

        let attributes = try CertificateAttribute.parseKYCExtension(kycExtensionData)

        // Verify both attributes exist and are sensitive
        guard let contactAttr = attributes[.kycContactDetails] else {
            XCTFail("contactDetails attribute not found")
            return
        }
        XCTAssertTrue(contactAttr.isSensitive)

        guard let addressAttr = attributes[.kycAddress] else {
            XCTFail("address attribute not found")
            return
        }
        XCTAssertTrue(addressAttr.isSensitive)

        // Decrypt contactDetails and verify values
        // Decrypted value is ASN.1 encoded (Rust uses ASN.1 structs with context-tagged fields)
        // ContactDetails field_order (alphabetical): 0:department, 1:emailAddress, 2:emailPurpose,
        // 3:faxNumber, 4:fullName, 5:jobResponsibility, 6:jobTitle, 7:mobileNumber, 8:namePrefix,
        // 9:other, 10:phoneNumber, 11:preferredMethod
        let contactBytes = try contactAttr.rawValue(using: account)
        let contact = try ContactDetails(from: Data(contactBytes))

        XCTAssertEqual(contact.emailAddress, "john.doe@example.com")
        XCTAssertEqual(contact.phoneNumber, "+1-555-123-4567")
        XCTAssertEqual(contact.mobileNumber, "+1-555-987-6543")
        XCTAssertEqual(contact.faxNumber, "+1-555-111-2222")

        // Verify proof generation and validation for contactDetails
        let pubKeyBytes = try account.keyPair.publicKey.toBytes()
        let contactProof = try contactAttr.proof(using: account)
        XCTAssertTrue(try contactAttr.validateProof(contactProof, publicKey: pubKeyBytes))

        // Decrypt address and verify values
        // Address field_order (alphabetical): 0:addressLines, 1:addressType, 2:buildingNumber,
        // 3:country, 4:countrySubDivision, 5:department, 6:postalCode, 7:streetName,
        // 8:subDepartment, 9:townName
        let addressBytes = try addressAttr.rawValue(using: account)
        let address = try Address(from: Data(addressBytes))

        XCTAssertEqual(address.postalCode, "12345")
        XCTAssertEqual(address.townName, "Springfield")
        XCTAssertEqual(address.country, "US")
        XCTAssertEqual(address.streetName, "Main Street")
        XCTAssertEqual(address.buildingNumber, "123")
        XCTAssertEqual(address.countrySubDivision, "IL")

        // Verify proof generation and validation for address
        let addressProof = try addressAttr.proof(using: account)
        XCTAssertTrue(try addressAttr.validateProof(addressProof, publicKey: pubKeyBytes))
    }

    // MARK: - Algorithm coverage (matching anchor Certificates test verifyAttribute pattern)

    func test_verifyAttributeAllAlgorithms() throws {
        let algorithms: [Account.KeyAlgorithm] = [.ECDSA_SECP256K1, .ECDSA_SECP256R1, .ED25519]

        for algorithm in algorithms {
            let account = try AccountBuilder.create(fromSeed: seed, index: 0, algorithm: algorithm)
            let accountNoPrivate = try AccountBuilder.create(fromPublicKey: account.publicKeyString)

            let derData = try buildSensitiveAttribute(value: contactDetailsJSON, account: accountNoPrivate)
            let attr = try SensitiveAttribute(data: derData)

            // Private key account can getValue
            let decryptedBytes = try attr.value(account)
            XCTAssertEqual(String(bytes: decryptedBytes, encoding: .utf8), contactDetailsJSON, "getValue failed for \(algorithm)")

            // Private key account can getProof
            let proof = try attr.proof(account)

            // Public key can validateProof
            let publicKeyBytes = try accountNoPrivate.keyPair.publicKey.toBytes()
            let valid = try attr.validateProof(proof, publicKey: publicKeyBytes)
            XCTAssertTrue(valid, "validateProof failed for \(algorithm)")

            // Public key only cannot getValue
            XCTAssertThrowsError(try attr.value(accountNoPrivate), "Expected getValue to throw for public-key-only \(algorithm)")

            // Public key only cannot getProof
            XCTAssertThrowsError(try attr.proof(accountNoPrivate), "Expected getProof to throw for public-key-only \(algorithm)")
        }
    }
}
