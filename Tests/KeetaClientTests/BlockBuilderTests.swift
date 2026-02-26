import XCTest
import KeetaClient

final class BlockBuilderTests: XCTestCase {
    
    let seed = "2401D206735C20485347B9A622D94DE9B21F2F1450A77C42102237FA4077567D"
    let baseToken = try! AccountBuilder.create(fromPublicKey: "keeta_apawchjv3mp6odgesjluzgolzk6opwq3yzygmor2ojkkacjb4ra6anxxzwsti")
    
    func test_networkAccounts() throws {
        let expectedAccounts: [NetworkAlias: String] = [
            .main: "keeta_alwerxoezkupzhifvpo5yvoazlsdqaweov66mokhq7xl4h5ow36v5xu6ek3js",
            .test: "keeta_aj5pgcaced3jjixdn7unsybr4bx2v2p22zyhwubggp3i7474dze3ehhc5b4u4"
        ]
        
        for alias in expectedAccounts.keys {
            let config = try NetworkConfig.create(for: alias)
            let account = try AccountBuilder.create(for: config)
            XCTAssertEqual(account.publicKeyString, expectedAccounts[alias], "Mismatch for network '\(alias.rawValue)'")
        }
    }
    
    func test_constructBlockFromData() throws {
        // generated using TS node v0.14.3
        let encodedBlocks: [Block.Version: [String]] = [
            .v1: ["MIIBbgIBAAIBAAUAGBMyMDIyMDYyNzIwMjMzNS4wNzZaBCIAAhV6sOsTVE8Vg2Nc+Nsu0x/p0CkgbhYBADkuyRKI1lOoBQAEIEOjdPNp96THWK9A4izhlm++gsE903bTNqU+PJGjvgoFMIHEoEwwSgQiAAJGuYUd+QGaTysWsDZ62+HQwJ43+EFjphc0eeRL6U3cjgIBCgQhA8FhHTXbH+cMxJJXTJnLyrzn2hvGcGY6OnJUoAkh5EHgoEwwSgQiAAJtFlRCN/EpEy0WshtvOHIBCeHsQ2PHy8arBrUPkxwtnAIBFAQhA8FhHTXbH+cMxJJXTJnLyrzn2hvGcGY6OnJUoAkh5EHgoSYwJAQiAAJtFlRCN/EpEy0WshtvOHIBCeHsQ2PHy8arBrUPkxwtnARAY9i6etYirZJwa9g+I2csRK84FbjL5aYvX1MiLp9Orj0IMyK+OMyCgJ8++ejjc6mBDVdwL8y+ZB9IqItnW0dLGg=="],
            .v2: ["oYIBcDCCAWwCAQAYEzIwMjIwNjI3MjAyMzM1LjA3NloCAQAEIgACFXqw6xNUTxWDY1z42y7TH+nQKSBuFgEAOS7JEojWU6gFAAQgQ6N082n3pMdYr0DiLOGWb76CwT3TdtM2pT48kaO+CgUwgcSgTDBKBCIAAka5hR35AZpPKxawNnrb4dDAnjf4QWOmFzR55EvpTdyOAgEKBCEDwWEdNdsf5wzEkldMmcvKvOfaG8ZwZjo6clSgCSHkQeCgTDBKBCIAAm0WVEI38SkTLRayG284cgEJ4exDY8fLxqsGtQ+THC2cAgEUBCEDwWEdNdsf5wzEkldMmcvKvOfaG8ZwZjo6clSgCSHkQeChJjAkBCIAAm0WVEI38SkTLRayG284cgEJ4exDY8fLxqsGtQ+THC2cBEDYS5K7t/irrbOfhijdm58ZREBGCspYMx+9lhoqsornGSnoO9jzsivAjl4AUKrqwP61AqySBtNbhU9NZza+ioW6"]
        ]
        
        let expectedHashes: [Block.Version: [String]] = [
            .v1: ["FA9AF443879D12518A2D5A43E018BA72CB1BB8AED51DCED964A3B69B140C9E57"],
            .v2: ["A8D628AB191BB9CB156E7B2EB34251060045B207D517E58E8CCD924A96123977"]
        ]
        
        for version in Block.Version.all {
            let blocks = try XCTUnwrap(encodedBlocks[version])
            let expectedHashes = try XCTUnwrap(expectedHashes[version])
            guard blocks.count == expectedHashes.count else {
                XCTFail("Misconfiguration")
                return
            }
            
            for (index, base64) in blocks.enumerated() {
                let data = try XCTUnwrap(Data(base64Encoded: base64))
                let block = try Block(from: data)
                XCTAssertEqual(block.hash, expectedHashes[index], "\(version)")
            }
        }
    }
    
