// 'use client'

// import { useState, useEffect } from 'react'
// import { MiniKit } from '@worldcoin/minikit-js'
// import { WalletAuth } from '@/components/WalletAuth'
// import { WorldIDVerify } from '@/components/WorldIDVerify'
// import { LendingInterface } from '@/components/LendingInterface'

// declare global {
//   interface Window {
//     MiniKit: any; // Replace 'any' with the actual type if available
//   }
// }
// export default function Home() {
//   const [walletAddress, setWalletAddress] = useState<string>('')
//   const [isVerified, setIsVerified] = useState(false)

//   useEffect(() => {
//     // Check if wallet is already connected
//     if (MiniKit.walletAddress) {
//       setWalletAddress(MiniKit.walletAddress)
//     }
//   }, [])

//   return (
//     <main className="min-h-screen bg-gray-50 p-4">
//       <div className="max-w-md mx-auto space-y-6">
//         <div className="text-center">
//           <h1 className="text-2xl font-bold text-gray-900">AAVE Mini</h1>
//           <p className="text-gray-600">Decentralized Lending Protocol</p>
//         </div>

//         {!walletAddress ? (
//           <WalletAuth onSuccess={setWalletAddress} />
//         ) : !isVerified ? (
//           <WorldIDVerify 
//             userAddress={walletAddress} 
//             onVerified={() => setIsVerified(true)} 
//           />
//         ) : (
//           <LendingInterface walletAddress={walletAddress} />
//         )}
//       </div>
//     </main>
//   )
// }

// export const WorldIDVerify = ({
//   userAddress,
//   onVerified,
// }: {
//   userAddress: string;
//   onVerified: () => void;
// }) => {
//   // ...component code...
// }


import { MiniKit, VerifyCommandInput, VerificationLevel, ISuccessResult } from '@worldcoin/minikit-js'

const verifyPayload: VerifyCommandInput = {
	action: 'voting-action', // This is your action ID from the Developer Portal
	signal: '0x12312', // Optional additional data
	verification_level: VerificationLevel.Orb, // Orb | Device
}

const handleVerify = async () => {
	if (!MiniKit.isInstalled()) {
		return
	}
	// World App will open a drawer prompting the user to confirm the operation, promise is resolved once user confirms or cancels
	const {finalPayload} = await MiniKit.commandsAsync.verify(verifyPayload)
		if (finalPayload.status === 'error') {
			return console.log('Error payload', finalPayload)
		}

		// Verify the proof in the backend
		const verifyResponse = await fetch('/api/verify', {
			method: 'POST',
			headers: {
				'Content-Type': 'application/json',
			},
			body: JSON.stringify({
			payload: finalPayload as ISuccessResult, // Parses only the fields we need to verify
			action: 'voting-action',
			signal: '0x12312', // Optional
		}),
	})

	// TODO: Handle Success!
	const verifyResponseJson = await verifyResponse.json()
	if (verifyResponseJson.status === 200) {
		console.log('Verification success!')
	}
}