import Foundation

public struct Verification: Identifiable, Codable {
    public let id: String
    public let expectedCost: Cost
    public let webUrl: URL
}

public enum KYCRedirectStatus: String {
    case completed
    case cancelled
    case failed

    public init?(from url: URL) {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let status = components.queryItems?.first(where: { $0.name == "status" })?.value,
              let parsed = KYCRedirectStatus(rawValue: status) else {
            return nil
        }
        self = parsed
    }
}
