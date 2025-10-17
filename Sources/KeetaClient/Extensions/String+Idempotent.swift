enum IdempotentError: Error {
    case invalidString(String)
}

extension String {
    public func idempotent() throws -> String {
        guard let data = data(using: .utf8) else {
            throw IdempotentError.invalidString(self)
        }
        return data.base64EncodedString()
    }
}
