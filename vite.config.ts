import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'
import tailwindcss from '@tailwindcss/vite'
import { fileURLToPath, URL } from 'node:url'

export default defineConfig({
  // GitHub Pages يخدم مشاريع المستودعات تحت /<repo>/ لا تحت الجذر، فبناء
  // النشر يحتاج البادئة وإلا طلبت الصفحة أصولها من مسار غير موجود وظهرت بيضاء.
  // التطوير المحلي يبقى على الجذر.
  base: process.env.VITE_BASE ?? '/',
  plugins: [react(), tailwindcss()],
  resolve: {
    alias: {
      '@': fileURLToPath(new URL('./src', import.meta.url)),
    },
  },
  server: {
    port: 5173,
    host: true,
  },
})
