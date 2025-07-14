import XCTest
import KeetaClient

final class AccountBuilderTests: XCTestCase {
    
    struct PublicAccountConfig {
        let keyAlgorithm: Account.KeyAlgorithm
        let publicKey: String
        let encodedPublicKey: String
    }
    
    let publicAccounts: [PublicAccountConfig] = [
        .init(
            keyAlgorithm: .ECDSA_SECP256K1,
            publicKey: "020F2115FA0C9A10680AEECB64AB2E0564AED1AF821A72BF987AABF87A1AD68251",
            encodedPublicKey: "keeta_aaba6iiv7igjuediblxmwzflfycwjlwrv6bbu4v7tb5kx6d2dllieunedvq3cza"
        ),
        .init(
            keyAlgorithm: .ED25519,
            publicKey: "0F2115FA0C9A10680AEECB64AB2E0564AED1AF821A72BF987AABF87A1AD68251",
            encodedPublicKey: "keeta_aehscfp2bsnba2ak53fwjkzoavsk5unpqinhfp4ypkv7q6q222bfcko6njrbw"
        ),
        .init(
            keyAlgorithm: .NETWORK,
            publicKey: "372D46C3ADA9F897C74D349BBFE0E450C798167C9F580F8DAF85DEF57E96C3EA",
            encodedPublicKey: "keeta_ai3s2rwdvwu7rf6hju2jxp7a4rimpgawpspvqd4nv6c555l6s3b6uj6cr5klc"
        ),
        .init(
            keyAlgorithm: .TOKEN,
            publicKey: "724E371B944A48E95B91EE059B7CB7110E5866CA707915C287C49CAB9B774AF1",
            encodedPublicKey: "keeta_anze4ny3srfer2k3shxalg34w4iq4wdgzjyhsfocq7cjzk43o5fpc2igkuifg"
        ),
    ]
    
    struct AccountConfig {
        let seed: String
        let index: Int
        let publicKey: String
        let privateKey: String
        let publicKeyString: String
        let algorithm: Account.KeyAlgorithm
    }
    
    let accountConfigs: [AccountConfig] = [
        .init(
            seed: "2401D206735C20485347B9A622D94DE9B21F2F1450A77C42102237FA4077567D",
            index: 0,
            publicKey: "02157AB0EB13544F1583635CF8DB2ED31FE9D029206E160100392EC91288D653A8",
            privateKey: "EEE6ABBC24F7FBB5A7035ABF27D6C389E94E4FF06D1A8948FDA56B4DC2D05794",
            publicKeyString: "keeta_aabbk6vq5mjvityvqnrvz6g3f3jr72oqfeqg4fqbaa4s5sisrdlfhkfr5p7chey",
            algorithm: .ECDSA_SECP256K1
        ),
        .init(
            seed: "2401D206735C20485347B9A622D94DE9B21F2F1450A77C42102237FA4077567D",
            index: 1,
            publicKey: "0246B9851DF9019A4F2B16B0367ADBE1D0C09E37F84163A6173479E44BE94DDC8E",
            privateKey: "6FF01C1B8092A715DF4231AD531CA1101FA941E49BD76EADE0DA047D5333E20E",
            publicKeyString: "keeta_aabenomfdx4qdgspfmllant23pq5bqe6g74ecy5gc42htzcl5fg5zdr55yndzra",
            algorithm: .ECDSA_SECP256K1
        ),
        .init(
            seed: "2401D206735C20485347B9A622D94DE9B21F2F1450A77C42102237FA4077567D",
            index: 0,
            publicKey: "C4FE1EC7D784869E485827E9A1CB21553ECD70570818DD367B86ACA295BC49BB",
            privateKey: "F0FAAE6AF2A3B84296F5B3216B4A7CB30228FC4593AAA10317D16C6412C9F05F",
            publicKeyString: "keeta_ahcp4hwh26cinhsilat6tiolefkt5tlqk4ebrxjwpodkziuvxre3x3r2wf5l6",
            algorithm: .ED25519
        ),
        .init(
            seed: "2401D206735C20485347B9A622D94DE9B21F2F1450A77C42102237FA4077567D",
            index: 1,
            publicKey: "8462D010DAE2934F29DD6DA88A58E80ACD2B1F69D81834F141FC25FA9CCDD2D9",
            privateKey: "6823B06E9A84281499ADDFF3719B7A530B8E8C9764629858C73DCA7844675346",
            publicKeyString: "keeta_agcgfuaq3lrjgtzj3vw2rcsy5afm2ky7nhmbqnhrih6cl6u4zxjntb2x72hc2",
            algorithm: .ED25519
        )
    ]
    
