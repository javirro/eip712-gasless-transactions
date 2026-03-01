import { createWalletClient, http, publicActions } from 'viem'
import { RELAYER_ACCOUNT, SIGNER_ACCOUNT } from './config'
import { polygon } from 'viem/chains'
import { ADDRESSES, ERC20_PERMIT_ABI, META_RELAYER_ABI, USDC_ADDRESS } from './smartcontract/addresses'

async function gasslessERC20Transfer(destination: string, amount: string) {
  if (!destination || !amount) {
    console.error('Usage: pnpm gassless-transfer <destination> <amount>')
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

  const tokenAddress = USDC_ADDRESS[polygon.id]
  const metaRelayerAddress = ADDRESSES[polygon.id]

  // --- Fetch on-chain data in parallel ---
  const [nameAndVersion, metaNonce, tokenName, tokenVersion, permitNonce, decimals] = await Promise.all([
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
    }) as Promise<bigint>,
    signerWalletClient.readContract({
      address: tokenAddress,
      abi: ERC20_PERMIT_ABI,
      functionName: 'name'
    }) as Promise<string>,
    signerWalletClient.readContract({
      address: tokenAddress,
      abi: ERC20_PERMIT_ABI,
      functionName: 'version'
    }) as Promise<string>,
    signerWalletClient.readContract({
      address: tokenAddress,
      abi: ERC20_PERMIT_ABI,
      functionName: 'nonces',
      args: [SIGNER_ACCOUNT.address]
    }) as Promise<bigint>,
    signerWalletClient.readContract({
      address: tokenAddress,
      abi: ERC20_PERMIT_ABI,
      functionName: 'decimals'
    }) as Promise<number>
  ])

  const weiAmount = BigInt(amount) * BigInt(10 ** decimals)
  const deadline = BigInt(Math.floor(Date.now() / 1000) + 3600) // 1 hour from now

  // =============================================
  // 1. Generate ERC-2612 Permit Signature
  // =============================================
  const permitDomain = {
    name: tokenName,
    version: tokenVersion,
    chainId: polygon.id,
    verifyingContract: tokenAddress
  } as const

  const permitTypes = {
    Permit: [
      { name: 'owner', type: 'address' },
      { name: 'spender', type: 'address' },
      { name: 'value', type: 'uint256' },
      { name: 'nonce', type: 'uint256' },
      { name: 'deadline', type: 'uint256' }
    ]
  }

  const permitMessage = {
    owner: SIGNER_ACCOUNT.address,
    spender: metaRelayerAddress,
    value: weiAmount,
    nonce: permitNonce,
    deadline
  }

  const permitSignature = await signerWalletClient.signTypedData({
    domain: permitDomain,
    types: permitTypes,
    primaryType: 'Permit',
    message: permitMessage
  })

  console.log('Generated ERC-2612 permit signature:', permitSignature)

  // =============================================
  // 2. Generate Meta-Transfer EIP-712 Signature
  // =============================================
  const metaDomain = {
    name: nameAndVersion[0],
    version: nameAndVersion[1],
    chainId: polygon.id,
    verifyingContract: metaRelayerAddress
  } as const

  const metaTypes = {
    MetaTransfer: [
      { name: 'token', type: 'address' },
      { name: 'from', type: 'address' },
      { name: 'to', type: 'address' },
      { name: 'amount', type: 'uint256' },
      { name: 'nonce', type: 'uint256' },
      { name: 'deadline', type: 'uint256' }
    ]
  }

  const metaMessage = {
    token: tokenAddress,
    from: SIGNER_ACCOUNT.address,
    to: destination as `0x${string}`,
    amount: weiAmount,
    nonce: metaNonce,
    deadline
  }

  const transferSignature = await signerWalletClient.signTypedData({
    domain: metaDomain,
    types: metaTypes,
    primaryType: 'MetaTransfer',
    message: metaMessage
  })

  console.log('Generated EIP-712 meta-transfer signature:', transferSignature)

  // =============================================
  // 3. Relayer submits the transaction on-chain
  // =============================================
  const txHash = await relayerWalletClient.writeContract({
    address: metaRelayerAddress,
    abi: META_RELAYER_ABI,
    functionName: 'executeGaslessTx',
    args: [tokenAddress, SIGNER_ACCOUNT.address, destination as `0x${string}`, weiAmount, deadline, permitSignature, transferSignature]
  })

  console.log('Transaction submitted! Hash:', txHash)

  const receipt = await relayerWalletClient.waitForTransactionReceipt({ hash: txHash })
  console.log('Transaction confirmed in block:', receipt.blockNumber)
  console.log('Status:', receipt.status === 'success' ? 'SUCCESS' : 'REVERTED')
}

const args = process.argv.slice(2)
const destination = args[0]
const amount = args[1]
gasslessERC20Transfer(destination, amount).catch((error) => {
  console.error('Error executing gasless ERC20 transfer:', error)
  process.exit(1)
})
