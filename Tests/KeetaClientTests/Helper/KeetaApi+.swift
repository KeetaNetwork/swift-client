import XCTest
import BigInt
import KeetaClient

extension KeetaApi {
    @discardableResult
    func send(amount: BigInt, from fromAccount: Account, to toAccount: Account, config: NetworkConfig) async throws -> String {
        let previousBlockHash = try await balance(for: fromAccount).currentHeadBlock
        let send = try SendOperation(amount: amount, to: toAccount, token: config.baseToken)
        
        let sendBlock = try BlockBuilder()
            .start(from: previousBlockHash, network: config.networkID)
            .add(signer: fromAccount)
            .add(operation: send)
            .seal()
        
        try await publish(blocks: [sendBlock], networkAlias: config.networkAlias)
        
        return sendBlock.hash
    }
    
    @discardableResult
    func verify(account: Account, head: String?, balance: BigInt? = nil)  async throws -> AccountBalance {
        let result = try await self.balance(for: account)
        
        XCTAssertEqual(result.account, account.publicKeyString)
        if let balance = balance {
            XCTAssertEqual(result.balances.first?.value, balance)
        }
        XCTAssertEqual(result.currentHeadBlock, head)

        return result
    }
}
