'use client'

import { MiniKit, VerifyCommandInput, VerificationLevel } from '@worldcoin/minikit-js'
import { useState } from 'react'

interface WorldIDVerifyProps {
  walletAddress: string
  onVerified: () => void
}

export const WorldIDVerify = ({ walletAddress, onVerified }: WorldIDVerifyProps) => {
  const [isVerifying, setIsVerifying] = useState(false)

  const verifyUser = async () => {
    if (!walletAddress) {
      alert('Wallet address not available')
      return
    }

    setIsVerifying(true)

    try {
      const verifyPayload: VerifyCommandInput = {
        action: 'aave-lending', // Create this action in Developer Portal
        signal: walletAddress,
        verification_level: VerificationLevel.Orb
      }

      const { finalPayload } = await MiniKit.commandsAsync.verify(verifyPayload)
      
      if (finalPayload.status === 'success') {
        // Verify proof on backend
        const response = await fetch('/api/verify', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            payload: finalPayload,
            action: 'aave-lending',
            signal: walletAddress
          })
        })

        if (response.ok) {
          onVerified()
          alert('World ID verified! You can now use lending features.')
        } else {
          alert('Verification failed. Please try again.')
        }
      }
    } catch (error) {
      console.error('World ID verification failed:', error)
      alert('Verification failed. Please try again.')
    } finally {
      setIsVerifying(false)
    }
  }

  return (
    <div className="bg-white rounded-lg p-6 shadow-sm">
      <h2 className="text-lg font-semibold mb-4">Verify Identity</h2>
      <p className="text-gray-600 mb-4">
        Verify your World ID to prevent sybil attacks and ensure fair lending
      </p>
      <p className="text-sm text-gray-500 mb-4">
        Wallet: {walletAddress.slice(0, 6)}...{walletAddress.slice(-4)}
      </p>
      <button 
        onClick={verifyUser} 
        disabled={isVerifying}
        className="w-full bg-green-600 text-white py-3 px-4 rounded-lg font-medium hover:bg-green-700 disabled:opacity-50"
      >
        {isVerifying ? 'Verifying...' : 'Verify with World ID'}
      </button>
    </div>
  )
}