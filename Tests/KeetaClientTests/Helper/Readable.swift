import Foundation
import BigInt

extension Date {
    func readable() -> String {
        if #available(iOS 15.0, *) {
            return formatted(date: .numeric, time: .omitted)
        } else {
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            formatter.timeStyle = .none
            formatter.locale = Locale.current
            return formatter.string(from: self)
        }
    }
}

extension Double {
    func readable() -> String {
        if #available(iOS 15.0, *) {
            return formatted()
        } else {
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.maximumFractionDigits = 2
            formatter.minimumFractionDigits = 0
            return formatter.string(from: NSNumber(value: self)) ?? "\(self)"
        }
    }
}

extension BigInt {
    func readable() -> String {
        if #available(iOS 15.0, *) {
            return formatted()
        } else {
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.maximumFractionDigits = 0
            formatter.locale = Locale.current
            return formatter.string(from: NSDecimalNumber(string: self.description)) ?? self.description
        }
    }
}
