import { Abi, parseAbi } from 'viem'
import metaRelayerAbi from './MetaTransactionAbi.json'
import tokenErc2612Abi from './tokenERC2612.json'

export const ADDRESSES: Record<string, `0x${string}`> = {
  '137': '0x89ab00cC30Ecf8Ac342455326B4Fb1b9E8AEfa7C'
}
export const USDC_ADDRESS: Record<string, `0x${string}`> = {
  '137': '0x3c499c542cEF5E3811e1192ce70d8cC03d5c3359'
}

export const TOKEN_ERC2612_ADDRESSES: Record<string, `0x${string}`> = {
  '11155111': '0x254301274dc1a7ED0DF68D45Ff3c39D01AA16082'
}

export const META_RELAYER_ABI = metaRelayerAbi as Abi

export const TOKEN_ERC2612_ABI =  tokenErc2612Abi as Abi

// Minimal ABI for ERC-2612 permit nonces and token name/version
export const ERC20_PERMIT_ABI = parseAbi([
  'function name() view returns (string)',
  'function version() view returns (string)',
  'function nonces(address owner) view returns (uint256)',
  'function decimals() view returns (uint8)'
])

