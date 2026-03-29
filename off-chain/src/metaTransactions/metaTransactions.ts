import { createWalletClient, encodeFunctionData, http, publicActions } from 'viem'
import { RELAYER_ACCOUNT, SIGNER_ACCOUNT } from '../config'
import { sepolia } from 'viem/chains'
import { EXAMPLE_SMART_CONTRACT_ABI, EXAMPLE_SMART_CONTRACT_ADDRESS, META_TRANSACTIONS_ABI, META_TRANSACTIONS_ADDRESS } from '../smartcontract/addresses'

// Function to execute a meta-transaction calling a function on the example smart contract
async function metaTransactions(amount: string) {
  if (!amount) {
    console.error('Usage: pnpm meta-transaction  <amount>')
    process.exit(1)
  }
  const relayerWalletClient = createWalletClient({
    chain: sepolia,
    transport: http(),
    account: RELAYER_ACCOUNT
  }).extend(publicActions)

  const signerWalletClient = createWalletClient({
    chain: sepolia,
    transport: http(),
    account: SIGNER_ACCOUNT
  }).extend(publicActions)

  const smartContractExample = EXAMPLE_SMART_CONTRACT_ADDRESS[sepolia.id]
  const metaTransactionsContract = META_TRANSACTIONS_ADDRESS[sepolia.id]

  // --- Fetch on-chain data in parallel ---
  const [nameAndVersion, nonce] = await Promise.all([
    relayerWalletClient.readContract({
      address: metaTransactionsContract,
      abi: META_TRANSACTIONS_ABI,
      functionName: 'getNameAndVersion'
    }) as Promise<[string, string]>,
    signerWalletClient.readContract({
      address: metaTransactionsContract,
      abi: META_TRANSACTIONS_ABI,
      functionName: 'nonces',
      args: [SIGNER_ACCOUNT.address]
    }) as Promise<bigint>
  ])

  const deadline = BigInt(Math.floor(Date.now() / 1000) + 3600) // 1 hour from now

  // Prepare the call data for the target function (e.g., updateValue(uint256))
  const callFunctionData = await encodeFunctionData({
    abi: EXAMPLE_SMART_CONTRACT_ABI,
    functionName: 'updateValue',
    args: [amount]
  })

  // =============================================
  // 1. Generate MetaTx EIP-712 Signature
  // =============================================

  const TYPE = 'MetaTx'

  const metaDomain = {
    name: nameAndVersion[0],
    version: nameAndVersion[1],
    chainId: sepolia.id,
    verifyingContract: metaTransactionsContract
  } as const

  const metaTypes = {
    [TYPE]: [
      { name: 'from', type: 'address' },
      { name: 'target', type: 'address' },
      { name: 'data', type: 'bytes' },
      { name: 'nonce', type: 'uint256' },
      { name: 'deadline', type: 'uint256' }
    ]
  }

  const metaMessage = {
    from: SIGNER_ACCOUNT.address,
    target: smartContractExample as `0x${string}`,
    data: callFunctionData,
    nonce,
    deadline
  }

  const signature = await signerWalletClient.signTypedData({
    domain: metaDomain,
    types: metaTypes,
    message: metaMessage,
    primaryType: TYPE
  })

  console.log('Generated EIP-712 signature for meta-transaction:', signature)

  // Send transaction to the blockchain via the relayer
  const tx = await relayerWalletClient.writeContract({
    address: metaTransactionsContract,
    abi: META_TRANSACTIONS_ABI,
    functionName: 'executeMetaTx',
    args: [metaMessage.from, metaMessage.target, metaMessage.data,  metaMessage.deadline, signature]
  })

  await relayerWalletClient.waitForTransactionReceipt({ hash: tx })

  console.log('Meta-transaction submitted. Tx hash:', tx)
}

const args = process.argv.slice(2)
const amount = args[0]
metaTransactions(amount).catch((error) => {
  console.error('Error executing meta transactions:', error)
  process.exit(1)
})
