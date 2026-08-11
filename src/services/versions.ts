import { requireSupabase } from '@/lib/supabase'
import type { AppVersion } from '@/lib/types'
import { mockVersions } from '@/data/mock'
import { delay, isSupabaseConfigured } from './base'

const demoVersions: AppVersion[] = [...mockVersions].sort(
  (a, b) => new Date(b.released_at).getTime() - new Date(a.released_at).getTime(),
)

export async function listVersions(): Promise<AppVersion[]> {
  if (!isSupabaseConfigured) return delay([...demoVersions])

  const { data, error } = await requireSupabase()
    .from('app_versions')
    .select('*')
    .order('released_at', { ascending: false })
  if (error) throw error
  return (data ?? []) as AppVersion[]
}

export async function setForceUpdate(id: string, forceUpdate: boolean): Promise<void> {
  if (!isSupabaseConfigured) {
    const version = demoVersions.find((candidate) => candidate.id === id)
    if (version) version.force_update = forceUpdate
    await delay(null, 180)
    return
  }

  const { error } = await requireSupabase()
    .from('app_versions')
    .update({ force_update: forceUpdate })
    .eq('id', id)
  if (error) throw error
}

export async function setRollout(id: string, percent: number): Promise<void> {
  const clamped = Math.min(100, Math.max(0, Math.round(percent)))

  if (!isSupabaseConfigured) {
    const version = demoVersions.find((candidate) => candidate.id === id)
    if (version) version.rollout_percent = clamped
    await delay(null, 180)
    return
  }

  const { error } = await requireSupabase()
    .from('app_versions')
    .update({ rollout_percent: clamped })
    .eq('id', id)
  if (error) throw error
}
