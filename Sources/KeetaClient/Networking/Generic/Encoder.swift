import Foundation

public protocol Encoder {
    func encode<T: Encodable>(_ value: T) throws -> Data
}

extension JSONEncoder: Encoder {}
