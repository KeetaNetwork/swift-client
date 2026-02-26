import Foundation
import BigInt

/// Each token on the Keeta network has their own decimal
public struct NumbersConverter {
    
    /// Convert an integer value into a BigInt scaled by decimals
    public static func toBigInt(_ value: Int, decimals: Int) -> BigInt {
        let multiplier = BigInt(10).power(decimals)
        return BigInt(value) * multiplier
    }
    
    /// Convert a decimal (Double) into a BigInt scaled by decimals
    public static func toBigInt(_ value: Double, decimals: Int) -> BigInt {
        if decimals == 0 { return BigInt(value) }
        
        if value.truncatingRemainder(dividingBy: 1) == 0 {
            let multiplier = BigInt(10).power(decimals)
            return BigInt(value) * multiplier
        } else {
            let stringValue = NSDecimalNumber(decimal: Decimal(string: "\(value)")!).stringValue
            let parts = stringValue.split(separator: ".")
            let fractions = parts[1].prefix(decimals).count
            let remainingFractions = decimals - fractions
            let multiplier = remainingFractions > 0 ? BigInt(10).power(remainingFractions) : 1
            return BigInt(value * pow(10, Double(fractions))) * multiplier
        }
    }
    
    /// Try to convert a String into a Double with given decimals
    public static func fromBigIntToDouble(_ bigIntRaw: String, decimals: Int) -> Double? {
        guard let bigInt = BigInt(bigIntRaw) else { return nil }
        return fromBigIntToDouble(bigInt, decimals: decimals)
    }
    
    /// Convert a BigInt into a Double with given decimals
    public static func fromBigIntToDouble(_ bigInt: BigInt, decimals: Int) -> Double? {
        guard let double = Double(bigInt.description) else { return nil }
        let divisor = pow(10.0, Double(decimals))
        return double / divisor
    }
}

public extension BigInt {
    func fromRaw(decimals: Int) -> Double? {
        NumbersConverter.fromBigIntToDouble(self, decimals: decimals)
    }
}

public extension String {
    func fromRaw(decimals: Int) -> Double? {
        NumbersConverter.fromBigIntToDouble(self, decimals: decimals)
    }
}

public extension Int {
    func toRaw(decimals: Int) -> BigInt {
        NumbersConverter.toBigInt(self, decimals: decimals)
    }
}

public extension Double {
    func toRaw(decimals: Int) -> BigInt {
        NumbersConverter.toBigInt(self, decimals: decimals)
    }
}