    let invalidPublicKeys: [(key: String, error: Error)] = [
        ("keeta_cqaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaabibevehoy", AccountError.invalidPublicKeyAlgo(key: "20")),
        ("keeta_aguijv77cohs3fks62isqa4ywdvwlyhfddwpq4pqnvl6lssoyug2k7vkqfwuk", AccountBuilderError.invalidPublicKeyChecksum),
        ("keeta_aguijv77cohs3fks62isqa4ywdvwlyhfddwpq4pqnvl6lssoyug2k7vkqfwu", AccountError.invalidPublicKeyLength(length: 60)),
        ("0xadkee277rhdznsvjpnejiaomlb23f4dsrr3hyohyg2v7fzjhmkdnfp2vic3ke", AccountBuilderError.invalidPublicKeyPrefix),
        ("notkeeta_adkee277rhdznsvjpnejiaomlb23f4dsrr3hyohyg2v7fzjhmkdnfp2vic3ke", AccountBuilderError.invalidPublicKeyPrefix),
        ("A884D7FF138F2D9552F691280398B0EB65E0E518ECF871F06D57E5CA4EC50DA5", AccountBuilderError.invalidPublicKeyPrefix)
    ]
    
    let invalidIndexes: [(index: Int, error: AccountBuilderError)] = [
        (-1, .seedIndexNegative),
        (.max, .seedIndexTooLarge)
    ]
    
    func test_createAccountsFromSeed() throws {
        for config in accountConfigs {
            let account = try AccountBuilder.create(fromSeed: config.seed, index: config.index, algorithm: config.algorithm)
            
            let expected = KeyPair(publicKey: config.publicKey, privateKey: config.privateKey)
            
            XCTAssertEqual(account.keyPair, expected)
            XCTAssertEqual(account.keyAlgorithm, config.algorithm)
            XCTAssertEqual(account.publicKeyString, config.publicKeyString)
        }
    }
    
    func test_tryToCreateAccountWithInvalidPublicKeys() {
        invalidPublicKeys.forEach { config in
            captureError(config.error, failure: "Public key should be invalid: \(config.key)") {
                _ = try AccountBuilder.create(fromPublicKey: config.key)
            }
        }
    }
    
    func test_createAccountFromPublicKeys() throws {
        for config in publicAccounts {
            do {
                let account = try AccountBuilder.create(fromPublicKey: config.encodedPublicKey)
                
                XCTAssertEqual(account.keyAlgorithm, config.keyAlgorithm)
                XCTAssertEqual(account.keyPair, .init(publicKey: config.publicKey, privateKey: nil))
            } catch {
                XCTFail("Failed for \(config)\n\(error)")
            }
        }
    }
    
    func test_createAccountsFromPrivateKeys() throws {
        for config in accountConfigs {
            let account = try AccountBuilder.create(fromPrivateKey: config.privateKey, algorithm: config.algorithm)
            
            XCTAssertEqual(account.keyPair, .init(publicKey: config.publicKey, privateKey: config.privateKey))
            XCTAssertEqual(account.keyAlgorithm, config.algorithm)
        }
    }
    
    func test_tryToCreateAccountWithInvalidIndex() {
        let seed = "2401D206735C20485347B9A622D94DE9B21F2F1450A77C42102237FA4077567D"
        
        invalidIndexes.forEach { config in
            captureError(config.error, failure: "Index should be invalid: \(config.index)") {
                _ = try AccountBuilder.create(fromSeed: seed, index: config.index)
            }
        }
    }
    
    func test_accountSignAndVerifyData() throws {
        let seed = "2401D206735C20485347B9A622D94DE9B21F2F1450A77C42102237FA4077567D"
        let data = try XCTUnwrap("Some random test data".data(using: .utf8))
        
        let accountAlgorithms: [Account.KeyAlgorithm] = [.ECDSA_SECP256K1, .ED25519]
        
        for (index, algorithm) in accountAlgorithms.enumerated() {
            let account = try AccountBuilder.create(fromSeed: seed, index: index, algorithm: algorithm)
            
            /**
             * Generate a valid signature and validate it
             */
            let signature = try account.sign(data: data)
            let valid = try account.verify(data: data, signature: signature)
            XCTAssertTrue(valid, "Account Type: \(algorithm)")
            XCTAssertFalse(signature.isEmpty)
            
            /**
             * Modify that signature and verify that it cannot be validated
             */
            var invalidSignature = signature
            invalidSignature[1] += 1
            let updatedValue1 = Int(invalidSignature[1]) % 256
            invalidSignature[1] = .init(updatedValue1)
            do {
                let invalid1 = try account.verify(data: data, signature: invalidSignature)
                XCTAssertFalse(invalid1, "Signature should be invalid.")
            } catch {}
            
            /**
             * Modify the data and verify that the signature cannot be validated
             */
            var invalidData = data.bytes
            invalidData[1] += 1
            let updatedValue2 = Int(invalidData[1]) % 256
            invalidData[1] = .init(updatedValue2)
            let invalid2 = try account.verify(data: .init(invalidData), signature: signature)
            XCTAssertFalse(invalid2)
        }
    }
    
