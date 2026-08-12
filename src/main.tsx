import { StrictMode } from 'react'
import { createRoot } from 'react-dom/client'
import { HashRouter } from 'react-router-dom'
import { App } from './App'
import { AuthProvider } from './context/AuthContext'
import { ThemeProvider } from './context/ThemeContext'
import './index.css'

/**
 * HashRouter لا BrowserRouter.
 *
 * اللوحة تُنشر على استضافة ملفات ثابتة (GitHub Pages)، وهي لا تعرف أن
 * ‎/bookings/123‎ مسار داخلي في التطبيق فتردّ 404. المسار خلف ‎#‎ لا يصل
 * الخادم أصلاً، فيعمل الموجّه بلا أي إعداد على الخادم ومهما كانت البادئة
 * التي يُخدَم منها الموقع.
 */
const container = document.getElementById('root')
if (!container) throw new Error('عنصر #root غير موجود في الصفحة.')

createRoot(container).render(
  <StrictMode>
    <ThemeProvider>
      <AuthProvider>
        <HashRouter>
          <App />
        </HashRouter>
      </AuthProvider>
    </ThemeProvider>
  </StrictMode>,
)
