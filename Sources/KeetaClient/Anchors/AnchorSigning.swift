import Foundation
import PotentASN1
import BigInt

/// Replicates the server's `FormatData` + `SignData` from `@keetanetwork/anchor`.
/// Signs data using ASN.1 DER encoding, matching the exact structure the server verifies against.
public enum AnchorSigning {

    public enum SignableItem {
        case string(String)
        case integer(Int)
        case account(Account)
    }

    public struct SignedResult {
        public let nonce: String
        public let timestamp: String
        public let signature: String
    }
    
    public static func sign(
        account: Account,
        data: [SignableItem]
    ) throws -> SignedResult {
        let nonce = UUID().uuidString
        let timestamp = millisecondISO8601(from: Date())

        // Build ASN.1 sequence: [nonce, timestamp, publicKeyAndType, ...data]
        var elements: [ASN1] = [
            .utf8String(nonce),
            .utf8String(timestamp),
            .octetString(Data(account.publicKeyAndType))
        ]

        for item in data {
            switch item {
            case .string(let value):
                elements.append(.utf8String(value))
            case .integer(let value):
                elements.append(.integer(BigInt(value)))
            case .account(let value):
                elements.append(.octetString(Data(value.publicKeyAndType)))
            }
        }

        let derData = try elements.toData()
        let signature = try account.sign(data: derData)

        return SignedResult(
            nonce: nonce,
            timestamp: timestamp,
            signature: Data(signature).base64EncodedString()
        )
    }

    public static func signedField(_ result: SignedResult) -> JSON {
        [
            "nonce": result.nonce,
            "timestamp": result.timestamp,
            "signature": result.signature
        ]
    }

    /// Flattens a nested `SignableObject` into a sorted list of `SignableItem`s,
    /// replicating the server's `commonToSignable` function.
    public static func commonToSignable(_ item: SignableObject) -> [SignableItem] {
        var queue: [(String, SignableObject)] = [("", item)]
        var result: [(String, SignableItem)] = []

        while !queue.isEmpty {
            let (prefix, current) = queue.removeFirst()

            switch current {
            case .string(let value):
                result.append((prefix, .string(value)))
            case .integer(let value):
                result.append((prefix, .integer(value)))
            case .account(let value):
                result.append((prefix, .account(value)))
            case .bool(let value):
                result.append((prefix, .integer(value ? 1 : 0)))
            case .array(let items):
                for (i, item) in items.enumerated() {
                    queue.append(("\(prefix)[\(i)]", item))
                }
            case .object(let fields):
                for (key, value) in fields {
                    let newPrefix = prefix.isEmpty ? key : "\(prefix).\(key)"
                    queue.append((newPrefix, value))
                }
            case .none:
                break
            }
        }

        result.sort { $0.0.compare($1.0, locale: Locale(identifier: "en_US")) == .orderedAscending }

        return result.map { $0.1 }
    }

    public static func signObject(
        account: Account,
        object: SignableObject
    ) throws -> SignedResult {
        try sign(account: account, data: commonToSignable(object))
    }

    static func millisecondISO8601(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"
        return formatter.string(from: date)
    }
}

public indirect enum SignableObject {
    case string(String)
    case integer(Int)
    case account(Account)
    case bool(Bool)
    case array([SignableObject])
    case object([(String, SignableObject)])
    case none
}
