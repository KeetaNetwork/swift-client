import Foundation

public enum NetworkTransaction: Equatable, Codable {
    case send(NetworkSendTransaction)
    case receive(NetworkReceiveTransaction)
    
    public var created: Date {
        switch self {
        case .send(let send): send.created
        case .receive(let receive): receive.created
        }
    }
    
    public var blockHash: String {
        switch self {
        case .send(let send): send.blockHash
        case .receive(let receive): receive.blockHash
        }
    }
    
    public var stapleHash: String {
        switch self {
        case .send(let send): send.stapleHash
        case .receive(let receive): receive.stapleHash
        }
    }
    
    public var send: NetworkSendTransaction? {
        if case .send(let send) = self { send } else { nil }
    }
}
