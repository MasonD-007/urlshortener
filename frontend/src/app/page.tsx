'use client'

import { useState } from 'react'
import URLShortenerForm from '@/components/URLShortenerForm'
import ResultDisplay from '@/components/ResultDisplay'

export default function Home() {
  const [result, setResult] = useState<{
    hash: string
    short_url: string
    qr_code_url: string
    original_url: string
  } | null>(null)

  return (
    <main className="min-h-screen bg-gradient-to-br from-indigo-500 via-purple-500 to-pink-500">
      <div className="container mx-auto px-4 py-16">
        <div className="max-w-2xl mx-auto">
          {/* Header */}
          <div className="text-center mb-12">
            <h1 className="text-5xl font-bold text-white mb-4">
              URL Shortener
            </h1>
            <p className="text-xl text-white/90">
              Create short URLs with QR codes instantly
            </p>
          </div>

          {/* Main Card */}
          <div className="bg-white rounded-3xl shadow-2xl p-8 md:p-12">
            <URLShortenerForm onResult={setResult} />
            
            {result && (
              <div className="mt-8">
                <ResultDisplay result={result} />
              </div>
            )}
          </div>

          {/* Footer */}
          <div className="text-center mt-8 text-white/80">
            <p className="text-sm">
              Built with OpenFaaS, DynamoDB, and Next.js
            </p>
          </div>
        </div>
      </div>
    </main>
  )
}
