/// <reference types="vite/client" />

interface ImportMetaEnv {
  readonly VITE_API_URL: string
  readonly VITE_SOCKET_URL: string
  readonly VITE_APP_ENV: string
  readonly VITE_USE_MOCK: string
  readonly VITE_REVERB_URL: string
  readonly VITE_REVERB_APP_KEY: string
  readonly VITE_REVERB_AUTH_ENDPOINT: string
}

interface ImportMeta {
  readonly env: ImportMetaEnv
}
