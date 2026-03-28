import { createWalletClient, http, publicActions } from 'viem'
import { RELAYER_ACCOUNT, SIGNER_ACCOUNT } from './config'
import { polygon } from 'viem/chains'
import { ADDRESSES, META_RELAYER_ABI } from './smartcontract/addresses'

async function executeGenericGaslessTx(target: string, data: `0x${string}`) {
  if (!target || !data) {
    console.error('Usage: pnpm generic-gasless-tx <target> <data>')
    process.exit(1)
  }

  const relayerWalletClient = createWalletClient({
    chain: polygon,
    transport: http(),
    account: RELAYER_ACCOUNT
  }).extend(publicActions)

  const signerWalletClient = createWalletClient({
    chain: polygon,
    transport: http(),
    account: SIGNER_ACCOUNT
  }).extend(publicActions)

  const metaRelayerAddress = ADDRESSES[polygon.id]

  // --- Fetch on-chain data in parallel ---
  const [nameAndVersion, nonce] = await Promise.all([
    relayerWalletClient.readContract({
      address: metaRelayerAddress,
      abi: META_RELAYER_ABI,
      functionName: 'getNameAndVersion'
    }) as Promise<[string, string]>,
    signerWalletClient.readContract({
      address: metaRelayerAddress,
      abi: META_RELAYER_ABI,
      functionName: 'nonces',
      args: [SIGNER_ACCOUNT.address]
    }) as Promise<bigint>
  ])

  const deadline = BigInt(Math.floor(Date.now() / 1000) + 3600) // 1 hour from now

  // =============================================
  // 1. Generate MetaTx EIP-712 Signature
  // =============================================
  const metaDomain = {
    name: nameAndVersion[0],
    version: nameAndVersion[1],
    chainId: polygon.id,
    verifyingContract: metaRelayerAddress
  } as const

  const metaTypes = {
    MetaTx: [
      { name: 'from', type: 'address' },
      { name: 'target', type: 'address' },
      { name: 'data', type: 'bytes' },
      { name: 'nonce', type: 'uint256' },
      { name: 'deadline', type: 'uint256' }
    ]
  }

  const metaMessage = {
    from: SIGNER_ACCOUNT.address,
    target: target as `0x${string}`,
    data,
    nonce,
    deadline
  }

  const signature = await signerWalletClient.signTypedData({
    domain: metaDomain,
    types: metaTypes,
    primaryType: 'MetaTx',
    message: metaMessage
  })

  console.log('Generated EIP-712 meta-tx signature:', signature)

  // =============================================
  // 2. Relayer submits the transaction on-chain
  // =============================================
  const txHash = await relayerWalletClient.writeContract({
    address: metaRelayerAddress,
    abi: META_RELAYER_ABI,
    functionName: 'executeMetaTx',
    args: [SIGNER_ACCOUNT.address, target as `0x${string}`, data, deadline, signature]
  })

  console.log('Transaction submitted! Hash:', txHash)

  const receipt = await relayerWalletClient.waitForTransactionReceipt({ hash: txHash })
  console.log('Transaction confirmed in block:', receipt.blockNumber)
  console.log('Status:', receipt.status === 'success' ? 'SUCCESS' : 'REVERTED')
}

const args = process.argv.slice(2)
const target = args[0]
const data = args[1] as `0x${string}`
executeGenericGaslessTx(target, data).catch((error) => {
  console.error('Error executing generic gasless tx:', error)
  process.exit(1)
})
