![Platform: iOS](https://img.shields.io/badge/platform-iOS-lightgrey.svg)
![Platform: macOS](https://img.shields.io/badge/platform-macOS-lightgrey.svg)

# Keeta Swift Client SDK

Official Swift SDK to interact with the [Keeta Network](https://keeta.com/).

### Installation

This package uses Swift Package Manager. To add it to your project using Xcode:

1. Go to `File > Add Packages...`
2. Enter the package URL: `https://github.com/KeetaNetwork/swift-client`
3. Select the desired version

### Quickstart

`KeetaClient` provides high-level methods to interact with the Keeta network.

While a more detailed developer documentation is on the way, please checkout the examples below:

```js
import BigInt
import KeetaClient

// 1. Generate a secure seed and create an account
let seed = try SeedGenerator.generate()
let account = try AccountBuilder.create(fromSeed: seed, index: 0)

print("Public Key:", account.publicKeyString) // e.g., keeta_aabpd...csrqxi

// 2. Initialize an account specific client for the test network
let client = KeetaClient(network: .test, account: account)
// Alternatively: let client = KeetaClient(network: .test)

// 3. Create a new token with an initial supply
let newToken = try await client.createToken(name: "DEMO", supply: BigInt(100))

// 4. Send some of minted tokens to the generated account
// ℹ️ Token accounts can't sign transactions — use the owner (account) as signer
try await client.send(amount: BigInt(10), from: newToken, to: account, token: newToken, signer: account)

// 5. Check the account's balance
let accountBalance = try await client.balance()
print("Account Balance:", accountBalance.balances[newToken.publicKeyString] ?? "0") // 10

// 6. Create a second account from the same seed with a different index
let recipient = try AccountBuilder.create(fromSeed: seed, index: 1)

// 7. Send tokens from the funded account to the new recipient
try await client.send(amount: BigInt(5), to: recipient, token: newToken)

// 8.Check the recipient's balance
let recipientBalance = try await client.balance(of: recipient)
print("Recipient Balance:", recipientBalance.balances[newToken.publicKeyString] ?? "0") // 5

// 9. List account transactions
let transactions = try await client.transactions()
print("Transactions:", transactions) // [ -5 tokens sent, +10 tokens received ]

// 10. Token swap between the two accounts
try await client.swap(
    with: recipient,
    offer: .init(amount: BigInt(1), token: newToken),
    ask: .init(amount: BigInt(5), token: newToken)
)
```

## Components

### SeedGenerator

`SeedGenerator` is a lightweight utility for generating cryptographic seeds and [BIP-39 mnemonic phrases](https://iancoleman.io/bip39/).  
It uses secure randomness from Apple's `SecRandomCopyBytes` and supports both seed-to-phrase and phrase-to-seed transformations.

**Usage**
```js
// Generate a secure seed (hex string)
let seed = try SeedGenerator.generate()

// Generate mnemonic phrase from a given seed
let phrase = try SeedGenerator.bip39Passphrase(using: seed)

// Get a list of 12 unique mnemonic words
let words = try SeedGenerator.randomWords(count: 12)

// Convert mnemonic phrase back into seed
let recoveredSeed = try SeedGenerator.from(bip39Phrase: words)
```

### AccountBuilder

AccountBuilder is a utility for creating and validating Keeta Account objects from seeds, private keys, or encoded public keys.  
It supports cryptographic key generation using [ECDSA secp256k1](https://xilinx.github.io/Vitis_Libraries/security/2021.2/guide_L1/internals/ecdsa_secp256k1.html) and [Ed25519](https://ed25519.cr.yp.to/) algorithm.

**Usage**
```js
let publicKey = "keeta_aehscfp2bsnba2ak53fwjkzoavsk5unpqinhfp4ypkv7q6q222bfcko6njrbw"
try AccountBuilder.create(fromPublicKey: publicKey) // can't sign blocks as there is no private key

let privateKey = "6823B06E9A84281499ADDFF3719B7A530B8E8C9764629858C73DCA7844675346"
try AccountBuilder.create(fromPrivateKey: privateKey, algorithm: .ECDSA_SECP256K1)

let seed = "2401D206735C20485347B9A622D94DE9B21F2F1450A77C42102237FA4077567D"
try AccountBuilder.create(fromSeed: seed, index: 0, algorithm: .ECDSA_SECP256K1)
```

### BlockBuilder

The BlockBuilder class provides a flexible, safe, and structured way to assemble and blocks for the Keeta network.  
Each block must reference the previous account block correctly and contain no more than 500 operations.

Supported Operations
- `SendOperation`
- `SetRepOperation`
- `TokenAdminSupplyOperation`
- `CreateIdentifierOperation`
- `TokenAdminModifyBalanceOperation`
- `SetInfoOperation`
- `ReceiveOperation`

**Usage**
```js
let config: NetworkConfig = try .create(for: .test)

let sendBlock = try BlockBuilder()
        .start(from: nil, network: config.networkID)
        .add(account: senderAccount) // the block will be added to it's chain
        .add(operation: SendOperation(amount: 10, to: recipientAccount, token: baseToken))
        .seal()

let consecutiveBlock = try BlockBuilder()
        .start(from: sendBlock.hash, network: config.networkID)
        .add(account: tokenAccount)
        .add(signer: ownerAccount) // sign on behalf of token account
        .add(operation: SetInfoOperation(name: "Demo Account".uppercased()))
        .seal()

// Manually constructed blocks can be published using the KeetaApi. Please check the fees section for further details.
```

### KeetaClient

A high-level client that uses the core components to provide a seamless interaction with the Keeta network.

**Instantiation**
```js
// Account-specific
let client = KeetaClient(network: .test, account: account)

// Generic client
let client = KeetaClient(network: .test)
```

### KeetaApi

Interact with the network directly, specify which rep to talk to, recover accounts and more.

**Instantiation**
```js
let api = try KeetaApi(config: .create(for: .test))
```

### Fees

Representatives may charge a fee to issue permanent votes. Permanent votes are required to publish a block to the network. Fees are handled automatically when using the `KeetaClient`. When publishing blocks manually using the `KeetaApi`, an additional block to pay the fees has to be included using the `feeBlockBuilder` completion.

**Publish a Block via API**
```js
let network: NetworkAlias = .main

let api = try KeetaApi(network: network)

// Use the `AccountBuilder` to create a 'senderAccount'
// Use the `BlockBuilder` to construct a 'sendBlock'

try await api.publish(blocks: [sendBlock]) { temporaryStaple in
    // Compute the fee block, will be published together with the 'sendBlock'
    try BlockBuilder.feeBlock(for: temporaryStaple, account: senderAccount, network: network)
}
```