    func test_createSealedBlocks() throws {
        for algorithm in [Account.KeyAlgorithm.ED25519, .ECDSA_SECP256K1, .ECDSA_SECP256R1] {
            let account1 = try AccountBuilder.create(fromSeed: seed, index: 0, algorithm: algorithm)
            let account2 = try AccountBuilder.create(fromSeed: seed, index: 1, algorithm: algorithm)
            let account3 = try AccountBuilder.create(fromSeed: seed, index: 2, algorithm: algorithm)
            
            let expectedHashes: [Block.Version: [Account.KeyAlgorithm: [String]]] = [
                .v1: [
                    .ED25519: [
                        // generated using TS node v0.14.12
                        "8ED08D4D17193B467FDDC96B19CBB6039B23E5693667E4C9C5DBA5F9A51B1EC7"
                    ],
                    .ECDSA_SECP256K1: [
                        // generated using TS node v0.10.6
                        "FA9AF443879D12518A2D5A43E018BA72CB1BB8AED51DCED964A3B69B140C9E57",
                        // generated using TS node v0.8.8
                        "D6FE2854DDB8645E2749949DD71FD73054C30FA2AC2D8917D21220F76F2C444C"
                    ],
                    .ECDSA_SECP256R1: [
                        // generated using TS node v0.14.12
                        "8527EBDB8D57E826BF7BC6DE24B2AB15912A75ACF01DD4DE8CB5758AE4460587"
                    ]
                ],
                .v2: [
                    .ED25519: [
                        // generated using TS node v0.14.12
                        "984DF649733A2C9A7528C5D4862497C90D1E7E9D2FEF5F1E5633E5E1A9B76771"
                    ],
                    .ECDSA_SECP256K1: [
                        // generated using TS node v0.14.3
                        "A8D628AB191BB9CB156E7B2EB34251060045B207D517E58E8CCD924A96123977",
                        "9B2268604FF9B040BEB9C7AC6AFA414CB8BD23ED57B077CAF42DE46659041D3D"
                    ],
                    .ECDSA_SECP256R1: [
                        // generated using TS node v0.14.12
                        "E4B1E16D5522C0B3C083F4CA08770620DCE57B5B37AB1F49988EBF913EEF68AB"
                    ]
                ]
            ]
            
            for version in Block.Version.all {
                let created1 = try XCTUnwrap(Block.dateFormatter.date(from: "2022-06-27T20:23:35.076Z"))
                let finalBlock = try BlockBuilder(version: version)
                    .start(from: nil, network: 0)
                    .add(signer: account1)
                    .add(operation: SendOperation(amount: 10, to: account2, token: baseToken))
                    .add(operation: SendOperation(amount: 20, to: account3, token: baseToken))
                    .add(operation: SetRepOperation(to: account3))
                    .seal(created: created1)
                
                let expectedHashes = try XCTUnwrap(
                    expectedHashes[version]?[algorithm],
                    "Missing block hashes for version: \(version) & algorithm: \(algorithm)"
                )
                XCTAssertEqual(finalBlock.hash, expectedHashes[0])
                XCTAssertTrue(finalBlock.opening)
                
                let publicAccount1 = try AccountBuilder.create(fromPublicKey: account1.publicKeyString)
                let hashBytes = try finalBlock.hash.toBytes()
                switch finalBlock.signature {
                case .single(let signature):
                    let verified = try publicAccount1.verify(data: Data(hashBytes), signature: signature)
                    XCTAssertTrue(verified)
                case .multi:
                    XCTFail("Multi-signatures not implemented")
                }
                
                let created2 = try XCTUnwrap(Block.dateFormatter.date(from: "2022-06-28T20:24:39.076Z"))
                let subsequentBlock = try BlockBuilder(version: version)
                    .start(from: finalBlock.hash, network: 0)
                    .add(signer: account1)
                    .add(operation: SendOperation(amount: 10, to: account2, token: baseToken, external: "test"))
                    .seal(created: created2)
                if expectedHashes.count == 2 {
                    XCTAssertEqual(subsequentBlock.hash, expectedHashes[1])
                }
                XCTAssertFalse(subsequentBlock.opening)
            }
        }
    }
    
