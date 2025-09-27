'use client'

import { MiniKit } from '@worldcoin/minikit-js'
import { useState } from 'react'

interface LendingInterfaceProps {
  walletAddress: string
}

export const LendingInterface = ({ walletAddress }: LendingInterfaceProps) => {
  const [mode, setMode] = useState<'deposit' | 'borrow' | 'repay'>('deposit')
  const [amount, setAmount] = useState('')
  const [token, setToken] = useState('USDC')
  const [isLoading, setIsLoading] = useState(false)

  const handleDeposit = async () => {
    if (!amount || parseFloat(amount) <= 0) {
      alert('Please enter a valid amount')
      return
    }

    setIsLoading(true)
    try {
      const { finalPayload } = await MiniKit.commandsAsync.sendTransaction({
        transaction: [{
          address: '0xYourAAVEPoolAddress', // Replace with your deployed contract
          abi: [
            {
              "inputs": [
                {"name": "token", "type": "address"},
                {"name": "amount", "type": "uint256"}
              ],
              "name": "deposit",
              "outputs": [],
              "stateMutability": "nonpayable",
              "type": "function"
            }
          ],
          functionName: 'deposit',
          args: [
            token === 'USDC' ? '0xUSDCAddress' : '0xWLDAddress', // Replace with actual token addresses
            (parseFloat(amount) * 1e6).toString() // Convert to 6 decimals
          ]
        }]
      })

      if (finalPayload.status === 'success') {
        alert('Deposit successful!')
        setAmount('')
      }
    } catch (error) {
      console.error('Deposit failed:', error)
      alert('Deposit failed. Please try again.')
    } finally {
      setIsLoading(false)
    }
  }

  const handleBorrow = async () => {
    if (!amount || parseFloat(amount) <= 0) {
      alert('Please enter a valid amount')
      return
    }

    setIsLoading(true)
    try {
      const { finalPayload } = await MiniKit.commandsAsync.sendTransaction({
        transaction: [{
          address: '0xYourAAVEPoolAddress', // Replace with your deployed contract
          abi: [
            {
              "inputs": [
                {"name": "token", "type": "address"},
                {"name": "amount", "type": "uint256"}
              ],
              "name": "borrow",
              "outputs": [],
              "stateMutability": "nonpayable",
              "type": "function"
            }
          ],
          functionName: 'borrow',
          args: [
            token === 'USDC' ? '0xUSDCAddress' : '0xWLDAddress',
            (parseFloat(amount) * 1e6).toString()
          ]
        }]
      })

      if (finalPayload.status === 'success') {
        alert('Borrow successful!')
        setAmount('')
      }
    } catch (error) {
      console.error('Borrow failed:', error)
      alert('Borrow failed. Please try again.')
    } finally {
      setIsLoading(false)
    }
  }

  const handleRepay = async () => {
    if (!amount || parseFloat(amount) <= 0) {
      alert('Please enter a valid amount')
      return
    }

    setIsLoading(true)
    try {
      const { finalPayload } = await MiniKit.commandsAsync.sendTransaction({
        transaction: [{
          address: '0xYourAAVEPoolAddress', // Replace with your deployed contract
          abi: [
            {
              "inputs": [
                {"name": "token", "type": "address"},
                {"name": "amount", "type": "uint256"}
              ],
              "name": "repay",
              "outputs": [],
              "stateMutability": "nonpayable",
              "type": "function"
            }
          ],
          functionName: 'repay',
          args: [
            token === 'USDC' ? '0xUSDCAddress' : '0xWLDAddress',
            (parseFloat(amount) * 1e6).toString()
          ]
        }]
      })

      if (finalPayload.status === 'success') {
        alert('Repay successful!')
        setAmount('')
      }
    } catch (error) {
      console.error('Repay failed:', error)
      alert('Repay failed. Please try again.')
    } finally {
      setIsLoading(false)
    }
  }

  const handleAction = () => {
    switch (mode) {
      case 'deposit':
        return handleDeposit()
      case 'borrow':
        return handleBorrow()
      case 'repay':
        return handleRepay()
    }
  }

  return (
    <div className="bg-white rounded-lg p-6 shadow-sm">
      <h2 className="text-lg font-semibold mb-4">AAVE Lending Pool</h2>
      
      {/* Tab Navigation */}
      <div className="flex mb-6 bg-gray-100 rounded-lg p-1">
        {(['deposit', 'borrow', 'repay'] as const).map((tab) => (
          <button
            key={tab}
            onClick={() => setMode(tab)}
            className={`flex-1 py-2 px-4 rounded-md text-sm font-medium capitalize transition-colors ${
              mode === tab
                ? 'bg-white text-blue-600 shadow-sm'
                : 'text-gray-600 hover:text-gray-900'
            }`}
          >
            {tab}
          </button>
        ))}
      </div>

      {/* Token Selection */}
      <div className="mb-4">
        <label className="block text-sm font-medium text-gray-700 mb-2">
          Token
        </label>
        <select
          value={token}
          onChange={(e) => setToken(e.target.value)}
          className="w-full p-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
        >
          <option value="USDC">USDC</option>
          <option value="WLD">WLD</option>
        </select>
      </div>

      {/* Amount Input */}
      <div className="mb-6">
        <label className="block text-sm font-medium text-gray-700 mb-2">
          Amount
        </label>
        <input
          type="number"
          value={amount}
          onChange={(e) => setAmount(e.target.value)}
          placeholder="0.00"
          className="w-full p-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
        />
      </div>

      {/* Action Button */}
      <button
        onClick={handleAction}
        disabled={isLoading || !amount}
        className={`w-full py-3 px-4 rounded-lg font-medium transition-colors disabled:opacity-50 ${
          mode === 'deposit'
            ? 'bg-green-600 hover:bg-green-700 text-white'
            : mode === 'borrow'
            ? 'bg-blue-600 hover:bg-blue-700 text-white'
            : 'bg-orange-600 hover:bg-orange-700 text-white'
        }`}
      >
        {isLoading ? 'Processing...' : `${mode.charAt(0).toUpperCase() + mode.slice(1)} ${token}`}
      </button>

      {/* User Info */}
      <div className="mt-4 pt-4 border-t border-gray-200">
        <p className="text-xs text-gray-500">
          Connected: {walletAddress.slice(0, 6)}...{walletAddress.slice(-4)}
        </p>
      </div>
    </div>
  )
}