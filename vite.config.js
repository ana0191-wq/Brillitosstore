import { defineConfig, loadEnv } from 'vite'

export default defineConfig(({ mode }) => {
  const env = loadEnv(mode, process.cwd(), '')
  const supabaseUrl = env.VITE_SUPABASE_URL || 'https://jzhayqzmrpfesmhdxyaf.supabase.co'

  return {
    server: {
      proxy: {
        '/rest/v1': {
          target: supabaseUrl,
          changeOrigin: true,
          secure: true,
        },
        '/storage/v1': {
          target: supabaseUrl,
          changeOrigin: true,
          secure: true,
        },
        '/auth/v1': {
          target: supabaseUrl,
          changeOrigin: true,
          secure: true,
        }
      }
    }
  }
})
