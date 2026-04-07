import Foundation
import Testing
import KeetaClient

@Suite(.serialized) struct UsernameAnchorTests {

    @Test func searchInvalidUsername() async throws {
        let anchor = try devUsernameAnchor()

        do {
            _ = try await anchor.search(query: "invalid-username")
            Issue.record("Expected search for invalid username to fail")
        } catch RequestError<AnchorError>.error(_, _) {
            // expected
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test func searchUnclaimedUsername() async throws {
        let anchor = try devUsernameAnchor()
        let username = randomUsername()

        let results = try await anchor.search(query: username)
        #expect(results.isEmpty)
    }

    @Test func claimProviderIdMismatch() async throws {
        let anchor = try devUsernameAnchor()
        let account = try AccountBuilder.new()
        let username = randomUsername()

        do {
            try await anchor.claim(for: account, username: "\(username)$keeta")
            Issue.record("Expected providerIdMismatch error")
        } catch UsernameAnchorError.providerIdMismatch {
            // expected
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test func claimAndResolve() async throws {
        let anchor = try devUsernameAnchor()
        let account = try AccountBuilder.new()
        let username = randomUsername()

        let claimed = try await anchor.claim(for: account, username: username)
        #expect(claimed)

        let resolution = try #require(try await anchor.resolve(account: account))
        #expect(resolution.username == username)
        #expect(resolution.account == account.publicKeyString)
        #expect(resolution.providerID == "dev")
    }

    @Test func searchClaimedUsername() async throws {
        let anchor = try devUsernameAnchor()
        let account = try AccountBuilder.new()
        let username = randomUsername()

        try await anchor.claim(for: account, username: username)

        let results = try await anchor.search(query: username)

        #expect(results.count == 1)
        #expect(results.first?.account == account.publicKeyString)
        #expect(results.first?.username == username)
    }

    @Test func claimAlreadyTakenUsername() async throws {
        let anchor = try devUsernameAnchor()
        let account = try AccountBuilder.new()
        let anotherAccount = try AccountBuilder.new()
        let username = randomUsername()

        try await anchor.claim(for: account, username: username)

        do {
            try await anchor.claim(for: anotherAccount, username: username)
            Issue.record("Expected error when claiming already taken username")
        } catch RequestError<AnchorError>.error(_, _) {
            // expected
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test func transferUsername() async throws {
        let anchor = try devUsernameAnchor()
        let account = try AccountBuilder.new()
        let anotherAccount = try AccountBuilder.new()
        let username = randomUsername()

        try await anchor.claim(for: account, username: username)

        do {
            try await anchor.claim(for: anotherAccount, username: username, transfer: .fromSigner(account))
        } catch {
            Issue.record("Expected transfer to succeed: \(error)")
            return
        }

        let resolution = try #require(try await anchor.resolve(account: anotherAccount))
        #expect(resolution.username == username)
        #expect(resolution.account == anotherAccount.publicKeyString)

        let oldResolution = try await anchor.resolve(account: account)
        #expect(oldResolution == nil)
    }

    @Test func releaseUsername() async throws {
        let anchor = try devUsernameAnchor()
        let account = try AccountBuilder.new()
        let username = randomUsername()

        try await anchor.claim(for: account, username: username)

        let released = try await anchor.release(for: account)
        #expect(released)

        let results = try await anchor.search(query: username)
        #expect(results.isEmpty)
    }

    @Test func resolveUnclaimedUsername() async throws {
        let anchor = try devUsernameAnchor()
        let account = try AccountBuilder.new()

        let resolution = try await anchor.resolve(account: account)
        #expect(resolution == nil)
    }

    // MARK: - Helpers

    private func randomUsername() -> String {
        "test_swift_\(Int.random(in: 1..<9999999))"
    }

    private func devUsernameAnchor() throws -> UsernameAnchor {
        let baseURL = "https://username-anchor.dev2.api.keeta.com"
        let authRequired: [AnchorOperation.Option] = [.authentication(type: .required, method: .account)]

        let operations: [UsernameAnchor.Operation: AnchorOperation] = [
            .resolve: AnchorOperation(url: baseURL + "/api/resolve/{toResolve}", parameters: ["toResolve"], options: []),
            .claim: AnchorOperation(url: baseURL + "/api/claim", parameters: [], options: authRequired),
            .release: AnchorOperation(url: baseURL + "/api/release", parameters: [], options: authRequired),
            .search: AnchorOperation(url: baseURL + "/api/search", parameters: [], options: [])
        ]

        return try .init(name: "dev", usernamePattern: nil, operations: operations)
    }
}