    func test_signAndVerificationWithPublicKeyAndOptions() throws {
        let privateKey = "50A44F48CF187E47483614BDA872E9405D36FE0DDF0ADA0FAE5982BDFBE9EF13"
        let accountAlgorithms: [Account.KeyAlgorithm] = [.ECDSA_SECP256K1, .ED25519]
        let data = try XCTUnwrap("Some random test data".data(using: .utf8))
        
        for (algorithm) in accountAlgorithms {
            let account = try AccountBuilder.create(fromPrivateKey: privateKey, algorithm: algorithm)
            
            let signature1 = try account.sign(data: data)
            let verified1 = try account.verify(data: data, signature: signature1)
            XCTAssertTrue(verified1)
            
            let hashedData = Data(Hash.create(from: data.bytes))
            let signature2 = try account.sign(data: hashedData, options: .init(raw: true, forCert: false))
            let verified2 = try account.verify(data: hashedData, signature: signature2, options: .init(raw: true, forCert: false))
            XCTAssertTrue(verified2)
            
            let encodedPublicKey = "keeta_aabm7moneqqjpaaee5vxjqoe5f2ay3dchgr2hysdfh4wg3ycylohabivswjyfci"
            let accountFromPublic = try AccountBuilder.create(fromPublicKey: encodedPublicKey)
            
            let verified3 = try accountFromPublic.verify(data: hashedData, signature: signature2)
            XCTAssertFalse(verified3)
            
            captureError(AccountError.invalidDataLength, failure: "Unhashed data shouldn't be verifiable.") {
                _ = try account.verify(data: data, signature: signature1, options: .init(raw: true, forCert: false))
            }
        }
    }
    
    func test_accountVerifyNodeSignature_ECDSA() throws {
        let data = try XCTUnwrap("Some random test data".data(using: .utf8))
        
        let signature = try "C0879BE652D4292DDDC6A183711F99ED1E0293C824651F8374365375990A2E7B35E0F21D156346118E1932117482F7A9145075442FCC91C28946F65CCDAC04BE"
            .toBytes()
        
        let privateKey = "50A44F48CF187E47483614BDA872E9405D36FE0DDF0ADA0FAE5982BDFBE9EF13"
        let account = try AccountBuilder.create(fromPrivateKey: privateKey, algorithm: .ECDSA_SECP256K1)
        
        let verified = try account.verify(data: data, signature: signature)
        XCTAssertTrue(verified)
    }
    
    func test_accountVerifyOpenSSLCert() throws {
        let privateKey = "50A44F48CF187E47483614BDA872E9405D36FE0DDF0ADA0FAE5982BDFBE9EF13"
        let account = try AccountBuilder.create(fromPrivateKey: privateKey, algorithm: .ECDSA_SECP256K1)
        
        /**
         * "Some random test data"
         */
        let data: [UInt8] = [
            83, 111, 109, 101,  32, 114,
            97, 110, 100, 111, 109,  32,
            116, 101, 115, 116,  32, 100,
            97, 116,  97
        ]
        
        /**
         * Generated from OpenSSL: openssl dgst -sha3-256 -sign test.key data.txt
         */
        let signature: [UInt8] = [
            0x5C, 0xDC, 0x7C, 0x59, 0xE0, 0x9C, 0xDD, 0x1A, 0xE1, 0xE5,
            0xC8, 0xD5, 0x21, 0x1E, 0xFA, 0x09, 0x25, 0x31, 0x92, 0x42,
            0x50, 0xE1, 0x56, 0x26, 0x66, 0x00, 0xCB, 0xDC, 0x69, 0xBF,
            0x9F, 0xED, 0x5C, 0x28, 0x5F, 0x33, 0x9E, 0x17, 0xDA, 0xA2,
            0xFC, 0xAC, 0xED, 0x7C, 0xD3, 0xAC, 0x40, 0x3C, 0x9E, 0xFE,
            0x98, 0x39, 0x24, 0x87, 0xF4, 0xEA, 0x15, 0x51, 0xEC, 0xCB,
            0x5D, 0xBC, 0x97, 0x4F
        ]
        
        let verified = try account.verify(data: .init(data), signature: signature)
        XCTAssertTrue(verified)
        
        /**
         * Corrupted version of @see signature_2 which has the last byte modified
         */
        let manipulatedSignature: [UInt8] = [
            0x5C, 0xDC, 0x7C, 0x59, 0xE0, 0x9C, 0xDD, 0x1A, 0xE1, 0xE5,
            0xC8, 0xD5, 0x21, 0x1E, 0xFA, 0x09, 0x25, 0x31, 0x92, 0x42,
            0x50, 0xE1, 0x56, 0x26, 0x66, 0x00, 0xCB, 0xDC, 0x69, 0xBF,
            0x9F, 0xED, 0x5C, 0x28, 0x5F, 0x33, 0x9E, 0x17, 0xDA, 0xA2,
            0xFC, 0xAC, 0xED, 0x7C, 0xD3, 0xAC, 0x40, 0x3C, 0x9E, 0xFE,
            0x98, 0x39, 0x24, 0x87, 0xF4, 0xEA, 0x15, 0x51, 0xEC, 0xCB,
            0x5D, 0xBC, 0x97, 0x50
        ]
        
        let notVerified = try account.verify(data: .init(data), signature: manipulatedSignature)
        XCTAssertFalse(notVerified)
    }
    
