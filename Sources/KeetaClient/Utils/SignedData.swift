import Foundation

public enum SignedDataError: Error {
    case invalidDataToSign(Any)
}

public struct SignedData {
    public enum Keys: String {
        case account
        case nonce
        case timestamp
        case signature
        case signed
    }
    
    public let account: String
    public let nonce: String
    public let timeStamp: String
    public let signature: [UInt8]
    public let input: JSON
    public let signed: JSON
    
    static let timeStampFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFractionalSeconds, .withInternetDateTime]
        return formatter
    }()
    
    public static func create(with data: Data, account: Account) throws -> Self {
        let jsonObject = try JSONSerialization.jsonObject(with: data, options: [])
        
        guard let json = jsonObject as? JSON else {
            throw SignedDataError.invalidDataToSign(jsonObject)
        }
        
        var toSign = json
        let nonce = UUID().uuidString
        toSign[Keys.nonce.rawValue] = nonce
        
        let timeStamp = timeStampFormatter.string(from: .now)
        toSign[Keys.timestamp.rawValue] = timeStamp
        
        let accountPubKey = account.publicKeyString
        if !toSign.keys.contains(Keys.account.rawValue) {
            toSign[Keys.account.rawValue] = accountPubKey
        }
        
        let dataToSign = try JSONSerialization.data(withJSONObject: toSign)
        
        let signature = try account.sign(data: dataToSign)
        
        var result: JSON = json
        
        result[Keys.account.rawValue] = accountPubKey
        
        result[Keys.signed.rawValue] = [
            Keys.nonce.rawValue: nonce,
            Keys.timestamp.rawValue: timeStamp,
            Keys.signature.rawValue: signature.toBase64()
        ]
        
        return Self(account: accountPubKey, nonce: nonce, timeStamp: timeStamp, signature: signature, input: json, signed: result)
    }
}

extension JSON {
    public func sign(using account: Account) throws -> SignedData {
        let data = try JSONSerialization.data(withJSONObject: self, options: [])
        return try .create(with: data, account: account)
    }
}

extension Encodable {
    public func sign(using account: Account) throws -> SignedData {
        let data = try JSONEncoder().encode(self)
        return try .create(with: data, account: account)
    }
}
