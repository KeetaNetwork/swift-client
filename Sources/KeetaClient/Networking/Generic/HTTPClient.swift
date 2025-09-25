import Foundation

public protocol HTTPClient {
    func sendRequest<T: Decodable>(to endpoint: Endpoint, decoder: Decoder) async throws -> T
}

extension HTTPClient {
    
    public func sendRequest<R: Decodable, E: Decodable>(
        to endpoint: Endpoint,
        error errorType: E.Type,
        decoder: Decoder
    ) async throws -> R {
        do {
            return try await sendRequest(to: endpoint, decoder: decoder)
        } catch RequestError<Error>.invalidResponse(let statusCode, let response) {
            guard let response, let data = response.data(using: .utf8) else {
                throw RequestError<E>.invalidResponse(statusCode: statusCode, response)
            }
            
            let error: E
            do {
                error = try JSONDecoder().decode(E.self, from: data)
            } catch {
                throw RequestError<E>.unknownError(statusCode: statusCode, response: response, error: error)
            }
            throw RequestError<E>.error(statusCode: statusCode, error: error)
        } catch {
            throw error
        }
    }
    
    public func sendRequest<T: Decodable>(to endpoint: Endpoint, decoder: Decoder) async throws -> T {
        let data = try await sendRequest(to: endpoint)
        
        do {
            return try decoder.decode(T.self, from: data)
        } catch let error {
            #if DEBUG
            print("RESPONSE: \(String(describing: String(data: data, encoding: .utf8)))")
            #endif
            throw RequestError<Error>.decodingError(error: error, data: data)
        }
    }
    
    public func sendRequest(to endpoint: Endpoint) async throws -> Data {
        var components = URLComponents(url: try endpoint.url, resolvingAgainstBaseURL: false)!
        
        if !endpoint.query.isEmpty {
            components.queryItems = endpoint.query.map { URLQueryItem(name: $0.key, value: $0.value) }
        }
        
        guard let url = components.url else {
            throw RequestError<Error>.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = endpoint.method
        request.allHTTPHeaderFields = endpoint.header

        if let body = endpoint.body {
            request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
            
        guard let response = response as? HTTPURLResponse else {
            #if DEBUG
            print("REQUEST: \(request)")
            #endif
            throw RequestError<Error>.noResponse
        }
        
        switch response.statusCode {
        case 200...299:
            return data
        case 401:
            throw RequestError<Error>.unauthorized
        default:
            #if DEBUG
            print("REQUEST: \(request)")
            print("RESPONSE \(response.statusCode): \(String(describing: String(data: data, encoding: .utf8)))")
            #endif
            
            throw RequestError<Error>.invalidResponse(statusCode: response.statusCode, String(data: data, encoding: .utf8))
        }
    }
}
