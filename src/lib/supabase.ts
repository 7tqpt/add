import { createClient, type SupabaseClient } from '@supabase/supabase-js'

const url = import.meta.env.VITE_SUPABASE_URL
const anonKey = import.meta.env.VITE_SUPABASE_ANON_KEY

/**
 * True when both Supabase env vars are present. When false the whole app falls
 * back to the seeded demo data in `src/data/mock.ts`, so the dashboard is fully
 * browsable before any backend exists. Copy `.env.example` to `.env` to switch
 * every screen over to the real project — no other code change is needed.
 */
export const isSupabaseConfigured = Boolean(url && anonKey)

export const supabase: SupabaseClient | null = isSupabaseConfigured
  ? createClient(url!, anonKey!, {
      auth: {
        persistSession: true,
        autoRefreshToken: true,
        detectSessionInUrl: true,
      },
    })
  : null

/** Narrows `supabase` to non-null at the call site. */
export function requireSupabase(): SupabaseClient {
  if (!supabase) {
    throw new Error(
      'لم يتم إعداد Supabase. أضف VITE_SUPABASE_URL و VITE_SUPABASE_ANON_KEY في ملف .env',
    )
  }
  return supabase
}
