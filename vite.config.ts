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
    // `strictPort` لأجل تطبيق سطح المكتب: نافذة Tauri تُوجَّه إلى 5173 نصّاً
    // في `tauri.conf.json`. فلو انزلق Vite إلى 5174 لأن المنفذ مشغول، فتحت
    // النافذة على لا شيء — والفشل الصريح خيرٌ من نافذةٍ بيضاء بلا سبب.
    strictPort: true,
    host: true,
  },
  // Rust يراقب `src-tauri` بنفسه، ومراقبةُ Vite لها تُعيد بناء الواجهة عند
  // كل تعديلٍ في الشيفرة الأصلية بلا فائدة.
  envPrefix: ['VITE_', 'TAURI_'],
  build: {
    // WebView2 في ويندوز وWebKit في ماك يفهمان ما تفهمه المتصفّحات الحديثة،
    // فلا داعي لخفض الهدف — لكن نتركه صريحاً حتى لا يتغيّر ضمناً مع Vite.
    target: 'es2022',
  },
})
