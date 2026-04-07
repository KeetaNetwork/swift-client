import Foundation

public enum AnchorResolverError: Error {
    case invalidServiceUrl(String)
    case invalidMetaData(Any)
}

public struct AnchorResolver: HTTPClient {

    public static func identityAnchors(for network: NetworkAlias) async throws -> [IdentityAnchor] {
        let config = try await serviceMetaData(for: network)
        return try IdentityAnchor.parse(metadata: config)
    }

    public static func usernameAnchors(for account: Account, network: NetworkAlias) async throws -> UsernameAnchor {
        let api = try KeetaApi(network: network)
        let accountInfo = try await api.accountInfo(for: account)

        guard let compressedData = Data(base64Encoded: accountInfo.metadata) else {
            throw AnchorResolverError.invalidMetaData(accountInfo.metadata)
        }

        let decompressedData = decompress(compressedData)
        let jsonObject = try JSONSerialization.jsonObject(with: decompressedData, options: [])

        guard let json = jsonObject as? JSON,
              let services = json["services"] as? JSON else {
            throw AnchorResolverError.invalidMetaData(jsonObject)
        }

        let anchors = try UsernameAnchor.parse(metadata: services)

        guard let anchor = anchors.first else {
            throw UsernameAnchorError.metaDataProviderMissing
        }

        return anchor
    }
    
    public static func usernameAnchors(for network: NetworkAlias) async throws -> [UsernameAnchor] {
        let config = try await serviceMetaData(for: network)
        return try UsernameAnchor.parse(metadata: config)
    }

    public static func serviceMetaData(for network: NetworkAlias) async throws -> JSON {
        guard let url = URL(string: network.serviceUrl) else {
            throw AnchorResolverError.invalidServiceUrl(network.serviceUrl)
        }

        var request = URLRequest(url: url)
        request.httpMethod = RequestMethod.get.value

        let data = try await Self().sendRequest(request)
        let metaData = try JSONSerialization.jsonObject(with: data, options: [])

        guard let json = metaData as? JSON else {
            throw AnchorResolverError.invalidMetaData(metaData)
        }
        return json
    }
}
