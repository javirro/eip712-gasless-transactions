import dotenv from 'dotenv'
import { privateKeyToAccount } from 'viem/accounts'


dotenv.config()

const RELAYER_PRIVATE_KEY = process.env.RELAYER_PRIVATE_KEY
const SIGNER_PRIVATE_KEY = process.env.SIGNER_PRIVATE_KEY

const formatPk = (pk: string | undefined) => {
  if (!pk) throw new Error('Private key is not defined in environment variables')
  return pk.startsWith('0x') ? (pk as `0x${string}`) : (`0x${pk}` as `0x${string}`)
}

export const RELAYER_ACCOUNT = privateKeyToAccount(formatPk(RELAYER_PRIVATE_KEY))
export const SIGNER_ACCOUNT = privateKeyToAccount(formatPk(SIGNER_PRIVATE_KEY))
