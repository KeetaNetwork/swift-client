import Foundation
import Testing
import KeetaClient

struct AnchorResolverTests {

    @Test func resolveServiceMetaData() async throws {
        let metadata = try await AnchorResolver.serviceMetaData(for: .test)

        #expect(metadata["kyc"] != nil)
        #expect(metadata["assetMovement"] != nil)
    }

    @Test func resolveUsernameAnchorFromAccountMetaData() async throws {
        let account = try AccountBuilder.create(fromPublicKey: "keeta_aabss4qwb3ek4h2w5kicdklop2elyrr3evwwrid4nbvdvlapkngzpqh3avqzkpq")

        let anchor = try await AnchorResolver.usernameAnchors(for: account, network: .test)

        #expect(!anchor.operations.isEmpty)
    }
}
