import Foundation

public enum RequestError<T>: Error {
    case invalidURL
    case invalidJSON
    case noResponse
    case decodingError(error: Error, data: Data)
    case unauthorized
    case invalidResponse(statusCode: Int, String?)
    case unknownError(statusCode: Int, response: String?, error: Error)
    case error(statusCode: Int, error: T)
}
