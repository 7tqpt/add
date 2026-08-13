import {
  createContext,
  use,
  useCallback,
  useEffect,
  useMemo,
  useState,
  type ReactNode,
} from 'react'
import { isSupabaseConfigured, supabase } from './supabase'

/**
 * الدور الذي يستعمل به الشخص التطبيق الآن.
 *
 * ليس صفةً في الحساب: الشخص نفسه قد يحجز لعرس أخيه ويبيع خدمة التصوير. فهو
 * اختيار عرضٍ يُبدَّل من شاشة الحساب، لا هويةٌ تُثبَّت عند التسجيل.
 */
export type AppRole = 'customer' | 'provider'

interface SessionValue {
  userId: string | null
  email: string
  /** معرّف الصفّ في `app_users` — يُملأ بعد `api_register_profile`. */
  appUserId: string | null
  /** معرّف ملف مقدّم الخدمة إن وُجد، وإلا null. */
  providerId: string | null
  role: AppRole
  setRole: (role: AppRole) => void
  /** true حتى تستقرّ الجلسة وأول قراءة للملف. */
  loading: boolean
  /** الحساب موجود في المصادقة لكن بلا صفّ في `app_users` بعد. */
  needsProfile: boolean
  signIn: (email: string, password: string) => Promise<void>
  signUp: (email: string, password: string) => Promise<void>
  signOut: () => Promise<void>
  refresh: () => void
}

const SessionContext = createContext<SessionValue | null>(null)

const TIMEOUT_MS = 20_000

/** يحوّل صمت الشبكة إلى رسالة بدل مؤشّر دوّار لا ينتهي. */
function withTimeout<T>(promise: PromiseLike<T>): Promise<T> {
  return Promise.race([
    promise,
    new Promise<never>((_, reject) =>
      setTimeout(
        () => reject(new Error('تعذّر الوصول إلى الخادم. تحقّق من اتصالك ثم أعد المحاولة.')),
        TIMEOUT_MS,
      ),
    ),
  ])
}

