import Foundation

public enum AnchorOperationError: Error {
    case invalidConfig(JSON)
    case invalidUrl(Any)
    case missingUrlParameters(Set<String>)
    case missingOperation(Any)
    case unknownOperationAuthentication
}

public struct AnchorOperation {
    public enum Option {
        public enum CodingKeys: String, CodingKey, CaseIterable {
            case authentication
        }
        
        case authentication(type: AuthenticationType, method: AnchorAuthenticationMethod)
        
        public static func parse(_ metadata: JSON) throws -> [Self] {
            var results = [Self]()
            
            for key in CodingKeys.allCases {
                switch key {
                case .authentication:
                    guard let authentication = metadata["authentication"] as? JSON else { continue }
                    let type = (authentication["type"] as? String).flatMap(AuthenticationType.init) ?? .none
                    guard let methodRaw = authentication["method"] as? String,
                            let method = AnchorAuthenticationMethod(rawValue: methodRaw) else {
                        throw AnchorOperationError.unknownOperationAuthentication
                    }
                    results.append(.authentication(type: type, method: method))
                }
            }
            
            return results
        }
    }
    
    public let url: String
    public let parameters: [String]
    public let options: [Option]
    
    public static func parse<Operation: RawRepresentable & CaseIterable & Equatable>(
        from config: JSON
    ) throws -> [Operation: Self] where Operation.RawValue == String {
        guard let operationsRaw = config["operations"] as? JSON else {
            throw AnchorOperationError.invalidConfig(config)
        }
        
        var results = [Operation: Self]()
        
        for (key, value) in operationsRaw {
            guard let type = Operation(rawValue: key) else {
                continue // ignore unknown operations
            }
            
            let url: String
            let options: [Option]
            
            if let valueJson = value as? JSON {
                guard let urlValue = valueJson["url"] as? String else {
                    throw AnchorOperationError.invalidUrl(valueJson)
                }
                url = urlValue
                if let optionsJson = valueJson["options"] as? JSON {
                    options = try Option.parse(optionsJson)
                } else {
                    options = []
                }
            } else if let urlValue = value as? String {
                url = urlValue
                options = []
            } else {
                throw AnchorOperationError.invalidUrl(value)
            }
            
            // parse parameters
            let pattern = #"\{([^}]+)\}"#
            let regex = try NSRegularExpression(pattern: pattern)
            let matches = regex.matches(in: url, range: NSRange(url.startIndex..., in: url))
            let parameters = matches.compactMap {
                Range($0.range(at: 1), in: url).map { String(url[$0]) }
            }
            
            results[type] = .init(url: url, parameters: parameters, options: options)
        }
        
        return results
    }
    
    public init(url: String, parameters: [String], options: [Option]) {
        self.url = url
        self.parameters = parameters
        self.options = options
    }
    
    public func url(with parameters: [String: String]) throws -> URL {
        // Verify all required parameters are available
        let remainingParameters = Set(self.parameters).subtracting(parameters.keys)
        
        guard remainingParameters.isEmpty else {
            throw AnchorOperationError.missingUrlParameters(remainingParameters)
        }
        
        var resolved = url
        
        for (key, value) in parameters {
            resolved = resolved.replacingOccurrences(of: "{\(key)}", with: value)
        }
        
        guard let url = URL(string: resolved) else {
            throw AnchorOperationError.invalidUrl(resolved)
        }
        return url
    }
}