    func test_createBlockWithSigner() throws {
        let fullAccount = try AccountBuilder.create(fromSeed: seed, index: 0)
        let publicKey = "keeta_aabd26ccegg4jglymitdsy2cj537cgt5zrnhrjx3ekc5bojpomwzw6gpgj2zeja"
        let publicAccount = try AccountBuilder.create(fromPublicKey: publicKey)
        let created = try XCTUnwrap(Block.dateFormatter.date(from: "2025-01-01T16:23:35.076Z"))
        
        let block = try BlockBuilder(version: .v1)
            .start(from: nil, network: 31)
            .add(signer: fullAccount)
            .add(account: publicAccount)
            .add(operation: TokenAdminModifyBalanceOperation(token: baseToken, amount: .init(10), method: .add))
            .seal(created: created)
        
        // generated using TS node v0.10.6
        let expectedHash1 = "BEB8D563362B0EE7C04865F37F000D4C365623A3849695656116093ACFB7F7AD"
        XCTAssertEqual(block.hash, expectedHash1)
        XCTAssertTrue(block.opening)
        
        let hashBytes = try block.hash.toBytes()
        switch block.signature {
        case .single(let signature):
            let verified = try fullAccount.verify(data: Data(hashBytes), signature: signature)
            XCTAssertTrue(verified)
        case .multi:
            XCTFail("Multi-signatures not implemented")
        }
    }
    
    func test_createBlockWithSignature() throws {
        // generate using the TS node v0.10.6
        // Hex: 63D8BA7AD622AD92706BD83E23672C44AF3815B8CBE5A62F5F53222E9F4EAE3D083322BE38CC82809F3EF9E8E373A9810D57702FCCBE641F48A88B675B474B1A
        let signature: Signature = [
            0x63, 0xD8, 0xBA, 0x7A, 0xD6, 0x22, 0xAD, 0x92, 0x70, 0x6B,
            0xD8, 0x3E, 0x23, 0x67, 0x2C, 0x44, 0xAF, 0x38, 0x15, 0xB8,
            0xCB, 0xE5, 0xA6, 0x2F, 0x5F, 0x53, 0x22, 0x2E, 0x9F, 0x4E,
            0xAE, 0x3D, 0x08, 0x33, 0x22, 0xBE, 0x38, 0xCC, 0x82, 0x80,
            0x9F, 0x3E, 0xF9, 0xE8, 0xE3, 0x73, 0xA9, 0x81, 0x0D, 0x57,
            0x70, 0x2F, 0xCC, 0xBE, 0x64, 0x1F, 0x48, 0xA8, 0x8B, 0x67,
            0x5B, 0x47, 0x4B, 0x1A
        ]
        
        let account1 = try AccountBuilder.create(fromSeed: seed, index: 0)
        let account2 = try AccountBuilder.create(fromSeed: seed, index: 1)
        let account3 = try AccountBuilder.create(fromSeed: seed, index: 2)
        
        let created = try XCTUnwrap(Block.dateFormatter.date(from: "2022-06-27T20:23:35.076Z"))
        
        let finalBlock = try BlockBuilder(version: .v1)
            .start(from: nil, network: 0)
            .add(signer: account1)
            .add(operation: SendOperation(amount: 10, to: account2, token: baseToken))
            .add(operation: SendOperation(amount: 20, to: account3, token: baseToken))
            .add(operation: SetRepOperation(to: account3))
            .seal(with: signature, created: created)
        
        let expectedHash = "FA9AF443879D12518A2D5A43E018BA72CB1BB8AED51DCED964A3B69B140C9E57"
        XCTAssertEqual(finalBlock.hash, expectedHash)
    }
    
