import { MiniKit, WalletAuthInput } from '@worldcoin/minikit-js'
import { useState } from 'react'

declare global {
  interface Window {
    MiniKit: any; // Replace 'any' with the actual type if available
  }
}
export const WalletAuth = ({ onSuccess }: { onSuccess: (address: string) => void }) => {
  const [isLoading, setIsLoading] = useState(false)

  const signInWithWallet = async () => {
    if (!MiniKit.isInstalled()) return
    
    setIsLoading(true)
    
    try {
      // Get nonce from backend
      const res = await fetch('/api/nonce')
      const { nonce } = await res.json()

      // Authenticate wallet
      const { finalPayload } = await MiniKit.commandsAsync.walletAuth({
        nonce: nonce,
        expirationTime: new Date(new Date().getTime() + 7 * 24 * 60 * 60 * 1000),
        statement: 'Sign in to AAVE Mini App',
      })

      if (finalPayload.status === 'success') {
        // Verify on backend
        const response = await fetch('/api/complete-siwe', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ payload: finalPayload, nonce }),
        })

        if (response.ok) {
          // Get wallet address from MiniKit
          const walletAddress = window.MiniKit?.walletAdress
          onSuccess(walletAddress!)
        }
      }
    } catch (error) {
      console.error('Wallet auth failed:', error)
    } finally {
      setIsLoading(false)
    }
  }

  return (
    <button onClick={signInWithWallet} disabled={isLoading}>
      {isLoading ? 'Connecting...' : 'Connect Wallet'}
    </button>
  )
}