export function SessionProvider({ children }: { children: ReactNode }) {
  const [userId, setUserId] = useState<string | null>(null)
  const [email, setEmail] = useState('')
  const [appUserId, setAppUserId] = useState<string | null>(null)
  const [providerId, setProviderId] = useState<string | null>(null)
  const [role, setRole] = useState<AppRole>('customer')
  const [loading, setLoading] = useState(true)
  const [nonce, setNonce] = useState(0)

  useEffect(() => {
    if (!isSupabaseConfigured || !supabase) {
      // الوضع التجريبي: هوية محلّية بلا خادم، فتُتصفَّح الشاشات كلها.
      setUserId('demo-user')
      setEmail('demo@example.com')
      setAppUserId('demo-app-user')
      setProviderId('demo-provider')
      setLoading(false)
      return
    }
    const client = supabase
    let active = true

    client.auth.getSession().then(({ data }) => {
      if (!active) return
      setUserId(data.session?.user.id ?? null)
      setEmail(data.session?.user.email ?? '')
      if (!data.session) setLoading(false)
    })

    const { data: sub } = client.auth.onAuthStateChange((_event, session) => {
      setUserId(session?.user.id ?? null)
      setEmail(session?.user.email ?? '')
      if (!session) {
        setAppUserId(null)
        setProviderId(null)
        setLoading(false)
      }
    })

    return () => {
      active = false
      sub.subscription.unsubscribe()
    }
  }, [])

  /**
   * من هو هذا الحساب في المنصة: عميل مسجَّل؟ مقدّم خدمة أيضاً؟
   *
   * يُقرأ من الجدولين مباشرةً لا بدالة: `current_app_user()` و
   * `current_provider()` مساعدتان داخليتان لم تُمنح صلاحية تنفيذهما لـ
   * `authenticated`، فاستدعاؤهما من التطبيق يرتدّ. وسياسات القراءة الذاتية
   * تكفي — كلٌّ يرى صفّه هو.
   */
  useEffect(() => {
    if (!userId || !supabase) return
    const client = supabase
    let active = true
    setLoading(true)

    /**
     * `Promise.resolve(...)` حول الاستعلام مقصود: مُنشئ الاستعلام في
     * postgrest-js كائنٌ ذو `then` لا وعدٌ كامل، فليس فيه `catch` ولا
     * `finally` — والسلسلة بدونها لا تُصرّف أصلاً.
     */
    Promise.resolve(
      (async () => {
        const { data } = await client
          .from('app_users')
          .select('id')
          .eq('auth_user_id', userId)
          .maybeSingle()
        const mine = (data?.id as string | undefined) ?? null
        if (!mine) return { appUser: null, provider: null }
        const { data: prov } = await client
          .from('service_providers')
          .select('id')
          .eq('user_id', mine)
          .maybeSingle()
        return { appUser: mine, provider: (prov?.id as string | undefined) ?? null }
      })(),
    )
      .then((result) => {
        if (!active) return
        setAppUserId(result.appUser)
        setProviderId(result.provider)
      })
      .catch(() => {
        if (active) {
          setAppUserId(null)
          setProviderId(null)
        }
      })
      .finally(() => {
        if (active) setLoading(false)
      })

    return () => {
      active = false
    }
  }, [userId, nonce])

  const signIn = useCallback(async (mail: string, password: string) => {
    if (!isSupabaseConfigured) {
      if (password.length < 4) throw new Error('كلمة المرور قصيرة جداً (٤ أحرف على الأقل).')
      setUserId('demo-user')
      setEmail(mail)
      setAppUserId('demo-app-user')
      setProviderId('demo-provider')
      return
    }
    const client = requireClient()
    const { error } = await withTimeout(
      client.auth.signInWithPassword({ email: mail, password }),
    )
    if (error) {
      throw new Error(
        error.message === 'Invalid login credentials'
          ? 'بيانات الدخول غير صحيحة.'
          : error.message,
      )
    }
  }, [])

  const signUp = useCallback(async (mail: string, password: string) => {
    if (!isSupabaseConfigured) {
      if (password.length < 8) throw new Error('كلمة المرور قصيرة جداً (٨ أحرف على الأقل).')
      setUserId('demo-user')
      setEmail(mail)
      setAppUserId('demo-app-user')
      setProviderId('demo-provider')
      return
    }
    const client = requireClient()
    const { data, error } = await withTimeout(client.auth.signUp({ email: mail, password }))
    if (error) {
      throw new Error(
        error.message === 'User already registered'
          ? 'هذا البريد مسجّل — سجّل الدخول بدلاً من إنشاء حساب.'
          : error.message,
      )
    }
    if (!data.session) {
      throw new Error('أُنشئ حسابك — افتح رسالة التأكيد في بريدك ثم سجّل الدخول.')
    }
  }, [])

  const signOut = useCallback(async () => {
    if (supabase) await supabase.auth.signOut()
    else {
      setUserId(null)
      setEmail('')
    }
    setUserId(null)
    setAppUserId(null)
    setProviderId(null)
    setRole('customer')
  }, [])

  const value = useMemo<SessionValue>(
    () => ({
      userId,
      email,
      appUserId,
      providerId,
      role,
      setRole,
      loading,
      needsProfile: userId !== null && appUserId === null,
      signIn,
      signUp,
      signOut,
      refresh: () => setNonce((n) => n + 1),
    }),
    [userId, email, appUserId, providerId, role, loading, signIn, signUp, signOut],
  )

  return <SessionContext value={value}>{children}</SessionContext>
}

function requireClient() {
  if (!supabase) {
    throw new Error('لم يُضبط Supabase. املأ .env ثم أعد تشغيل التطبيق.')
  }
  return supabase
}

export function useSession(): SessionValue {
  const value = use(SessionContext)
  if (!value) throw new Error('useSession يجب أن يُستعمل داخل SessionProvider')
  return value
}
