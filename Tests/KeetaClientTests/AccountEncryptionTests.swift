import XCTest
@testable import KeetaClient

final class AccountEncryptionTests: XCTestCase {

    let seed = "2401D206735C20485347B9A622D94DE9B21F2F1450A77C42102237FA4077567D"

    /// Test vectors from the node project (account.test.ts encryptionTestCases).
    /// Each was encrypted with the test seed at index 0 for the given algorithm.
    struct NodeVector {
        let algorithm: Account.KeyAlgorithm
        let encrypted: String
        let value: String
    }

    let nodeVectors: [NodeVector] = [
        .init(
            algorithm: .ECDSA_SECP256K1,
            encrypted: "BI8ePLqAhgOQvUXsTqW8ifQ77eRhg7Z6FpxX5wd6xJfE+ErjHyuXFKNjSDMBgTAG6iKylZITJajh6Zdgcbpdvb3+pBN17zCaaOzAgpId4hcOG3P/ueHMRWolYQPJ5jGqM1xmBO64sa3nodxDwEtAI5dA3CG4mg==",
            value: "Hello"
        ),
        .init(
            algorithm: .ECDSA_SECP256R1,
            encrypted: "BBF2ML5v5BMyOu/BMChxa984vGgED2rjaM5I0QP01MmjdMWnHx/00AfpxSCaVkFx3qYbl4cpxBM3WcHo9PIZG5P1CMv36lv8wmMMus+xQ/KrUozna8hLRlJN9ez3i+vzOZeMKYm9EfkpMZ2eQv1y1clevkvKicA8V+Zt3CVog0MhT9HYuTwWWN9yoxfshAlqGpODSFiHabdLG3E4er2d9q8=",
            value: "Hello"
        ),
        .init(
            algorithm: .ED25519,
            encrypted: "fZazrME6jGTTj2Dp1o9imAuri5s3MxeE0ZnK8HP2dK4TgnAJ3825UWKFaQnW0E0tETD0iyo8B1Zex4JUB7Ab83RnJrWBxGfoho6YqaKdHTWYfAPPJ1G2EBkDo1qoiGpO8t1Tb3o9JiOQf6jAMp2VKg==",
            value: "Ed25519 Encryption"
        )
    ]

    // MARK: - Round-trip encrypt/decrypt (indexes 0-4, matching node test)

    let algorithms: [Account.KeyAlgorithm] = [.ECDSA_SECP256K1, .ECDSA_SECP256R1, .ED25519]

    func test_roundTripEncryptDecrypt() throws {
        for algorithm in algorithms {
            for seedIndex in 0..<5 {
                let account = try AccountBuilder.create(fromSeed: seed, index: seedIndex, algorithm: algorithm)
                let plaintext = randomBytes(64)

                let encrypted = try account.encrypt(data: plaintext)
                let decrypted = try account.decrypt(data: encrypted)

                XCTAssertEqual(decrypted, plaintext, "Round-trip failed for \(algorithm) index \(seedIndex)")
            }
        }
    }

    private func randomBytes(_ count: Int) -> [UInt8] {
        var bytes = [UInt8](repeating: 0, count: count)
        _ = SecRandomCopyBytes(kSecRandomDefault, count, &bytes)
        return bytes
    }

    // MARK: - Cross-compatibility: decrypt node-generated test vectors

    func test_decryptNodeVectors() throws {
        for vector in nodeVectors {
            let account = try AccountBuilder.create(fromSeed: seed, index: 0, algorithm: vector.algorithm)
            let encrypted = Array(Data(base64Encoded: vector.encrypted)!)

            let decrypted = try account.decrypt(data: encrypted)

            XCTAssertEqual(String(bytes: decrypted, encoding: .utf8), vector.value, "Decryption failed for \(vector.algorithm)")
        }
    }

    // MARK: - Wrong account can't decrypt (matching node: wrongAccount.decrypt(exampleEncrypted))

    func test_wrongAccountCannotDecrypt() throws {
        for vector in nodeVectors {
            let wrongAccount = try AccountBuilder.create(fromSeed: seed, index: 1, algorithm: vector.algorithm)
            let encrypted = Array(Data(base64Encoded: vector.encrypted)!)

            XCTAssertThrowsError(try wrongAccount.decrypt(data: encrypted), "Expected error for \(vector.algorithm)")
        }
    }

    // MARK: - Corrupted ciphertext fails (matching node: invalidateBuffer)

    func test_corruptedCiphertextFails() throws {
        for vector in nodeVectors {
            let account = try AccountBuilder.create(fromSeed: seed, index: 0, algorithm: vector.algorithm)
            var encrypted = Array(Data(base64Encoded: vector.encrypted)!)
            invalidateBuffer(&encrypted)

            XCTAssertThrowsError(try account.decrypt(data: encrypted), "Expected error for corrupted \(vector.algorithm)")
        }
    }

    /// Matches node's invalidateBuffer: increment 3 random bytes
    private func invalidateBuffer(_ buf: inout [UInt8], times: Int = 3) {
        for _ in 0..<times {
            let randomIndex = Int.random(in: 0..<buf.count)
            buf[randomIndex] &+= 1
        }
    }
}
