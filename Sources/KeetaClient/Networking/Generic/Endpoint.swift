import Foundation

public typealias JSON = [String: Any]

public protocol Endpoint {
    var url: URL { get throws }
    var method: String { get }
    var header: [String: String]? { get }
    var query: [String: String] { get }
    var body: JSON? { get }
}

public enum RequestMethod: String {
    case delete
    case get
    case patch
    case post
    case put
    
    public var value: String { rawValue.uppercased() }
}
