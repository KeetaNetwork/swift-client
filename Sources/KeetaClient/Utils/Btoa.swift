import Foundation

// Encoding
public extension Encodable {
    func btoa() throws -> String {
        let jsonData = try JSONEncoder().encode(self)
        guard let jsonString = String(data: jsonData, encoding: .utf8) else {
            throw NSError(domain: "Invalid JSON data", code: 0)
        }
        return try jsonString.btoa()
    }
}

public extension String {
    func btoa() throws -> String {
        if isEmpty { return self }
        
        guard let latin1Data = data(using: .isoLatin1) else {
            throw NSError(domain: "Invalid ISO-Latin1 string", code: 0)
        }
        return latin1Data.base64EncodedString()
    }
}

// Decoding
public extension Decodable {
    static func create(from btoa: String) throws -> Self {
        guard let decodedData = Data(base64Encoded: btoa) else {
            throw NSError(domain: "Invalid base64 string", code: 0)
        }
        return try JSONDecoder().decode(Self.self, from: decodedData.btoa())
    }
}

public extension Data {
    func btoa() throws -> Data {
        guard let latin1String = String(data: self, encoding: .isoLatin1) else {
            throw NSError(domain: "Invalid Latin-1 data", code: 0)
        }
        guard let utf8Data = latin1String.data(using: .utf8) else {
            throw NSError(domain: "Failed to convert Latin-1 string", code: 0)
        }
        return utf8Data
    }
}
