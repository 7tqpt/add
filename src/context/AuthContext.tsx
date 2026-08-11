import { createContext, use, useCallback, useEffect, useMemo, useState, type ReactNode } from 'react'
import { isSupabaseConfigured, supabase } from '@/lib/supabase'

export interface AdminUser {
  id: string
  email: string
  name: string
}

interface AuthValue {
  user: AdminUser | null
  /** True until the initial session lookup settles — routes wait on this. */
  loading: boolean
  signIn: (email: string, password: string) => Promise<void>
  signOut: () => Promise<void>
}

const AuthContext = createContext<AuthValue | null>(null)

const DEMO_STORAGE_KEY = 'demo-admin'

function nameFromEmail(email: string): string {
  const handle = email.split('@')[0] ?? 'admin'
  return handle.replace(/[._-]+/g, ' ')
}

export function AuthProvider({ children }: { children: ReactNode }) {
  const [user, setUser] = useState<AdminUser | null>(null)
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    if (!isSupabaseConfigured || !supabase) {
      // Demo mode: the "session" is a local flag, so a refresh keeps you signed in.
      const stored = localStorage.getItem(DEMO_STORAGE_KEY)
      if (stored) {
        try {
          setUser(JSON.parse(stored) as AdminUser)
        } catch {
          localStorage.removeItem(DEMO_STORAGE_KEY)
        }
      }
      setLoading(false)
      return
    }

    const client = supabase
    let active = true

    client.auth.getSession().then(({ data }) => {
      if (!active) return
      const session = data.session
      setUser(
        session
          ? {
              id: session.user.id,
              email: session.user.email ?? '',
              name: nameFromEmail(session.user.email ?? ''),
            }
          : null,
      )
      setLoading(false)
    })

    const { data: subscription } = client.auth.onAuthStateChange((_event, session) => {
      setUser(
        session
          ? {
              id: session.user.id,
              email: session.user.email ?? '',
              name: nameFromEmail(session.user.email ?? ''),
            }
          : null,
      )
    })

    return () => {
      active = false
      subscription.subscription.unsubscribe()
    }
  }, [])

  const signIn = useCallback(async (email: string, password: string) => {
    if (!isSupabaseConfigured || !supabase) {
      if (password.length < 4) {
        throw new Error('كلمة المرور قصيرة جداً (٤ أحرف على الأقل).')
      }
      const demoUser: AdminUser = {
        id: 'demo-admin',
        email,
        name: nameFromEmail(email),
      }
      localStorage.setItem(DEMO_STORAGE_KEY, JSON.stringify(demoUser))
      setUser(demoUser)
      return
    }

    const { error } = await supabase.auth.signInWithPassword({ email, password })
    if (error) {
      throw new Error(
        error.message === 'Invalid login credentials'
          ? 'بيانات الدخول غير صحيحة.'
          : error.message,
      )
    }
  }, [])

  const signOut = useCallback(async () => {
    if (!isSupabaseConfigured || !supabase) {
      localStorage.removeItem(DEMO_STORAGE_KEY)
      setUser(null)
      return
    }
    await supabase.auth.signOut()
    setUser(null)
  }, [])

  const value = useMemo<AuthValue>(
    () => ({ user, loading, signIn, signOut }),
    [user, loading, signIn, signOut],
  )

  return <AuthContext value={value}>{children}</AuthContext>
}

export function useAuth(): AuthValue {
  const value = use(AuthContext)
  if (!value) throw new Error('useAuth يجب أن يُستخدم داخل AuthProvider')
  return value
}
