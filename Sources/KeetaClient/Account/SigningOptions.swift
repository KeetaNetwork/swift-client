import Foundation

public struct SigningOptions {
    public init(raw: Bool, forCert: Bool) {
        self.raw = raw
        self.forCert = forCert
    }
    
    public let raw: Bool
    public let forCert: Bool
    
    public static let `default` = Self(raw: false, forCert: false)
}
