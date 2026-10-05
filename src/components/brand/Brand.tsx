/**
 * علامة «فرحتي» — أيقونةُ التطبيق نفسُها (`mobile/assets/brand/app_icon.png`)
 * لا رسمٌ يشبهها. اختارها صاحبُ المنصّة في (أ) «المخمل»: اللوحةُ والتطبيقُ
 * علامةٌ واحدة، وكانت اللوحةُ تحمل علامةَ «سد للبرمجيات» — وهي صانعتُها،
 * فبقي اسمُها في ذيل القائمة.
 *
 * ولا تدور: في العلامة اسمُ الشركة وشعارها مكتوبَين، ودورانُها يقلب الكلام
 * رأساً على عقب. فالحركة — إن طُلبت — في حلقةٍ مرسومةٍ حولها تدور وحدها،
 * والعلامة ثابتةٌ في مركزها.
 */

const LOGO = "/brand/farhati.png";

export function BrandMark({
  size = 40,
  spin = false,
}: {
  size?: number;
  /** حلقةٌ تدور حول العلامة — لصفحة الدخول، حيث لا شيء ينافسها على الانتباه. */
  spin?: boolean;
}) {
  return (
    <span
      className="relative inline-flex shrink-0 items-center justify-center"
      style={{ width: size, height: size }}
    >
      {spin ? (
        <svg
          viewBox="0 0 100 100"
          aria-hidden
          className="brand-ring pointer-events-none absolute inset-0 h-full w-full"
        >
          <circle
            cx="50"
            cy="50"
            r="48"
            fill="none"
            stroke="#e6c473"
            strokeOpacity="0.55"
            strokeWidth="1"
            strokeDasharray="26 10 14 8"
            strokeLinecap="round"
          />
        </svg>
      ) : null}

      <img
        src={LOGO}
        alt=""
        aria-hidden
        width={size}
        height={size}
        // الحلقة تدور خارج العلامة، فتُصغَّر قليلاً لتترك لها مجالاً.
        style={{ width: spin ? "84%" : "100%", height: spin ? "84%" : "100%" }}
        className="rounded-[22%] object-contain shadow-[0_0_0_2px_rgba(230,196,115,0.4)]"
      />
    </span>
  );
}

/**
 * العلامة والاسمان بجانبها.
 *
 * ولمَ يُكتب الاسم وهو مكتوبٌ داخل العلامة؟ لأن العلامة في الشريط الجانبي
 * ستّةٌ وثلاثون بكسلاً، وخطُّ «سد للبرمجيات» داخلها عندئذٍ أدقُّ من بكسلين —
 * يُرى ولا يُقرأ. فالنصّ خارجها هو ما يُقرأ فعلاً.
 *
 * أمّا حيث تكبر العلامة — كلوح صفحة الدخول — فالاسم داخلها يكفي، ويُستعمل
 * `BrandMark` وحده.
 */
export function BrandLockup({
  size = 40,
  spin = false,
  tone = "auto",
  subtitle = "لوحة الإدارة",
}: {
  size?: number;
  spin?: boolean;
  /** `invert` لأرضيةٍ داكنة دائماً. */
  tone?: "auto" | "invert";
  subtitle?: string;
}) {
  const strong = tone === "invert" ? "text-white" : "text-ink";
  // والسطرُ الثاني ذهبيٌّ على النبيذيّ كما في الصورة.
  const weak = tone === "invert" ? "text-[var(--side-gold)]" : "text-muted";

  return (
    <span className="flex items-center gap-2.5">
      <BrandMark size={size} spin={spin} />
      <span className="leading-tight">
        <span className={`block text-xl font-bold ${strong}`}>
          فرحتي
        </span>
        <span className={`block text-[11px] ${weak}`}>{subtitle}</span>
      </span>
    </span>
  );
}
