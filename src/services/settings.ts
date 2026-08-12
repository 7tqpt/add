import { requireSupabase } from '@/lib/supabase'
import type { AppSettings } from '@/lib/types'
import { mockSettings } from '@/data/mock'
import { delay, isSupabaseConfigured } from './base'
import { recordAudit } from './audit'

const demoSettings: AppSettings = { ...mockSettings }

/**
 * The values as last read from the source of truth, in either mode. Kept so the
 * audit entry can name which fields actually moved rather than logging the whole
 * form on every save.
 */
let lastLoaded: AppSettings | null = null

export async function getSettings(): Promise<AppSettings> {
  if (!isSupabaseConfigured) {
    const settings = { ...demoSettings }
    lastLoaded = settings
    return delay(settings)
  }

  const { data, error } = await requireSupabase()
    .from('app_settings')
    .select('*')
    .eq('id', 1)
    .single()
  if (error) throw error
  lastLoaded = data as AppSettings
  return data as AppSettings
}

export async function saveSettings(settings: AppSettings): Promise<void> {
  const previous = lastLoaded
  const changed = previous
    ? (Object.keys(settings) as (keyof AppSettings)[]).filter(
        (key) => settings[key] !== previous[key],
      )
    : []

  if (!isSupabaseConfigured) {
    Object.assign(demoSettings, settings)
    await delay(null, 420)
  } else {
    const { error } = await requireSupabase()
      .from('app_settings')
      .update({ ...settings, updated_at: new Date().toISOString() })
      .eq('id', 1)
    if (error) throw error
  }

  lastLoaded = { ...settings }

  await recordAudit({
    action: 'settings.update',
    entity: 'settings',
    entityId: '1',
    entityLabel: 'إعدادات التطبيق',
    details: { maintenance_mode: settings.maintenance_mode, changed },
  })
}
