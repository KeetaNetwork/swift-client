import Foundation

public struct AnchorError: Error, Decodable {

    public let name: String
    public let error: String
    public let fields: [ValidationField]?

    public struct ValidationField: Decodable {
        public let path: String?
        public let message: String
        public let expected: String?
        public let receivedValue: AnyReceivedValue?
        public let allowedValues: [String]?
    }

    /// Type-erased Decodable to handle `receivedValue: unknown` from the server.
    public struct AnyReceivedValue: Decodable, CustomStringConvertible {
        public let value: Any

        public init(from decoder: Swift.Decoder) throws {
            let container = try decoder.singleValueContainer()
            if let string = try? container.decode(String.self) {
                value = string
            } else if let int = try? container.decode(Int.self) {
                value = int
            } else if let double = try? container.decode(Double.self) {
                value = double
            } else if let bool = try? container.decode(Bool.self) {
                value = bool
            } else {
                value = try container.decode(String.self)
            }
        }

        public var description: String { "\(value)" }
    }

    enum CodingKeys: String, CodingKey {
        case name, error, data
    }

    enum DataKeys: String, CodingKey {
        case fields
    }

    public init(from decoder: Swift.Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? "Unknown"
        error = try container.decodeIfPresent(String.self, forKey: .error) ?? "Unknown error"

        if let dataContainer = try? container.nestedContainer(keyedBy: DataKeys.self, forKey: .data) {
            fields = try dataContainer.decodeIfPresent([ValidationField].self, forKey: .fields)
        } else {
            fields = nil
        }
    }
}

extension AnchorError: LocalizedError {
    public var errorDescription: String? { error }
}
