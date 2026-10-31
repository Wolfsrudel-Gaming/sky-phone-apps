import { resolve } from 'node:path'
import vue from '@vitejs/plugin-vue'
import { defineConfig } from 'vite'

// Builds straight into the FiveM resource. Assets use relative paths because the
// pages are served from https://cfx-nui-<resource>/web/.
export default defineConfig({
  base: './',
  plugins: [vue()],
  resolve: {
    alias: { '@': resolve(__dirname, 'src') },
  },
  build: {
    // FiveM's embedded browser (CEF) is Chromium 103 based.
    target: 'chrome103',
    outDir: resolve(__dirname, '../../shadow/web'),
    emptyOutDir: true,
    assetsDir: 'assets',
    rollupOptions: {
      input: {
        app: resolve(__dirname, 'app.html'),
      },
    },
  },
  server: {
    port: 5181,
    open: '/app.html',
  },
})
