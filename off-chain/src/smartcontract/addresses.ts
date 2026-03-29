import { Abi, parseAbi } from 'viem'
import metaRelayerAbi from './MetaTransactionPermitAbi.json'
import tokenErc2612Abi from './tokenERC2612.json'
import exampleSmartContractAbi from './exampleSmartContractAbi.json'
import metaTransactionsAbi from './metaTransactionsAbi.json'

// Addresses for MetaTransactionsWithPermit (two signatures combinated)
export const META_RELAYER_PERMIT: Record<string, `0x${string}`> = {
  '137': '0x89ab00cC30Ecf8Ac342455326B4Fb1b9E8AEfa7C'
}
export const USDC_ADDRESS: Record<string, `0x${string}`> = {
  '137': '0x3c499c542cEF5E3811e1192ce70d8cC03d5c3359'
}

// Addresses for MetaTransactions (single signature)
export const META_TRANSACTIONS_ADDRESS: Record<string, `0x${string}`> = {
  '11155111': '0xf1e76EdcFC8356EAAE03AE8937c43D8A451E0AfE'
}

export const EXAMPLE_SMART_CONTRACT_ADDRESS: Record<string, `0x${string}`> = {
  '11155111': '0x7E1dbe90f2109b9FBF7FD373B4dAcF51E829f312'
}

// Minimal ERC-2612 token address to use Permit functionality
export const TOKEN_ERC2612_ADDRESSES: Record<string, `0x${string}`> = {
  '11155111': '0x254301274dc1a7ED0DF68D45Ff3c39D01AA16082'
}

export const META_RELAYER_ABI = metaRelayerAbi as Abi
// Minimal ABI for ERC-2612 permit nonces and token name/version
export const ERC20_PERMIT_ABI = parseAbi([
  'function name() view returns (string)',
  'function version() view returns (string)',
  'function nonces(address owner) view returns (uint256)',
  'function decimals() view returns (uint8)'
]) as Abi

// Token ERC-2612 ABI (for permit and transferWithPermit)
export const TOKEN_ERC2612_ABI = tokenErc2612Abi as Abi


// Example smart contract ABI with a function to call via meta-transaction
export const EXAMPLE_SMART_CONTRACT_ABI = exampleSmartContractAbi as Abi

export const META_TRANSACTIONS_ABI = metaTransactionsAbi as Abi


