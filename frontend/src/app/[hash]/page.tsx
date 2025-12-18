'use client'

import { useEffect, useState } from 'react'
import { useParams } from 'next/navigation'
import Link from 'next/link'

interface RedirectData {
    hash: string
    original_url: string
    statusCode: number
    error?: string
}

export default function HashPage() {
    const params = useParams()
    const hash = params.hash as string
    const [data, setData] = useState<RedirectData | null>(null)
    const [loading, setLoading] = useState(true)

    useEffect(() => {
        const fetchRedirectUrl = async () => {
            try {
                const apiGateway = process.env.NEXT_PUBLIC_API_GATEWAY || 'https://faas.masondrake.dev'
                const response = await fetch(`${apiGateway}/function/redirect-url`, {
                    method: 'POST',
                    body: hash,
                    redirect: 'manual' // Don't follow redirects automatically
                })

                console.log('Response status:', response.status)
                console.log('Response:', response)

                // OpenFaaS returns actual HTTP redirects (301/302), not JSON
                if (response.status === 301 || response.status === 0) {
                    // Status 0 means opaque redirect (CORS preflight blocked the redirect)
                    // Get the Location header from the response
                    const originalUrl = response.headers.get('Location')

                    if (originalUrl) {
                        setData({
                            hash,
                            original_url: originalUrl,
                            statusCode: response.status || 301
                        })
                    }
                }

                // Handle error responses (404, 500, etc.)
                if (response.status === 404) {
                    setData({
                        hash,
                        original_url: '',
                        statusCode: 404,
                        error: 'URL not found'
                    })
                } else if (!response.ok) {
                    let errorMessage = 'Unknown error'
                    try {
                        const result = await response.json()
                        errorMessage = result.error || result.body?.error || errorMessage
                    } catch {
                        errorMessage = `HTTP ${response.status}: ${response.statusText}`
                    }

                    setData({
                        hash,
                        original_url: '',
                        statusCode: response.status,
                        error: errorMessage
                    })
                }
            } catch (error) {
                setData({
                    hash,
                    original_url: '',
                    statusCode: 500,
                    error: error instanceof Error ? error.message : 'Unknown error'
                })
            } finally {
                setLoading(false)
            }
        }

        fetchRedirectUrl()
    }, [hash])

    if (loading) {
        return (
            <main className="min-h-screen bg-gradient-to-br from-indigo-500 via-purple-500 to-pink-500 flex items-center justify-center">
                <div className="bg-white rounded-3xl shadow-2xl p-12 max-w-2xl w-full mx-4">
                    <div className="text-center">
                        <div className="animate-spin rounded-full h-16 w-16 border-b-4 border-indigo-600 mx-auto mb-6"></div>
                        <h2 className="text-2xl font-bold text-gray-800 mb-2">Loading...</h2>
                        <p className="text-gray-600">Fetching redirect URL</p>
                    </div>
                </div>
            </main>
        )
    }

    if (data?.error) {
        return (
            <main className="min-h-screen bg-gradient-to-br from-red-500 via-pink-500 to-purple-500 flex items-center justify-center">
                <div className="bg-white rounded-3xl shadow-2xl p-12 max-w-2xl w-full mx-4">
                    <div className="text-center">
                        <div className="text-6xl mb-6">❌</div>
                        <h1 className="text-4xl font-bold text-gray-800 mb-4">URL Not Found</h1>
                        <p className="text-xl text-gray-600 mb-2">Hash: <code className="bg-gray-100 px-3 py-1 rounded">{hash}</code></p>
                        <p className="text-gray-500 mb-8">{data.error}</p>
                        <Link
                            href="/"
                            className="inline-block bg-gradient-to-r from-indigo-600 to-purple-600 text-white font-semibold px-8 py-3 rounded-full hover:from-indigo-700 hover:to-purple-700 transition-all"
                        >
                            Create a Short URL
                        </Link>
                    </div>
                </div>
            </main>
        )
    }

    return (
        <main className="min-h-screen bg-gradient-to-br from-indigo-500 via-purple-500 to-pink-500 flex items-center justify-center">
            <div className="bg-white rounded-3xl shadow-2xl p-12 max-w-2xl w-full mx-4">
                <div className="text-center">
                    {/* Success Icon */}
                    <div className="text-6xl mb-6">🔗</div>

                    {/* Title */}
                    <h1 className="text-4xl font-bold text-gray-800 mb-4">
                        Short URL Found!
                    </h1>

                    {/* Hash Display */}
                    <div className="mb-6">
                        <p className="text-sm text-gray-500 mb-1">Short Code</p>
                        <code className="text-2xl font-mono bg-gradient-to-r from-indigo-100 to-purple-100 px-6 py-3 rounded-xl inline-block">
                            {hash}
                        </code>
                    </div>

                    {/* Original URL */}
                    <div className="mb-8">
                        <p className="text-sm text-gray-500 mb-2">This short URL points to:</p>
                        <div className="bg-gray-50 rounded-xl p-4 break-all">
                            <a
                                href={data?.original_url}
                                className="text-indigo-600 hover:text-indigo-800 font-medium"
                                target="_blank"
                                rel="noopener noreferrer"
                            >
                                {data?.original_url}
                            </a>
                        </div>
                    </div>

                    {/* Info Message */}
                    <div className="mb-8">
                        <p className="text-gray-600">
                            Click the button below to visit this URL
                        </p>
                    </div>

                    {/* Action Buttons */}
                    <div className="flex gap-4 justify-center flex-wrap">
                        <a
                            href={data?.original_url}
                            className="bg-gradient-to-r from-indigo-600 to-purple-600 text-white font-semibold px-8 py-3 rounded-full hover:from-indigo-700 hover:to-purple-700 transition-all shadow-lg"
                            target="_blank"
                            rel="noopener noreferrer"
                        >
                            Visit URL →
                        </a>
                        <Link
                            href="/"
                            className="bg-white text-gray-700 font-semibold px-8 py-3 rounded-full border-2 border-gray-300 hover:border-indigo-600 hover:text-indigo-600 transition-all"
                        >
                            Create New URL
                        </Link>
                    </div>
                </div>
            </div>
        </main>
    )
}
