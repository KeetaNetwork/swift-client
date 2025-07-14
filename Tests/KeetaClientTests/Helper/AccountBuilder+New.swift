import KeetaClient

extension AccountBuilder {
    static func new(algorithm: Account.KeyAlgorithm = .ECDSA_SECP256K1) throws -> Account {
        try AccountBuilder.create(fromSeed: try SeedGenerator.generate(), index: .random(in: 0...1_000), algorithm: algorithm)
    }
}
