'use client'

import { useState, useEffect } from 'react'

interface ResultDisplayProps {
    result: {
        hash: string
        short_url: string
        original_url: string
    }
}

export default function ResultDisplay({ result }: ResultDisplayProps) {
    const [copied, setCopied] = useState(false)
    const [qrCodeImage, setQrCodeImage] = useState<string | null>(null)
    const [qrLoading, setQrLoading] = useState(false)
    const [qrError, setQrError] = useState<string | null>(null)

    useEffect(() => {
        // Fetch QR code when result changes
        const fetchQRCode = async () => {
            setQrLoading(true)
            setQrError(null)
            try {
                const apiGateway = process.env.NEXT_PUBLIC_API_GATEWAY || 'http://10.0.1.2:8080'
                const qrcodeFunction = `${apiGateway}/function/qrcode-wrapper`
                const response = await fetch(qrcodeFunction, {
                    method: 'POST',
                    body: result.short_url,
                    headers: {
                        'Content-Type': 'text/plain',
                    },
                })

                if (response.ok) {
                    const blob = await response.blob()
                    const imageUrl = URL.createObjectURL(blob)
                    setQrCodeImage(imageUrl)
                    setQrError(null)
                } else {
                    const errorText = await response.text()
                    const errorMessage = `QR code generation failed (${response.status}): ${errorText}`
                    console.error(errorMessage)
                    setQrError(errorMessage)
                }
            } catch (error) {
                console.error('Failed to fetch QR code:', error)

                // Check for CORS error
                if (error instanceof TypeError && error.message.includes('Failed to fetch')) {
                    setQrError('Unable to generate QR code: CORS policy blocked the request. Please check server configuration.')
                } else {
                    setQrError(`Failed to generate QR code: ${error instanceof Error ? error.message : 'Unknown error'}`)
                }
            } finally {
                setQrLoading(false)
            }
        }

        fetchQRCode()

        // Cleanup blob URL on unmount
        return () => {
            if (qrCodeImage) {
                URL.revokeObjectURL(qrCodeImage)
            }
        }
    }, [result.short_url])

    const copyToClipboard = async () => {
        try {
            await navigator.clipboard.writeText(result.short_url)
            setCopied(true)
            setTimeout(() => setCopied(false), 2000)
        } catch (err) {
            console.error('Failed to copy:', err)
        }
    }

    const downloadQRCode = () => {
        if (!qrCodeImage) return

        const link = document.createElement('a')
        link.href = qrCodeImage
        link.download = `qr-${result.hash}.png`
        document.body.appendChild(link)
        link.click()
        document.body.removeChild(link)
    }

    return (
        <div className="border-t-2 border-gray-100 pt-8">
            <div className="text-center mb-6">
                <div className="inline-flex items-center justify-center w-12 h-12 bg-green-100 rounded-full mb-4">
                    <svg className="w-6 h-6 text-green-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M5 13l4 4L19 7" />
                    </svg>
                </div>
                <h2 className="text-2xl font-bold text-gray-800 mb-2">Success!</h2>
                <p className="text-gray-600">Your short URL is ready</p>
            </div>

            {/* Short URL Display */}
            <div className="bg-gray-50 rounded-lg p-4 mb-6">
                <label className="block text-sm font-medium text-gray-700 mb-2">
                    Short URL
                </label>
                <div className="flex items-center gap-2">
                    <input
                        type="text"
                        value={result.short_url}
                        readOnly
                        className="flex-1 px-4 py-2 bg-white border border-gray-300 rounded-lg text-gray-900 font-mono text-sm"
                    />
                    <button
                        onClick={copyToClipboard}
                        className="px-4 py-2 bg-indigo-600 text-white rounded-lg hover:bg-indigo-700 transition-colors whitespace-nowrap"
                    >
                        {copied ? (
                            <span className="flex items-center gap-1">
                                <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M5 13l4 4L19 7" />
                                </svg>
                                Copied!
                            </span>
                        ) : (
                            'Copy'
                        )}
                    </button>
                </div>
            </div>

            {/* Original URL */}
            <div className="bg-gray-50 rounded-lg p-4 mb-6">
                <label className="block text-sm font-medium text-gray-700 mb-2">
                    Original URL
                </label>
                <p className="text-gray-600 text-sm break-all">{result.original_url}</p>
            </div>

            {/* QR Code */}
            <div className="bg-gray-50 rounded-lg p-6 text-center">
                <label className="block text-sm font-medium text-gray-700 mb-4">
                    QR Code
                </label>
                {qrLoading ? (
                    <div className="flex items-center justify-center h-64">
                        <svg className="animate-spin h-8 w-8 text-indigo-600" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
                            <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4"></circle>
                            <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
                        </svg>
                    </div>
                ) : qrCodeImage ? (
                    <>
                        <img
                            src={qrCodeImage}
                            alt="QR Code"
                            className="w-64 h-64 mx-auto mb-4 border-4 border-white rounded-lg shadow-md"
                        />
                        <button
                            onClick={downloadQRCode}
                            className="px-6 py-2 bg-purple-600 text-white rounded-lg hover:bg-purple-700 transition-colors"
                        >
                            Download QR Code
                        </button>
                    </>
                ) : qrError ? (
                    <div className="flex flex-col items-center justify-center h-64 px-4">
                        <svg className="w-12 h-12 text-red-500 mb-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
                        </svg>
                        <p className="text-red-600 text-sm font-medium mb-2">QR Code Generation Failed</p>
                        <p className="text-gray-600 text-xs break-words max-w-md">{qrError}</p>
                    </div>
                ) : (
                    <div className="flex items-center justify-center h-64">
                        <p className="text-gray-500">Failed to load QR code</p>
                    </div>
                )}
            </div>
        </div>
    )
}