    func test_tryToCreateBlockWithInvalidSignature() throws {
        // last byte modified
        let invalidSignature: Signature = [
            0x63, 0xD8, 0xBA, 0x7A, 0xD6, 0x22, 0xAD, 0x92, 0x70, 0x6B,
            0xD8, 0x3E, 0x23, 0x67, 0x2C, 0x44, 0xAF, 0x38, 0x15, 0xB8,
            0xCB, 0xE5, 0xA6, 0x2F, 0x5F, 0x53, 0x22, 0x2E, 0x9F, 0x4E,
            0xAE, 0x3D, 0x08, 0x33, 0x22, 0xBE, 0x38, 0xCC, 0x82, 0x80,
            0x9F, 0x3E, 0xF9, 0xE8, 0xE3, 0x73, 0xA9, 0x81, 0x0D, 0x57,
            0x70, 0x2F, 0xCC, 0xBE, 0x64, 0x1F, 0x48, 0xA8, 0x8B, 0x67,
            0x5B, 0x47, 0x4B, 0xFF
        ]
        
        let account1 = try AccountBuilder.create(fromSeed: seed, index: 0)
        let account2 = try AccountBuilder.create(fromSeed: seed, index: 1)
        let account3 = try AccountBuilder.create(fromSeed: seed, index: 2)
        
        captureError(BlockError.invalidSignature, failure: "Block signature should be invalid.") {
            _ = try BlockBuilder()
                .start(from: nil, network: 0)
                .add(signer: account1)
                .add(operation: SendOperation(amount: 10, to: account2, token: self.baseToken))
                .add(operation: SendOperation(amount: 20, to: account3, token: self.baseToken))
                .add(operation: SetRepOperation(to: account3))
                .seal(with: invalidSignature)
        }
    }
    
    func test_sealingBlockErrors() throws {
        let account = try AccountBuilder.create(fromSeed: seed, index: 0)
        let sendOperation = try SendOperation(amount: 10, to: account, token: baseToken)
        
        captureError(BlockBuilderError.insufficentDataToSignBlock, failure: "Should not be possible to sign empty block data.") {
            _ = try BlockBuilder().seal()
        }
        
        let publicKey = "keeta_aabd26ccegg4jglymitdsy2cj537cgt5zrnhrjx3ekc5bojpomwzw6gpgj2zeja"
        let publicAccount = try AccountBuilder.create(fromPublicKey: publicKey)
        
        captureError(BlockBuilderError.noPrivateKeyOrSignatureToSignBlock, failure: "") {
            _ = try BlockBuilder()
                .start(from: nil, network: 1)
                .add(signer: publicAccount)
                .add(operation: sendOperation)
                .seal()
        }
        
        captureError(BlockBuilderError.negativeNetworkId, failure: "Should not be possible to create a block with negative network ID.") {
            _ = try BlockBuilder()
                .start(from: nil, network: -1)
                .add(signer: account)
                .add(operation: sendOperation)
                .seal()
        }
        
        captureError(BlockBuilderError.negativeSubnetId, failure: "Should not be possible to create a block with negative subnet ID.") {
            _ = try BlockBuilder()
                .start(from: nil, network: 1, subnet: -1)
                .add(signer: account)
                .add(operation: sendOperation)
                .seal()
        }
        
        // No accounts can call SET_REP more than once per block
        let setRepOperation = SetRepOperation(to: account)
        
        captureError(BlockBuilderError.multipleSetRepOperations, failure: "Should not be possible to create a block with") {
            _ = try BlockBuilder()
                .start(from: nil, network: 1)
                .add(signer: publicAccount)
                .add(operation: setRepOperation)
                .add(operation: setRepOperation)
                .seal()
        }
    }
    
