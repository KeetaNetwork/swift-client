import Foundation

public struct TokenInfo: Codable, Hashable, Identifiable {
    public let address: String
    public let name: String
    public let description: String?
    public let supply: Double
    public let decimalPlaces: Int
    public let icon: TokenIcon?
    
    public init(address: String, name: String, description: String?, supply: Double, decimalPlaces: Int, icon: TokenIcon? = nil) {
        self.address = address
        self.name = name
        self.description = description
        self.supply = supply
        self.decimalPlaces = decimalPlaces
        self.icon = icon
    }
    
    public var id: String { address }
}

public enum TokenIcon: Codable, Hashable {
    case remote(URL)
    case data(URL)
    case raw(Data)
    
    public static func create(from uri: String?) -> TokenIcon? {
        guard let uri else { return nil }
        
        if let url = URL(string: uri) {
            switch url.scheme {
            case "https", "http": return .remote(url)
            case "data": return .data(url)
            default: break
            }
        }
        
        if let data = Data(base64Encoded: uri) {
            return .raw(data)
        }
        
        return nil
    }
}

public enum MetaDataError: Error {
    case invalidImage
    case invalidImageData
}

public struct MetaData: Codable {
    public let decimalPlaces: Int
    public let logoURI: String?
    
    public init(decimalPlaces: Int, icon: TokenIcon?) throws {
        switch icon {
        case .remote(let url), .data(let url):
            self.init(decimalPlaces: decimalPlaces, logoURI: url.absoluteString)
            
        case .raw(let data):
            guard let image = KeetaImage(data: data) else {
                throw MetaDataError.invalidImageData
            }
            try self.init(decimalPlaces: decimalPlaces, image: image)
            
        case nil:
            self.init(decimalPlaces: decimalPlaces, logoURI: nil)
        }
    }
    
    public init(decimalPlaces: Int, image: KeetaImage?) throws {
        let logoURI: String?
        if let image {
            guard let data = image.jpegData(compressionQuality: 1) else {
                throw MetaDataError.invalidImage
            }
            logoURI = data.base64EncodedString()
        } else {
            logoURI = nil
        }
        
        self.init(decimalPlaces: decimalPlaces, logoURI: logoURI)
    }
    
    public init(decimalPlaces: Int, logoURI: String?) {
        self.decimalPlaces = decimalPlaces
        self.logoURI = logoURI
    }
}
