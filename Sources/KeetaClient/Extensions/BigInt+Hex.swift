import Foundation
import BigInt

extension BigInt {
    public init?(hex value: String) {
        let value = value.prefix(2) == "0x" ? String(value.dropFirst(2)) : value
        
        guard let bigInt = BigInt(value, radix: 16) else { return nil }
        self = bigInt
    }
    
    public func toHex() -> String {
        String(self, radix: 16)
    }
    
    public func toData() -> Data {
        var valueStr = toHex()
        
        // Determine if the value is negative
        var isNegative = false
        if valueStr.hasPrefix("-") {
            isNegative = true
            valueStr.removeFirst()
        }
        
        // Ensure there are an even number of hex digits
        if valueStr.count % 2 != 0 {
            valueStr = "0" + valueStr
        }
        
        // Pad with a leading 0 byte if the MSB is 1 to avoid writing a negative number
        if let leaderValue = Int(valueStr.prefix(2), radix: 16) {
            if !isNegative {
                if leaderValue > 127 {
                    valueStr = "00" + valueStr
                }
            } else {
                if leaderValue <= 127 {
                    valueStr = "FF" + valueStr
                }
            }
        }
        
        return Data(hex: valueStr)
    }
}