    func test_parseBlockV2() throws {
        let block = try Block.create(from: "oYIBcDCCAWwCAQAYEzIwMjUxMDExMDQ1MTMxLjM0NFoCAQAEIgACFXqw6xNUTxWDY1z42y7TH+nQKSBuFgEAOS7JEojWU6gFAAQgQ6N082n3pMdYr0DiLOGWb76CwT3TdtM2pT48kaO+CgUwgcSgTDBKBCIAAka5hR35AZpPKxawNnrb4dDAnjf4QWOmFzR55EvpTdyOAgEKBCEDwWEdNdsf5wzEkldMmcvKvOfaG8ZwZjo6clSgCSHkQeCgTDBKBCIAAm0WVEI38SkTLRayG284cgEJ4exDY8fLxqsGtQ+THC2cAgEUBCEDwWEdNdsf5wzEkldMmcvKvOfaG8ZwZjo6clSgCSHkQeChJjAkBCIAAm0WVEI38SkTLRayG284cgEJ4exDY8fLxqsGtQ+THC2cBEC1EJDEYIV69cn7ynaCouj7F7YifWSwjQlBYVrbIS47uCG9LBfc/wZsM+0qc0aSb2ttubiBExRz34ZkRNcyVGAu")
        
        let expectedHash = "BAD0320878F55686382CD5DFA3933C4E85100A8A0B376E7F5DD119A3E1CF2FAE"
        XCTAssertEqual(block.hash, expectedHash)
    }
    
    func test_multisigIdentifierCreationBlockV1() throws {
        let block = try Block.create(from: "MIIBIQIBAAIBAAUAGBMyMDI1MTEwNzEzNTg1My43MjhaBCIAAhV6sOsTVE8Vg2Nc+Nsu0x/p0CkgbhYBADkuyRKI1lOoBQAEIEOjdPNp96THWK9A4izhlm++gsE903bTNqU+PJGjvgoFMHikdjB0BCEHwWEdNdsf5wzEkldMmcvKvOfaG8ZwZjo6clSgCSHkQeCnTzBNMEgEIgACFXqw6xNUTxWDY1z42y7TH+nQKSBuFgEAOS7JEojWU6gEIgACRrmFHfkBmk8rFrA2etvh0MCeN/hBY6YXNHnkS+lN3I4CAQIEQKAK0dOLr7IUDl3tkXX5V3dIxO6ePWa9/w2txN3TZpwXZHU7LUB/w7QsBl2RnMuc0giWQ1o4pIfPMEODTY/218o=")
        
        let expectedHash = "8697ECECD10E14EEC58783964E67962FE66C39649050DAFE585D82821F8A805B"
        XCTAssertEqual(block.hash, expectedHash)
        
        let expectedSignature = "A00AD1D38BAFB2140E5DED9175F9577748C4EE9E3D66BDFF0DADC4DDD3669C1764753B2D407FC3B42C065D919CCB9CD20896435A38A487CF3043834D8FF6D7CA"
        XCTAssertEqual(block.signature, .single(try expectedSignature.toBytes()))
    }
    
