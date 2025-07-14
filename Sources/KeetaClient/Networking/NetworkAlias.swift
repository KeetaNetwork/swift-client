import Foundation

public enum NetworkAlias: String {
    case test
    
    public func keetaRepApiBaseUrl(number: Int = 1) -> String {
        switch self {
        case .test: "https://rep\(number).test.network.api.keeta.com/api"
        }
    }
    
    public func keetaRepSocketBaseUrl(number: Int = 1) -> String {
        switch self {
        case .test: "wss://rep\(number).test.network.api.keeta.com/p2p"
        }
    }
    
    public func keetaRepAddress(number: Int = 1) -> String {
        let addresses = switch self {
        case .test: [
            "keeta_aabi4bd3f7jrt67mxcq44ozj65bh4bp2mygmrkedxggu2rxwn2ztuw3b6exivbq",
            "keeta_aab3cxegizwhtim3zlyuwjhiqd5ikkhxg42smhwc3wx6yn7ep2t6lwo6emvw4wa",
            "keeta_aabznoicrzvte6ql5rxbgugmfrjqubbnjuo5l6ivopowy4rpkqgs5fco3oaezcq",
            "keeta_aabf7dz5asq2n2lrldct33x2ww65cophxp7egfiixbb7tbyat5r3kcbcez7ftpi"
        ]
        }
        
        return addresses[number - 1]
    }
    
    public func keetaPublishAidBaseUrl() -> String {
        switch self {
        case .test: "https://publish-aid.test.network.api.keeta.com/api"
        }
    }
}
