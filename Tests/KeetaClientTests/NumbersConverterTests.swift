import XCTest
import BigInt
import KeetaClient

final class NumbersConverterTests: XCTestCase {
    
    enum RawNumber {
        case bigInt(BigInt)
        case string(String)
    }
    
    func test_basicExamples() {
        let examples: [(RawNumber, Double, Int)] = [
            // 1 token with 0 decimals
            (.bigInt(BigInt(1)), 1.0, 0),

            // 1 token with 6 decimals (e.g., USDC)
            (.bigInt(BigInt(1_000_000)), 1.0, 6),

            // 1.5 tokens with 6 decimals
            (.bigInt(BigInt(1_500_000)), 1.5, 6),

            // 0.000001 tokens with 6 decimals
            (.bigInt(BigInt(1)), 0.000001, 6),

            // 1 token with 18 decimals (e.g., ETH)
            (.bigInt(BigInt("1000000000000000000")), 1.0, 18),

            // 0.5 token with 18 decimals
            (.bigInt(BigInt("500000000000000000")), 0.5, 18),

            // Large number with 18 decimals (1,234.56789)
            (.bigInt(BigInt("1234567890000000000000")), 1234.56789, 18),

            // Many decimals
            (.bigInt(BigInt("339557583")), 0.339557583, 9),
            
            // Too many decimals, will be cut off
            (.bigInt(BigInt("506463862")), 0.50646386241, 9),
            
            // Small fractional case
            (.bigInt(BigInt("1234")), 0.000000001234, 12),

            // String input variant
            (.string("100000000"), 1.0, 8)
        ]

        for (rawNumber, human, decimals) in examples {
            let converted: Double?
            let raw: BigInt?
            
            switch rawNumber {
            case .bigInt(let bigInt):
                raw = bigInt
                converted = NumbersConverter.fromBigIntToDouble(bigInt, decimals: decimals)
            case .string(let string):
                raw = BigInt(string)
                converted = NumbersConverter.fromBigIntToDouble(string, decimals: decimals)
            }
            
            if human.fractionalCount <= decimals { XCTAssertEqual(converted, human, "Decimals: \(decimals)") }
            XCTAssertEqual(NumbersConverter.toBigInt(human, decimals: decimals), raw, "Decimals: \(decimals)")
        }
    }
}

extension Double {
    var fractionalCount: Int {
        let string = String(self)
        guard let dotIndex = string.firstIndex(of: ".") else { return 0 }
        let fraction = string[string.index(after: dotIndex)...]
        return fraction.count
    }
}