    func test_idempotentBlockV1() throws {
        let block = try Block.create(from: "MIIBhAIBAAIBAAUABBRpZGVtcG90ZW50X2tleV92YWxpZBgTMjAyNTEwMTEwNTQyNTcuNDg3WgQiAAIVerDrE1RPFYNjXPjbLtMf6dApIG4WAQA5LskSiNZTqAUABCBDo3Tzafekx1ivQOIs4ZZvvoLBPdN20zalPjyRo74KBTCBxKBMMEoEIgACRrmFHfkBmk8rFrA2etvh0MCeN/hBY6YXNHnkS+lN3I4CAQoEIQPBYR012x/nDMSSV0yZy8q859obxnBmOjpyVKAJIeRB4KBMMEoEIgACbRZUQjfxKRMtFrIbbzhyAQnh7ENjx8vGqwa1D5McLZwCARQEIQPBYR012x/nDMSSV0yZy8q859obxnBmOjpyVKAJIeRB4KEmMCQEIgACbRZUQjfxKRMtFrIbbzhyAQnh7ENjx8vGqwa1D5McLZwEQID+jcqn7rRy2RSQhA85+k5woB9HWDSmNPpdnrVrtmDTZYQNiDaiZYMC9yikJXzjntPePp0zzHMSTIrDyGyoh/Y=")
        
        let expectedHash = "3F2B932AC0830BCE3FFAA71796BA126FD9998767C65333A3DBF56C2D1335A514"
        XCTAssertEqual(block.hash, expectedHash)
        XCTAssertEqual(block.rawData.idempotent, "idempotent_key_valid")
    }
    
    func test_multiSigBlockV2() throws {
        let block = try Block.create(from: "oYICPTCCAjkCAlOCBCAk4moTFpRvyVL6PItZxkeAd3UNKdVNDy7qXNNANkQf1BgTMjAyNTExMDYxNTIxNDguNTM0WgIBAAQhBBcxgXyMjzVjqCHH/3cbYNKhMVTo+UW7pTObmEb0XYj2MIGRBCEH97LbhjVfk/ncXSfpSn50Yy7Zh4WBYDEDJTwAeIsHTSYwbAQiAAOfTPCJY0GnHAFqOYJqRffcEBbOoeGqHTQpW2ocP3tMsAQiAANdd5txw2+nEg9ztKP3C1q/A9snerbUieK2Y1fu47l+PQQiAAJb3V9P9RlfJLdnM7Db6UtxF2r/r4j0taw+xRvLJxbLoAQgWuspKYiuM6Qj/G1qh1kYGnDBZXrLU7tSi4Yk7XYvn8swV6BVMFMEIgACW4nSA+I2drrhuNUL9AG6rqiqUZSHR9aEg/Gg3Nz4ofYCCgQ2x/o1SAFwAAAEIQNgNC3gyMih04AVvdKn8mLmJ+vWDFCxqhOWYVqSK0vs8jCBxgRAhGqfeXEXRmsBGlhaDNHe7xR3fUbiHIfQmODy00tx5/YkPkTjL34H1dVlTYAVtMjlk//SSHXiyW5ZpVNEDoppPQRAGGAVQO1oZfZ4jMxhMZFILGAx7aXOBth2Js3TbCTHxN80euhe/DSPlC0jL0NdilPR2AsGC+KGdBzMCFzT9LCLTQRAK3i5x7D+5BqRuiqeKa9npKVKpwb5lgiH9lzuNZB/ZZEe0a/hDAkozpTmGEb0NHPwwIHaelm1/G1f7vdrs/XsCQ==")
        
        XCTAssertEqual(block.rawData.version, .v2)
        
        let expectedHash = "044E18C4E35143466BC68C2972810669E5ED7AB68E092CA561B7376CDF3E792F"
        XCTAssertEqual(block.hash, expectedHash)
        
        let expectedIdempotent = "JOJqExaUb8lS+jyLWcZHgHd1DSnVTQ8u6lzTQDZEH9Q="
        XCTAssertEqual(block.rawData.idempotent, expectedIdempotent)
        
        let expectedSignatures = [
            "846A9F797117466B011A585A0CD1DEEF14777D46E21C87D098E0F2D34B71E7F6243E44E32F7E07D5D5654D8015B4C8E593FFD24875E2C96E59A553440E8A693D",
            "18601540ED6865F6788CCC613191482C6031EDA5CE06D87626CDD36C24C7C4DF347AE85EFC348F942D232F435D8A53D1D80B060BE286741CCC085CD3F4B08B4D",
            "2B78B9C7B0FEE41A91BA2A9E29AF67A4A54AA706F9960887F65CEE35907F65911ED1AFE10C0928CE94E61846F43473F0C081DA7A59B5FC6D5FEEF76BB3F5EC09"
        ]
        
        if case .multi(let signatures) = block.signature {
            XCTAssertEqual(signatures, try expectedSignatures.map { try $0.toBytes() })
        } else {
            XCTFail("Expected multisignature signature")
        }
        
        if case .multi(let account, let signers) = block.rawData.signer {
            XCTAssertEqual(account.publicKeyString, "keeta_a733fw4ggvpzh6o4lut6sst6orrs5wmhqwawamideu6aa6ela5gsnztw4vvqm")
            XCTAssertTrue(signers.allSatisfy { if case .single = $0 { true } else { false } })
            XCTAssertEqual(signers.map(\.account.publicKeyString), [
                "keeta_aabz6thqrfrudjy4afvdtatkix35yeawz2q6dkq5gquvw2q4h55uzmhq6cdyaha",
                "keeta_aabv2543ohbw7jysb5z3ji7xbnnl6a63e55lnvej4k3ggv7o4o4x4po5mchj5uy",
                "keeta_aabfxxk7j72rsxzew5tthmg35ffxcf3k76xyr5fvvq7mkg6le4lmxibrdkvqn5y"
            ])
        } else {
            XCTFail("Expected multisignature signers")
        }
    }
    
