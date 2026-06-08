import { defineConfig, loadEnv } from 'vite'
import { resolve } from 'path'

export default defineConfig(({ mode }) => {
  const env = loadEnv(mode, process.cwd(), '')
  const supabaseUrl = env.VITE_SUPABASE_URL || 'https://jzhayqzmrpfesmhdxyaf.supabase.co'

  return {
    build: {
      rollupOptions: {
        input: {
          main: resolve(__dirname, 'index.html'),
          admin: resolve(__dirname, 'admin.html'),
          pos: resolve(__dirname, 'pos.html'),
          pos2: resolve(__dirname, 'pos2.html'),
          pedidos: resolve(__dirname, 'pedidos.html'),
          qrEtiquetas: resolve(__dirname, 'qr-etiquetas.html'),
        }
      }
    },
    server: {
      proxy: {
        '/rest/v1': { target: supabaseUrl, changeOrigin: true, secure: true },
        '/storage/v1': { target: supabaseUrl, changeOrigin: true, secure: true },
        '/auth/v1': { target: supabaseUrl, changeOrigin: true, secure: true },
      }
    }
  }
})
