import { clsx, type ClassValue } from "clsx"
import { twMerge } from "tailwind-merge"

export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs))
}

export function getImageUrl(path?: string | null) {
  if (!path) return undefined
  if (path.startsWith('http') || path.startsWith('https')) return path

  // Default API URL (should be environment variable in production)
  let API_BASE_URL = process.env.NEXT_PUBLIC_API_URL || "https://web-production-06662.up.railway.app"

  // Remove trailing slash from API_BASE_URL if present
  if (API_BASE_URL.endsWith('/')) {
    API_BASE_URL = API_BASE_URL.slice(0, -1)
  }

  // Images are served from the host root, not under /api/v1. Strip it so a
  // NEXT_PUBLIC_API_URL like "https://host/api/v1" still resolves uploads.
  API_BASE_URL = API_BASE_URL.replace(/\/api\/v1$/, '')

  // Ensure path starts with / if not present
  const cleanPath = path.startsWith('/') ? path : `/${path}`

  return `${API_BASE_URL}${cleanPath}`
}