    func test_feeBlockV2() throws {
        let block = try Block.create(from: "oYIB/jCCAfoCAlOCGBMyMDI1MTIwNDAyMTU0Mi43MzBaAgEBBCIAAl8YxHyTnsdLw2iqvPrijKJYHos5dRJaVNMEtXguUvQrBQAEIGaRwSbSVjgdoJCDeN0D8mtwEUOcMu4x4ZaK03233/zWMIIBUKBSMFAEIgACFbCnNSKvklQqa9LnfGrF8l2a9PoVJT3YVhZNAP8ll4gCBwrfDcUDQAAEIQNgNC3gyMih04AVvdKn8mLmJ+vWDFCxqhOWYVqSK0vs8qBSMFAEIgACWjKmwrySF8Wxs52p0FHW3N9T57SfeWRrcK0xJRdm3dECBwrfDcUDQAAEIQNgNC3gyMih04AVvdKn8mLmJ+vWDFCxqhOWYVqSK0vs8qBSMFAEIgAD3XAEyrsP9k7sy5sfbTsr9Tv8g3HFVCyDC2r3fFWBbpYCBwrfDcUDQAAEIQNgNC3gyMih04AVvdKn8mLmJ+vWDFCxqhOWYVqSK0vs8qBSMFAEIgACqBIgT1/pWhfTv9he6IgIBEufEfA/0zzqU5TGE5tirXkCBwrfDcUDQAAEIQNgNC3gyMih04AVvdKn8mLmJ+vWDFCxqhOWYVqSK0vs8gRABfq756MEqsoZQAq5PSZDb91IoXhpYiqIfNL00GVfEwwk21uWgwhBLWyzFWbSVN5cWsZDdLVi+W+5jghlhv8KLA==")
        
        let expectedHash = "2B660432362CEC6ED626840F73F98D81397C5395981D5D44C67B59ED44D00628"
        XCTAssertEqual(block.hash, expectedHash)
    }
    
