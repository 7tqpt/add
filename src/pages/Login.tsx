import { useState, type FormEvent } from "react";
import { Navigate, useLocation, useNavigate } from "react-router-dom";
import { AlertCircle, Eye, EyeOff } from "lucide-react";
import { acceptInvitation, checkInvitation } from "@/services/admins";
import { ROLE_LABEL } from "@/lib/permissions";
import { Button } from "@/components/ui/Button";
import { Field, Input } from "@/components/ui/Field";
import { LoadingBlock, Spinner } from "@/components/ui/Feedback";
import { useAuth } from "@/context/AuthContext";
import { isSupabaseConfigured } from "@/lib/supabase";

export function LoginPage() {
  const { user, loading, signIn, signUp, verifySignUpCode, resendSignUpCode } =
    useAuth();
  const navigate = useNavigate();
  const location = useLocation();
  const [mode, setMode] = useState<"signin" | "invite">("signin");
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [token, setToken] = useState("");
  const [code, setCode] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [notice, setNotice] = useState<string | null>(null);
  const [showPassword, setShowPassword] = useState(false);
  const [submitting, setSubmitting] = useState(false);

  /**
   * وُجودُه يقلب البطاقة إلى خطوة الرمز.
   *
   * ورمز الدعوة يُحفظ معه لا يُطلب ثانيةً: الموظف أدخله قبل قليل، وإعادة
   * سؤاله عنه بعد أن قطع نصف الطريق عقوبةٌ بلا سبب.
   */
  const [pending, setPending] = useState<{
    email: string;
    token: string;
  } | null>(null);

  /** قبول الدعوة بعد أن صارت هناك جلسة — الخطوة الأخيرة في المسارين. */
  async function claimRole(inviteToken: string) {
    const role = await acceptInvitation(inviteToken);
    setNotice(`أهلاً بك — دورك «${ROLE_LABEL[role]}».`);
    navigate("/", { replace: true });
  }

  async function handleVerify(event: FormEvent) {
    event.preventDefault();
    if (!pending) return;
    setError(null);
    setNotice(null);
    setSubmitting(true);
    try {
      await verifySignUpCode(pending.email, code);
      await claimRole(pending.token);
    } catch (cause) {
      setError(cause instanceof Error ? cause.message : "تعذّر تأكيد الرمز.");
    } finally {
      setSubmitting(false);
    }
  }

  async function handleResend() {
    if (!pending) return;
    setError(null);
    setNotice(null);
    setSubmitting(true);
    try {
      await resendSignUpCode(pending.email);
      setNotice("أُرسل رمزٌ جديد. تحقّق من «المهملات» إن تأخّر.");
    } catch (cause) {
      setError(cause instanceof Error ? cause.message : "تعذّر إرسال الرمز.");
    } finally {
      setSubmitting(false);
    }
  }

  if (loading) return <LoadingBlock label="جارٍ التحقق من الجلسة…" />;

  if (user) {
    const from = (location.state as { from?: string } | null)?.from;
    return <Navigate to={from && from !== "/login" ? from : "/"} replace />;
  }

  async function handleSubmit(event: FormEvent) {
    event.preventDefault();
    setError(null);
    setNotice(null);
    setSubmitting(true);
    try {
      if (mode === "signin") {
        await signIn(email.trim(), password);
        navigate("/", { replace: true });
        return;
      }

      /**
       * الرمز يُفحص قبل إنشاء الحساب.
       *
       * وإلا خلّفت كل محاولةٍ خاطئة حساباً يتيماً في مصادقة Supabase لا تحذفه
       * اللوحة — حذف مستخدمي المصادقة يحتاج `service_role`، وهو لا يوضع في
       * متصفّح. والفحص قراءةٌ محضة لا تقبل الدعوة: القبول يبقى في دالته وحدها،
       * بجلسةٍ حقيقية، لأن القاعدة تقرأ البريد من رمز الجلسة لا ممّا يُرسله
       * المتصفّح.
       */
      const invited = await checkInvitation(token, email.trim());
      if (!invited) {
        throw new Error(
          "الدعوة غير صالحة — تأكّد من الرمز ومن أنك تستعمل البريد المدعوّ.",
        );
      }

      const needsCode = await signUp(email.trim(), password);
      if (needsCode) {
        setPending({ email: email.trim(), token });
        setNotice(`أرسلنا رمزاً إلى ${email.trim()} — اكتبه لتفعيل حسابك.`);
        return;
      }
      await claimRole(token);
    } catch (cause) {
      setError(
        cause instanceof Error
          ? cause.message
          : mode === "signin"
            ? "تعذّر تسجيل الدخول."
            : "تعذّر إكمال التسجيل.",
      );
    } finally {
      setSubmitting(false);
    }
  }

  return (
    /**
     * (أ) «المخمل» — اختارها صاحبُ المنصّة من صورتين: بطاقةٌ كريميّةٌ في
     * الوسط، وخلفها ورودُ التطبيق على النبيذيّ.
     *
     * والصورةُ نفسُها التي في رأس القائمة (`/brand/roses.webp`)، ممدودةً على
     * الشاشة كلّها، وفوقها ستارٌ نبيذيٌّ يُعتم أطرافَها أكثرَ من وسطها: فتبقى
     * الورودُ على الجانبين، والبطاقةُ هي ما تقع عليه العين. واللونُ تحت الصورة
     * نبيذيٌّ لا أسود، فإن تأخّرت الصورةُ لم تَبِن الصفحةُ فارغة.
     */
    <div
      data-login
      className="relative grid min-h-full place-items-center overflow-hidden bg-[#5c0820] bg-cover bg-center px-4 py-10"
      style={{ backgroundImage: "url(/brand/roses.webp)" }}
    >
      <div
        aria-hidden
        className="pointer-events-none absolute inset-0"
        style={{
          background:
            "radial-gradient(ellipse at center, rgba(92,8,32,0.35), rgba(60,4,20,0.75))",
        }}
      />

      <div className="relative w-full max-w-[26rem]">
        {/*
          البطاقةُ كريميّةٌ في الوضعين: هي ورقةُ الدخول على المخمل، لا سطحٌ من
          اللوحة. و`data-theme="light"` تزرع الألوانَ الفاتحة في فرعها وحده،
          فيتبعها كلُّ حقلٍ وحبرٍ بداخلها ولو كانت اللوحةُ داكنة.
        */}
        <div
          data-theme="light"
          data-login-card
          className="rounded-[26px] border border-[#e6c47388] bg-page px-6 pt-7 pb-6 text-ink shadow-[0_30px_80px_-20px_rgba(0,0,0,0.6)] sm:px-[34px] sm:pt-[30px]"
        >
          <div className="flex flex-col items-center gap-1.5 text-center">
            <img
              src="/brand/farhati.png"
              alt=""
              aria-hidden
              width={74}
              height={74}
              className="h-[74px] w-[74px] rounded-[20px] shadow-[0_0_0_3px_#e6c47366]"
            />
            <h1 className="mt-1 text-[28px] leading-tight font-bold text-accent">
              فرحتي
            </h1>
            <p className="text-[13px] text-gold-ink">
              لوحة الإدارة — للمسؤولين وحدهم
            </p>
          </div>
          <div
            aria-hidden
            className="mt-3.5 mb-5 h-px bg-[linear-gradient(90deg,transparent,#c9a46a,transparent)]"
          />

          {pending || mode === "invite" ? (
            <p className="mb-4 text-center text-xs text-ink-2">
              {pending
                ? "خطوة أخيرة — أكّد بريدك"
                : "أنشئ حسابك برمز الدعوة الذي وصلك"}
            </p>
          ) : null}

          {pending ? (
            <form onSubmit={handleVerify} className="flex flex-col gap-4">
              <p className="text-xs leading-6 text-ink-2">
                أرسلنا رمزاً إلى{" "}
                <span dir="ltr" className="font-semibold text-ink">
                  {pending.email}
                </span>
                . اكتبه هنا لتفعيل حسابك، ويُمنح دورك فور تأكيده.
              </p>

              <Field
                label="رمز التفعيل"
                hint="ستّة أرقام، وصلتك في رسالة بريد."
              >
                {(id) => (
                  <Input
                    id={id}
                    required
                    inputMode="numeric"
                    autoComplete="one-time-code"
                    dir="ltr"
                    placeholder="------"
                    className="login-field tnum text-center text-lg tracking-[0.4em]"
                    value={code}
                    onChange={(event) => setCode(event.target.value)}
                  />
                )}
              </Field>

              {error ? (
                <p
                  role="alert"
                  className="flex items-start gap-2 rounded-lg border border-[color-mix(in_oklab,var(--critical)_35%,transparent)] px-3 py-2 text-xs text-ink"
                >
                  <AlertCircle
                    size={14}
                    aria-hidden
                    className="mt-0.5 shrink-0 text-[var(--critical)]"
                  />
                  {error}
                </p>
              ) : null}

              {notice ? (
                <p role="status" className="text-xs text-[var(--good)]">
                  {notice}
                </p>
              ) : null}

              <Button
                type="submit"
                variant="primary"
                className="btn-glass login-button"
                disabled={submitting}
              >
                {submitting ? <Spinner /> : null}
                تفعيل الحساب
              </Button>

              <button
                type="button"
                onClick={handleResend}
                disabled={submitting}
                className="cursor-pointer text-center text-xs text-ink-2 underline underline-offset-4 hover:text-ink"
              >
                لم يصلني — أعد الإرسال
              </button>

              <button
                type="button"
                // مخرجٌ ممّن أخطأ بريده: بدونه يُحبس في شاشةٍ تنتظر رمزاً لن يأتي.
                onClick={() => {
                  setPending(null);
                  setCode("");
                  setError(null);
                  setNotice(null);
                }}
                className="cursor-pointer text-center text-xs text-ink-2 underline underline-offset-4 hover:text-ink"
              >
                بياناتي خطأ — ارجع
              </button>
            </form>
          ) : (
            <form onSubmit={handleSubmit} className="flex flex-col gap-4">
              {/*
                    بلا نصٍّ تمهيديّ داخل الحقول: التسمية فوق كلٍّ منها تحمل
                    معناها، والنصّ الرماديّ بداخلها يُقرأ قيمةً مكتوبةً بالفعل
                    فيتردّد الناظر: أهذا بريدي أم مثال؟ وحقلٌ فارغٌ تحت تسميةٍ
                    واضحة أصدق من حقلٍ يبدو ممتلئاً وليس كذلك.
                  */}
              <Field label="البريد الإلكتروني">
                {(id) => (
                  <Input
                    id={id}
                    type="email"
                    required
                    autoComplete="username"
                    dir="ltr"
                    className="login-field"
                    value={email}
                    onChange={(event) => setEmail(event.target.value)}
                  />
                )}
              </Field>

              <Field
                label="كلمة المرور"
                hint={
                  mode === "invite"
                    ? "اختر كلمة مرور جديدة — ٨ أحرف فأكثر."
                    : undefined
                }
              >
                {(id) => (
                  /*
                        زرّ المعاينة داخل الحقل لا بجانبه: بجانبه يزيح الحقل
                        فيضيق، وداخله يحتاج حشوةً في الطرف حتى لا يمرّ النصّ
                        تحته. و`ps-11` هي تلك الحشوة — على طرف البداية لأن
                        الحقل مكتوبٌ `dir="ltr"` والزرّ يجلس يساره.
                      */
                  <div className="relative">
                    <Input
                      id={id}
                      type={showPassword ? "text" : "password"}
                      required
                      minLength={mode === "invite" ? 8 : undefined}
                      autoComplete={
                        mode === "invite" ? "new-password" : "current-password"
                      }
                      dir="ltr"
                      className="login-field pe-11"
                      value={password}
                      onChange={(event) => setPassword(event.target.value)}
                    />
                    <button
                      type="button"
                      onClick={() => setShowPassword((on) => !on)}
                      // `aria-pressed` لا نصٌّ متبدّل وحده: قارئ الشاشة
                      // يُعلن الحالة، ولا يترك المستخدم يخمّن أثر الضغطة.
                      aria-pressed={showPassword}
                      aria-label={
                        showPassword ? "إخفاء كلمة المرور" : "إظهار كلمة المرور"
                      }
                      // `tabIndex={-1}` مقصود: من يتنقّل بالتاب يريد
                      // الانتقال من كلمة المرور إلى زرّ الدخول، لا أن
                      // تعترضه أداةُ عرضٍ في الطريق. والفأرة تصله، وقارئ
                      // الشاشة يصله في تصفّح العناصر.
                      tabIndex={-1}
                      className="icon-press absolute top-1/2 start-1.5 flex h-8 w-8 -translate-y-1/2 cursor-pointer items-center justify-center rounded-full text-muted transition-colors hover:bg-surface-2 hover:text-ink"
                    >
                      {showPassword ? (
                        <EyeOff size={16} aria-hidden />
                      ) : (
                        <Eye size={16} aria-hidden />
                      )}
                    </button>
                  </div>
                )}
              </Field>

              {mode === "invite" ? (
                <Field
                  label="رمز الدعوة"
                  hint="عشر خانات، وصلتك من مالك المنصة."
                >
                  {(id) => (
                    <Input
                      id={id}
                      required
                      dir="ltr"
                      placeholder="A1B2C3D4E5"
                      className="login-field tnum tracking-widest"
                      value={token}
                      onChange={(event) =>
                        setToken(event.target.value.toUpperCase())
                      }
                    />
                  )}
                </Field>
              ) : null}

              {error ? (
                <p
                  role="alert"
                  className="flex items-start gap-2 rounded-lg border border-[color-mix(in_oklab,var(--critical)_35%,transparent)] px-3 py-2 text-xs text-ink"
                >
                  <AlertCircle
                    size={14}
                    aria-hidden
                    className="mt-0.5 shrink-0 text-[var(--critical)]"
                  />
                  {error}
                </p>
              ) : null}

              {notice ? (
                <p role="status" className="text-xs text-[var(--good)]">
                  {notice}
                </p>
              ) : null}

              <Button
                type="submit"
                variant="primary"
                className="btn-glass login-button"
                disabled={submitting}
              >
                {submitting ? <Spinner /> : null}
                {mode === "signin" ? "تسجيل الدخول" : "إنشاء الحساب والدخول"}
              </Button>

              <button
                type="button"
                onClick={() => {
                  setMode(mode === "signin" ? "invite" : "signin");
                  setError(null);
                  setNotice(null);
                }}
                className="cursor-pointer text-center text-[13px] text-accent underline underline-offset-4 hover:text-ink"
              >
                {mode === "signin"
                  ? "وصلني رمز دعوة — أنشئ حسابي"
                  : "لديّ حساب — عودة لتسجيل الدخول"}
              </button>
            </form>
          )}
        </div>

        {!isSupabaseConfigured ? (
          <p className="mt-4 rounded-2xl border border-[#e6c47355] bg-[#2a0a14]/55 px-4 py-3 text-xs leading-6 text-[#f7e9ec]/80 backdrop-blur-sm">
            <strong className="font-semibold">وضع العرض التجريبي:</strong> لم
            يتم ربط Supabase بعد، لذا يقبل النموذج أي بريد إلكتروني مع كلمة مرور
            من ٤ أحرف فأكثر لعرض اللوحة. للربط الحقيقي، شغّل{" "}
            <code dir="ltr" className="rounded bg-white/10 px-1 text-[#f7e9ec]">
              supabase/schema.sql
            </code>{" "}
            وأضف المفاتيح في{" "}
            <code dir="ltr" className="rounded bg-white/10 px-1 text-[#f7e9ec]">
              .env
            </code>
            .
          </p>
        ) : null}
      </div>
    </div>
  );
}
