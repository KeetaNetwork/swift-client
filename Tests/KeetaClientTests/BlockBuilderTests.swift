import XCTest
import KeetaClient

final class BlockBuilderTests: XCTestCase {
    
    let seed = "2401D206735C20485347B9A622D94DE9B21F2F1450A77C42102237FA4077567D"
    let baseToken = try! AccountBuilder.create(fromPublicKey: "keeta_apawchjv3mp6odgesjluzgolzk6opwq3yzygmor2ojkkacjb4ra6anxxzwsti")
    
    func test_createSealedBlocks() throws {
        let account1 = try AccountBuilder.create(fromSeed: seed, index: 0)
        let account2 = try AccountBuilder.create(fromSeed: seed, index: 1)
        let account3 = try AccountBuilder.create(fromSeed: seed, index: 2)
        
        let created1 = try XCTUnwrap(Block.dateFormatter.date(from: "2022-06-27T20:23:35.076Z"))
        
        let finalBlock = try BlockBuilder()
            .start(from: nil, network: 0)
            .add(signer: account1)
            .add(operation: SendOperation(amount: 10, to: account2, token: baseToken))
            .add(operation: SendOperation(amount: 20, to: account3, token: baseToken))
            .add(operation: SetRepOperation(to: account3))
            .seal(created: created1)
        
        // generated using TS node v0.10.6
        let expectedHash1 = "FA9AF443879D12518A2D5A43E018BA72CB1BB8AED51DCED964A3B69B140C9E57"
        XCTAssertEqual(finalBlock.hash, expectedHash1)
        XCTAssertTrue(finalBlock.opening)
        
        let publicAccount1 = try AccountBuilder.create(fromPublicKey: account1.publicKeyString)
        let hashBytes = try finalBlock.hash.toBytes()
        let verified = try publicAccount1.verify(data: Data(hashBytes), signature: finalBlock.signature)
        XCTAssertTrue(verified)
        
        let created2 = try XCTUnwrap(Block.dateFormatter.date(from: "2022-06-28T20:24:39.076Z"))
        
        let subsequentBlock = try BlockBuilder()
            .start(from: finalBlock.hash, network: 0)
            .add(signer: account1)
            .add(operation: SendOperation(amount: 10, to: account2, token: baseToken, external: "test"))
            .seal(created: created2)
        
        // generated using TS node v0.8.8
        let expectedHash2 = "D6FE2854DDB8645E2749949DD71FD73054C30FA2AC2D8917D21220F76F2C444C"
        XCTAssertEqual(subsequentBlock.hash, expectedHash2)
        XCTAssertFalse(subsequentBlock.opening)
    }
    
    func test_createBlockWithSigner() throws {
        let fullAccount = try AccountBuilder.create(fromSeed: seed, index: 0)
        let publicKey = "keeta_aabd26ccegg4jglymitdsy2cj537cgt5zrnhrjx3ekc5bojpomwzw6gpgj2zeja"
        let publicAccount = try AccountBuilder.create(fromPublicKey: publicKey)
        let created = try XCTUnwrap(Block.dateFormatter.date(from: "2025-01-01T16:23:35.076Z"))
        
        let block = try BlockBuilder()
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
        let verified = try fullAccount.verify(data: Data(hashBytes), signature: block.signature)
        XCTAssertTrue(verified)
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
        
        let finalBlock = try BlockBuilder()
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
        
        captureError(BlockBuilderError.unsupportedBlockVersion, failure: "Should not be possible to create blocks with unsupported version") {
            _ = try BlockBuilder(version: 2)
        }
        
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
}