    func test_troubleMaker() throws {
        let block = try Block.create(from: "oYIB+jCCAfYCAlOCGA8yMDI1MTExOTIxNDc1OVoCAQEEIgACXxjEfJOex0vDaKq8+uKMolgeizl1ElpU0wS1eC5S9CsFAAQgIbrNaJ2MJQPU+Aynlhcevmvf26HBt4Mdnp842H0VSWgwggFQoFIwUAQiAANcYYE1XWhn6RPZzsoJLGkaZ0M9Y9QztMO1RqBNnQezjgIHCt8NxQNAAAQhA2A0LeDIyKHTgBW90qfyYuYn69YMULGqE5ZhWpIrS+zyoFIwUAQiAAKuImOBuXLw89BPO45nMrr4idlPk71e5NCS1bCrXiNjfwIHCt8NxQNAAAQhA2A0LeDIyKHTgBW90qfyYuYn69YMULGqE5ZhWpIrS+zyoFIwUAQiAAL3Wlfc/GoNk2n88oPEDW6rnwCuHzCubofIbeDCBKNOSwIHCt8NxQNAAAQhA2A0LeDIyKHTgBW90qfyYuYn69YMULGqE5ZhWpIrS+zyoFIwUAQiAAMr9ggNx/UztTqAGOwVmsmBvCYo5QdlFkSV3Dl1QwTJ6wIHCt8NxQNAAAQhA2A0LeDIyKHTgBW90qfyYuYn69YMULGqE5ZhWpIrS+zyBEA0kDYbrzXJGNKSmR2wXsJ80hWKl0fQ2J8hlhBqHtsAuAdlkAOt7ieltFbVaf6vzV29cjOSXr4e83ofIoFsiBX2")
        
        let expectedHash = "CD0484ECA3E24ACC147584F9C9DA14124CF4FDAA0A8F78578DEB02B04B66988E"
        XCTAssertEqual(block.hash, expectedHash)
    }
    
    func test_idempotentBlockV2() throws {
        let block = try Block.create(from: "oYIBhjCCAYICAQAEFGlkZW1wb3RlbnRfa2V5X3ZhbGlkGBMyMDI1MTAxMTA1NDc0MC4zMjRaAgEABCIAAhV6sOsTVE8Vg2Nc+Nsu0x/p0CkgbhYBADkuyRKI1lOoBQAEIEOjdPNp96THWK9A4izhlm++gsE903bTNqU+PJGjvgoFMIHEoEwwSgQiAAJGuYUd+QGaTysWsDZ62+HQwJ43+EFjphc0eeRL6U3cjgIBCgQhA8FhHTXbH+cMxJJXTJnLyrzn2hvGcGY6OnJUoAkh5EHgoEwwSgQiAAJtFlRCN/EpEy0WshtvOHIBCeHsQ2PHy8arBrUPkxwtnAIBFAQhA8FhHTXbH+cMxJJXTJnLyrzn2hvGcGY6OnJUoAkh5EHgoSYwJAQiAAJtFlRCN/EpEy0WshtvOHIBCeHsQ2PHy8arBrUPkxwtnARAyGqNldS23Ry+VlVLKV+/aAgQn6QuWscl63RmhZ6id80LG/oJrO+TUZ2F1ffW4yaxyA3oKsV9YnQaA/sRkY1cpQ==")
        
        let expectedHash = "20630B5EED455279BBFFF90A5E7E6457C7EE5BEF128710C565F27B2B1AD6121C"
        XCTAssertEqual(block.hash, expectedHash)
        XCTAssertEqual(block.rawData.idempotent, "idempotent_key_valid")
    }
    
    func test_idempotent() throws {
        let idempotentKey = try "idempotent_key_valid".idempotent()
        XCTAssertEqual(idempotentKey, "aWRlbXBvdGVudF9rZXlfdmFsaWQ=")
    }
}
