/**
 * علامة «سد للبرمجيات».
 *
 * مرسومةٌ شيفرةً لا صورةً، لثلاثة أسباب: تتبع الثيم فلا تحتاج نسخةً فاتحةً
 * وأخرى داكنة، وتبقى حادّةً في كل مقاسٍ وكثافة، ووزنها أقلّ من كيلوبايت فلا
 * يومض رأسُ اللوحة في انتظار تحميلها.
 *
 * ولاستبدالها بملفّ العلامة الأصلي: ضع الصورة في `public/brand/logo.png`،
 * ثم مرّر `src` إلى `BrandMark` — والباقي يعمل كما هو.
 */

/** الحلقة والحرف. الحلقة تدور دورةً بطيئةً واحدة عند الظهور ثم تهدأ. */
export function BrandMark({
  size = 40,
  spin = false,
  src,
}: {
  size?: number
  /** دورانٌ دائم — لصفحة الدخول وحدها، حيث لا شيء ينافسها على الانتباه. */
  spin?: boolean
  /** مسار صورة العلامة الأصلية، إن وُضعت في `public/`. */
  src?: string
}) {
  if (src) {
    return (
      <img
        src={src}
        alt=""
        aria-hidden
        width={size}
        height={size}
        className="shrink-0 rounded-xl object-cover"
      />
    )
  }

  return (
    <svg
      viewBox="0 0 64 64"
      width={size}
      height={size}
      aria-hidden
      className="shrink-0"
      style={{ display: 'block' }}
    >
      <defs>
        <linearGradient id="sddBlue" x1="0" y1="0" x2="1" y2="1">
          <stop offset="0" stopColor="#7fc4ff" />
          <stop offset="0.5" stopColor="#2f80ff" />
          <stop offset="1" stopColor="#1436a8" />
        </linearGradient>
      </defs>

      {/* دائرةٌ لا مربّع: العلامة الأصلية قرصٌ، والقرص هو ما يعرفه الناس منها.
          وأيقونة التبويب وحدها مربّعة — المتصفّح يعطيها 16 بكسلاً فلا تُهدر
          زواياها على فراغ. */}
      <circle cx="32" cy="32" r="31.2" fill="#070c16" />

      {/* حلقةٌ تقنيةٌ مقطّعة — قوسان لا دائرةٌ تامّة، كما في العلامة */}
      <g
        className={spin ? 'brand-ring' : undefined}
        style={{ transformOrigin: '32px 32px' }}
      >
        <circle
          cx="32"
          cy="32"
          r="27"
          fill="none"
          stroke="#1d4ed8"
          strokeOpacity="0.45"
          strokeWidth="1.6"
          strokeDasharray="34 12 18 10"
          strokeLinecap="round"
        />
        <circle
          cx="32"
          cy="32"
          r="23"
          fill="none"
          stroke="#60a5fa"
          strokeOpacity="0.3"
          strokeWidth="1"
          strokeDasharray="8 14"
        />
      </g>

      {/* حرف S زاويٌّ لا منحنٍ */}
      <polyline
        points="45,17 20,17 20,30 44,30 44,47 19,47"
        fill="none"
        stroke="url(#sddBlue)"
        strokeWidth="7.5"
        strokeLinecap="square"
      />
    </svg>
  )
}

/**
 * العلامة كاملةً: الحرف والاسمان.
 *
 * والاسم العربي أوّلاً لا الإنجليزي: اللوحة عربيةٌ وقارئها عربي، والسطر
 * اللاتيني توقيعٌ تحته لا عنوان.
 */
export function BrandLockup({
  size = 40,
  spin = false,
  tone = 'auto',
  subtitle = 'منصة حجوزات الأعراس',
}: {
  size?: number
  spin?: boolean
  /** `invert` لأرضيةٍ داكنة دائماً — كلوح صفحة الدخول. */
  tone?: 'auto' | 'invert'
  subtitle?: string
}) {
  const strong = tone === 'invert' ? 'text-white' : 'text-ink'
  const weak = tone === 'invert' ? 'text-white/60' : 'text-muted'

  return (
    <span className="flex items-center gap-2.5">
      <BrandMark size={size} spin={spin} />
      <span className="leading-tight">
        <span className={`block text-sm font-semibold ${strong}`}>سد للبرمجيات</span>
        <span className={`block text-[11px] ${weak}`}>{subtitle}</span>
      </span>
    </span>
  )
}
