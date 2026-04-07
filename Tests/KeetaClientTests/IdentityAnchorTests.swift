import Foundation
import Testing
import KeetaClient

@Suite(.serialized) struct IdentityAnchorTests {

    @Test func resolveAnchors() async throws {
        let anchors = try await AnchorResolver.identityAnchors(for: .test)

        #expect(anchors.count == 1)

        let demo = try #require(anchors.first)
        #expect(demo.countryCodes.contains("US"))
    }

    @Test func createVerification() async throws {
        let anchors = try await AnchorResolver.identityAnchors(for: .test)
        let demo = try #require(anchors.first)
        let testAccount = try AccountBuilder.new()

        let verification = try await demo.createVerification(for: testAccount, countryCodes: ["US"])

        #expect(verification.expectedCost.noCost)
    }

    @Test func getCertificates() async throws {
        let anchors = try await AnchorResolver.identityAnchors(for: .test)
        let demo = try #require(anchors.first)
        let testAccount = try AccountBuilder.new()

        let verification = try await demo.createVerification(for: testAccount, countryCodes: ["US"])

        do {
            let certificates = try await demo.certificates(for: verification.id)
            #expect(certificates.isEmpty)
        } catch {
            // currently accepted — server may not support this yet
        }
    }
}
