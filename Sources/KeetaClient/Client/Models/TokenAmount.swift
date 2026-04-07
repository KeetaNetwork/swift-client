import BigInt

public struct TokenAmount: Equatable, Sendable {
    /// The raw blockchain value (scaled by 10^decimals).
    public let raw: BigInt

    /// Create from a human-readable Double with the given decimal places.
    /// Example: `TokenAmount(1.5, decimals: 9)` produces raw = 1_500_000_000
    public init(_ value: Double, decimals: Int) {
        self.raw = NumbersConverter.toBigInt(value, decimals: decimals)
    }

    public init(raw: BigInt) {
        self.raw = raw
    }
}

public extension TokenInfo {
    func amount(_ value: Double) -> TokenAmount {
        TokenAmount(value, decimals: decimalPlaces)
    }
}

public extension KeetaClient {
    func baseTokenAmount(_ value: Double) -> TokenAmount {
        TokenAmount(value, decimals: config.baseTokenDecimals)
    }
}
