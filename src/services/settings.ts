import { requireSupabase } from '@/lib/supabase'
import type { AppSettings } from '@/lib/types'
import { mockSettings } from '@/data/mock'
import { delay, isSupabaseConfigured } from './base'

const demoSettings: AppSettings = { ...mockSettings }

export async function getSettings(): Promise<AppSettings> {
  if (!isSupabaseConfigured) return delay({ ...demoSettings })

  const { data, error } = await requireSupabase()
    .from('app_settings')
    .select('*')
    .eq('id', 1)
    .single()
  if (error) throw error
  return data as AppSettings
}

export async function saveSettings(settings: AppSettings): Promise<void> {
  if (!isSupabaseConfigured) {
    Object.assign(demoSettings, settings)
    await delay(null, 420)
    return
  }

  const { error } = await requireSupabase()
    .from('app_settings')
    .update({ ...settings, updated_at: new Date().toISOString() })
    .eq('id', 1)
  if (error) throw error
}
