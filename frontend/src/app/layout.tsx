import type { Metadata } from 'next'
import './globals.css'

export const metadata: Metadata = {
  title: 'URL Shortener',
  description: 'Simple and fast URL shortener with QR codes',
}

export default function RootLayout({
  children,
}: {
  children: React.ReactNode
}) {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  )
}
