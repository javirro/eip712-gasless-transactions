import { createWalletClient, http, publicActions } from 'viem'
import { RELAYER_ACCOUNT, SIGNER_ACCOUNT } from '../config'
import { sepolia } from 'viem/chains'
import { TOKEN_ERC2612_ABI, TOKEN_ERC2612_ADDRESSES } from '../smartcontract/addresses'

async function permitERC2612(amount: string) {
  if (!amount) {
    console.error('Usage: pnpm permit-erc2612 <amount>')
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

  const tokenErc2612Address = TOKEN_ERC2612_ADDRESSES[sepolia.id]

  // --- Fetch on-chain data in parallel ---
  const [tokenName, permitNonce, decimals] = await Promise.all([
    signerWalletClient.readContract({
      address: tokenErc2612Address,
      abi: TOKEN_ERC2612_ABI,
      functionName: 'name'
    }) as Promise<string>,
    signerWalletClient.readContract({
      address: tokenErc2612Address,
      abi: TOKEN_ERC2612_ABI,
      functionName: 'nonces',
      args: [SIGNER_ACCOUNT.address]
    }) as Promise<bigint>,
    signerWalletClient.readContract({
      address: tokenErc2612Address,
      abi: TOKEN_ERC2612_ABI,
      functionName: 'decimals'
    }) as Promise<number>
  ])
  const weiAmount = BigInt(amount) * BigInt(10 ** decimals)
  const deadline = BigInt(Math.floor(Date.now() / 1000) + 3600) // 1 hour from now
  const owner = SIGNER_ACCOUNT.address
  const spender = RELAYER_ACCOUNT.address


  // EIP712 smart contract domain separator
  const smartContractDomainSeparator = {
    name: tokenName,
    version: '1',
    chainId: sepolia.id,
    verifyingContract: tokenErc2612Address
  } as const

  // The name must exactly match the struct name defined in the ERC-2612 contract in the PERMIT_TYPEHASH
  const PERMIT_TYPE = "Permit"

  const permitTypes = {
    [PERMIT_TYPE]: [
      { name: 'owner', type: 'address' },
      { name: 'spender', type: 'address' },
      { name: 'value', type: 'uint256' },
      { name: 'nonce', type: 'uint256' },
      { name: 'deadline', type: 'uint256' }
    ]
  }

  const permitMessage = {
    owner,
    spender,
    value: weiAmount,
    nonce: permitNonce,
    deadline
  }

  // Sign the typed data (EIP-712) using the signer's wallet client
  const permitSignature = await signerWalletClient.signTypedData({
    domain: smartContractDomainSeparator,
    types: permitTypes,
    primaryType: PERMIT_TYPE,
    message: permitMessage
  })

  const permitTx = await relayerWalletClient.writeContract({
    address: tokenErc2612Address,
    abi: TOKEN_ERC2612_ABI,
    functionName: 'permit',
    args: [owner, spender, weiAmount, deadline, permitSignature]
  })

  await relayerWalletClient.waitForTransactionReceipt({ hash: permitTx })
  console.log('Permit transaction sent:', permitTx)
  console.log(`${SIGNER_ACCOUNT.address} approved ${weiAmount} tokens for ${RELAYER_ACCOUNT.address} with permit signature.`)
}

const args = process.argv.slice(2)
const amount = args[0]
permitERC2612(amount).catch((error) => {
  console.error('Error executing permit ERC2612:', error)
  process.exit(1)
})
