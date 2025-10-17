import XCTest
import KeetaClient

final class SeedGeneratorTests: XCTestCase {
    
    func test_bip39() throws {
        let seed = try SeedGenerator.generate()
        XCTAssertEqual(seed.count, 64)
        
        let phrase = try SeedGenerator.bip39Passphrase(using: seed)
        XCTAssertFalse(phrase.isEmpty)
        
        let recoveredSeed = try SeedGenerator.from(bip39Phrase: phrase)
        XCTAssertEqual(seed, recoveredSeed)
    }
    
    func test_seedFromPhrase() throws {
        // generated using node v0.10.6
        let validInput = [
            (
                "this is the example length for a sufficient passphrase to be set secured",
                "f4844098340a279dc09f7f6286081a9c92a518797634905e0e146bbaf708f9f3"
            ),
            (
                "one one one one one one one one one one one one one one one one one one one one",
                "281918a051553c41c79e2aab60a4566c0abeb5ade5a62a0ee08d0253e9171349"
            )
        ]
        
        for (phrase, expectedSeed) in validInput {
            let seed = try SeedGenerator.from(phrase: phrase)
            XCTAssertEqual(seed, expectedSeed, "Seed mismatch for phrase: \(phrase)")
        }
        
        captureError(
            SeedGeneratorError.weakPassphrase(count: 44, required: 60),
            failure: "Expected phrase to be invalid"
        ) {
            let invalidPhrase = "this is the example length for a too short passphrase"
            _ = try SeedGenerator.from(phrase: invalidPhrase)
        }
    }
    
    func test_randomWordGeneration() throws {
        try (0...100).forEach { _ in
            XCTAssertFalse(try SeedGenerator.randomWord().isEmpty)
        }
    }
    
    func test_randomWordsGeneration() throws {
        try [1, 5, 7, 19].forEach {
            let result = try SeedGenerator.randomWords(count: $0)
            XCTAssertEqual(result.count, $0)
        }
    }
    
    func test_randomWordsMaxIndex() {
        captureError(SeedGeneratorError.mnemonicWordIndexToLarge, failure: "Index should be too large.") {
            _ = try SeedGenerator.randomWords(count: 1_000_000)
        }
    }
    
    func test_tryToRecoverInvalidSeedPhrase() {
        let invalidPhrase = ["invalid phrase"]
        
        captureError(SeedGeneratorError.invalidSeedPhrase, failure: "Phrase should be invalid.") {
            _ = try SeedGenerator.from(bip39Phrase: invalidPhrase)
        }
    }
}
