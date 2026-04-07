public enum AnchorAuthenticationMethod: String, Codable {
    case account = "keeta-account"
}

public enum AuthenticationType: String {
    case required
    case optional
    case none
}
