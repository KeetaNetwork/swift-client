struct AccountStateResponse: Decodable {
	let account: String
    let currentHeadBlock: String?
    let representative: String?
    let balances: [AccountBalanceResponse]
    let info: AccountInfoResponse
}

struct AccountInfoResponse: Decodable {
    let name: String
    let description: String
    let metadata: String
    let supply: String?
//    let defaultPermission: Permissions?
}

struct AccountBalanceResponse: Decodable {
    let token: String
    let balance: String
}
