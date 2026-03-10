import { defineConfig } from 'vite'
import devServer from '@hono/vite-dev-server'
import react from '@vitejs/plugin-react'

export default defineConfig({
  plugins: [
    react(),
    devServer({
      entry: 'server.ts',
      exclude: [/^\/(?!api).*/],
    }),
  ],
})
