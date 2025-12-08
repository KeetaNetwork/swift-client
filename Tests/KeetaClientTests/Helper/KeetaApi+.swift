import XCTest
import BigInt
import KeetaClient

extension KeetaApi {
    @discardableResult
    func send(amount: BigInt, from fromAccount: Account, to toAccount: Account, config: NetworkConfig) async throws -> String {
        let previousBlockHash = try await balance(for: fromAccount).currentHeadBlock
        let send = try SendOperation(amount: amount, to: toAccount, token: config.baseToken)
        
        let sendBlock = try BlockBuilder()
            .start(from: previousBlockHash, network: config.network.id)
            .add(signer: fromAccount)
            .add(operation: send)
            .seal()
        
        let result = try await publish(
            blocks: [sendBlock],
            feeBlockBuilder: { try await BlockBuilder.feeBlock(for: $0, account: fromAccount, api: self) }
        )
        
        return result.staple.blocks.last!.hash
    }
    
    @discardableResult
    func verify(
        account: Account,
        head: String?,
        balance: BigInt? = nil,
        callLine: UInt = #line,
        file: StaticString = #file
    )  async throws -> AccountBalance {
        let result = try await self.balance(for: account)
        
        XCTAssertEqual(result.account, account.publicKeyString, file: file, line: callLine)
        if let balance = balance {
            XCTAssertEqual(result.rawBalances.first?.value, balance, file: file, line: callLine)
        }
        XCTAssertEqual(result.currentHeadBlock, head, file: file, line: callLine)

        return result
    }
}