    func test_accountVerifyNodeSignature_ED25519() throws {
        let data = try XCTUnwrap("Some random test data".data(using: .utf8))
        
        let seed = "2401D206735C20485347B9A622D94DE9B21F2F1450A77C42102237FA4077567D"
        let account = try AccountBuilder.create(fromSeed: seed, index: 1, algorithm: .ED25519)
        
        let signature = try "B7AC4D279F1602A315B939B90587D18BA65817B6C241D2539245DB32C05BB7A6C20F9067189F04F9B59E6F153D2DECAA06DFCF1E11989CACE3368CD20A878B04".toBytes()
        
        let verified = try account.verify(data: data, signature: signature)
        XCTAssertTrue(verified)
    }
    
    func test_verifySignaturesFromOtherAccountTypes() throws {
        let privateKey = "50A44F48CF187E47483614BDA872E9405D36FE0DDF0ADA0FAE5982BDFBE9EF13"
        
        let account1 = try AccountBuilder.create(fromPrivateKey: privateKey, algorithm: .ECDSA_SECP256K1)
        let account2 = try AccountBuilder.create(fromPrivateKey: privateKey, algorithm: .ED25519)
        
        XCTAssertNotEqual(account1.keyPair.publicKey, account2.keyPair.publicKey)
        
        let data = try XCTUnwrap("Some random test data".data(using: .utf8))
        
        let signature1 = try account1.sign(data: data)
        let signature2 = try account2.sign(data: data)
        
        let verified1_1 = try account1.verify(data: data, signature: signature1)
        let verified1_2 = try account1.verify(data: data, signature: signature2)
        let verified2_1 = try account2.verify(data: data, signature: signature1)
        let verified2_2 = try account2.verify(data: data, signature: signature2)
        
        XCTAssertTrue(verified1_1)
        XCTAssertFalse(verified1_2)
        XCTAssertFalse(verified2_1)
        XCTAssertTrue(verified2_2)
    }
    
    func test_tryAccountSignWithoutPrivateKey() throws {
        let encodedPublicKey = "keeta_aabm7moneqqjpaaee5vxjqoe5f2ay3dchgr2hysdfh4wg3ycylohabivswjyfci"
        let account = try AccountBuilder.create(fromPublicKey: encodedPublicKey)
        let data = try XCTUnwrap("Input to sign".data(using: .utf8))
        
        captureError(KeyPairError.noPrivateKeyToSign, failure: "Should not be possible to sign data without private key.") {
            _ = try account.sign(data: data)
        }
    }
    
    func test_tokenIdentifier() throws {
        let seed = "2401D206735C20485347B9A622D94DE9B21F2F1450A77C42102237FA4077567D"
        let token = try AccountBuilder.create(fromSeed: seed, index: 0).generateIdentifier()
        XCTAssertEqual(token.publicKeyString, "keeta_apawchjv3mp6odgesjluzgolzk6opwq3yzygmor2ojkkacjb4ra6anxxzwsti")
    }
    
    func test_createFromPublicKeyAndType() throws {
        let encodedPublicKey = "keeta_aabm7moneqqjpaaee5vxjqoe5f2ay3dchgr2hysdfh4wg3ycylohabivswjyfci"
        let account = try AccountBuilder.create(fromPublicKey: encodedPublicKey)
        XCTAssertEqual(account, try Account(publicKeyAndType: account.publicKeyAndType))
    }
}
