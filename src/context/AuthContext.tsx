import { createContext, use, useCallback, useEffect, useMemo, useState, type ReactNode } from 'react'
import { isSupabaseConfigured, supabase } from '@/lib/supabase'
import type { AdminRole } from '@/lib/types'
import { canManageAdmins, canWrite, getMyRole, setDemoRole } from '@/services/admins'
import { setAuditActor } from '@/services/audit'

export interface AdminUser {
  id: string
  email: string
  name: string
}

interface AuthValue {
  user: AdminUser | null
  /**
   * The signed-in admin's role, or `null` when signed in without an `admins`
   * row — authenticated but not authorised.
   */
  role: AdminRole | null
  /** May change data. Mirrors the `can_write()` RLS check. */
  canWrite: boolean
  /** May manage other admins. Mirrors the `is_owner()` RLS check. */
  canManageAdmins: boolean
  /** True until the initial session lookup settles — routes wait on this. */
  loading: boolean
  signIn: (email: string, password: string) => Promise<void>
  signOut: () => Promise<void>
  /** Demo mode only: re-render the UI as another role to see gating at work. */
  previewRole: (role: AdminRole) => void
}

const AuthContext = createContext<AuthValue | null>(null)

const DEMO_STORAGE_KEY = 'demo-admin'

function nameFromEmail(email: string): string {
  const handle = email.split('@')[0] ?? 'admin'
  return handle.replace(/[._-]+/g, ' ')
}

export function AuthProvider({ children }: { children: ReactNode }) {
  const [user, setUser] = useState<AdminUser | null>(null)
  const [role, setRole] = useState<AdminRole | null>(null)
  const [roleNonce, setRoleNonce] = useState(0)
  const [loading, setLoading] = useState(true)

  // The audit log stamps every mutation with whoever is signed in, so the actor
  // is published here rather than passed through each service call.
  useEffect(() => {
    setAuditActor(user?.email ?? '')
  }, [user])

  useEffect(() => {
    if (!user) {
      setRole(null)
      return
    }
    let active = true
    getMyRole(user.id)
      .then((next) => {
        if (active) setRole(next)
      })
      .catch(() => {
        // A failed role lookup must not read as "full access".
        if (active) setRole(null)
      })
    return () => {
      active = false
    }
  }, [user, roleNonce])

  const previewRole = useCallback((next: AdminRole) => {
    setDemoRole(next)
    setRoleNonce((value) => value + 1)
  }, [])

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
      // Signing out clears the demo-only state as well — role preview and audit
      // trail — so the next sign-in starts from a clean slate.
      localStorage.removeItem(DEMO_STORAGE_KEY)
      localStorage.removeItem('demo-role')
      localStorage.removeItem('demo-audit-log')
      setUser(null)
      return
    }
    await supabase.auth.signOut()
    setUser(null)
  }, [])

  const value = useMemo<AuthValue>(
    () => ({
      user,
      role,
      canWrite: canWrite(role),
      canManageAdmins: canManageAdmins(role),
      loading,
      signIn,
      signOut,
      previewRole,
    }),
    [user, role, loading, signIn, signOut, previewRole],
  )

  return <AuthContext value={value}>{children}</AuthContext>
}

export function useAuth(): AuthValue {
  const value = use(AuthContext)
  if (!value) throw new Error('useAuth يجب أن يُستخدم داخل AuthProvider')
  return value
}
