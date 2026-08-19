import { StrictMode } from 'react'
import { createRoot } from 'react-dom/client'
import { HashRouter } from 'react-router-dom'
import { App } from './App'
import { AuthProvider } from './context/AuthContext'
import { ThemeProvider } from './context/ThemeContext'
import { revealWindow } from './lib/desktop'

/**
 * الخطّ مُستضافٌ معنا لا مُحمَّلٌ من شبكة غوغل.
 *
 * وذلك لثلاثة: لا طلبَ إلى نطاقٍ ثالث قد يُحجب أو يبطؤ، ولا تسريبَ لعناوين
 * زوّار اللوحة إليه، ولا انكسارَ للخطّ يوم تتغيّر تلك الشبكة. والحزمة تدخل
 * بنية الموقع فتُخزَّن مع بقيّة ملفاته.
 *
 * والمجموعتان الفرعيتان وحدهما (`arabic` و`latin`) لا الملف الجامع: هذا
 * يستدعي المجموعات كلّها — كيريلية ويونانية وفيتنامية — ولا سطرَ في اللوحة
 * يحتاجها.
 *
 * وثلاثة أوزان تكفي الواجهة: نصٌّ عادي، ووسْطٌ للعناوين الصغيرة والتسميات،
 * وشبهُ عريضٍ للأرقام الكبيرة. وكلُّ وزنٍ زائد ملفٌّ يُنزَّل ولا يُستعمل.
 */
import '@fontsource/ibm-plex-sans-arabic/arabic-400.css'
import '@fontsource/ibm-plex-sans-arabic/arabic-500.css'
import '@fontsource/ibm-plex-sans-arabic/arabic-600.css'
import '@fontsource/ibm-plex-sans-arabic/latin-400.css'
import '@fontsource/ibm-plex-sans-arabic/latin-500.css'
import '@fontsource/ibm-plex-sans-arabic/latin-600.css'

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

/**
 * على سطح المكتب تبدأ النافذة مخفيّة وتُظهر نفسها هنا.
 *
 * وإلا رأى المستخدم إطاراً أبيض فارغاً قبل أن يُرسم شيء — وهو أوّل ما يراه
 * من البرنامج في كل تشغيل. و`requestAnimationFrame` بعد `render` لأن هذا
 * الأخير يجدول العمل ولا ينتظره: النداء المباشر يُظهر النافذة قبل الرسم
 * فيعود البياض الذي أردنا إخفاءه.
 *
 * ولا أثر لهذا في المتصفّح: `revealWindow` تعود فوراً خارج Tauri.
 */
requestAnimationFrame(() => {
  void revealWindow()
})
