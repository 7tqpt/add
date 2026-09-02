import { requireSupabase } from '@/lib/supabase'
import type { AppVersion } from '@/lib/types'
import { mockVersions } from '@/data/mock'
import { delay, isSupabaseConfigured } from './base'
import { recordAudit } from './audit'

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
  // A database that has not run `app_download.sql` yet returns rows without
  // the column at all, and `download_url` would be undefined while the type
  // promises a string — so every `.startsWith` downstream throws. The feature
  // should be missing, not the page.
  return (data ?? []).map((row) => ({
    ...row,
    download_url: (row as { download_url?: string }).download_url ?? '',
  })) as AppVersion[]
}

export async function setForceUpdate(version: AppVersion, forceUpdate: boolean): Promise<void> {
  // Read first: the demo store mutates the object this argument points at.
  const previous = version.force_update

  if (!isSupabaseConfigured) {
    const target = demoVersions.find((candidate) => candidate.id === version.id)
    if (target) target.force_update = forceUpdate
    await delay(null, 180)
  } else {
    const { error } = await requireSupabase()
      .from('app_versions')
      .update({ force_update: forceUpdate })
      .eq('id', version.id)
    if (error) throw error
  }

  await recordAudit({
    action: 'version.force_update',
    entity: 'version',
    entityId: version.id,
    entityLabel: `${version.version} (${version.platform})`,
    details: { from: previous, to: forceUpdate },
  })
}

/** https alone — the app opens whatever this holds, so a bad scheme is a hole. */
export function isDownloadUrlValid(url: string): boolean {
  if (url === '') return true // Clearing the link is allowed.
  if (!url.startsWith('https://')) return false
  try {
    return new URL(url).hostname !== ''
  } catch {
    return false
  }
}

export async function setDownloadUrl(version: AppVersion, url: string): Promise<void> {
  const trimmed = url.trim()
  if (!isDownloadUrlValid(trimmed)) {
    throw new Error('الرابط يجب أن يبدأ بـ https:// — التطبيق يفتح هذا الرابط على جهاز صاحبه.')
  }
  const previous = version.download_url

  if (!isSupabaseConfigured) {
    const target = demoVersions.find((candidate) => candidate.id === version.id)
    if (target) target.download_url = trimmed
    await delay(null, 180)
  } else {
    const { error } = await requireSupabase()
      .from('app_versions')
      .update({ download_url: trimmed })
      .eq('id', version.id)
    if (error) throw error
  }

  await recordAudit({
    action: 'version.download_url',
    entity: 'version',
    entityId: version.id,
    entityLabel: `${version.version} (${version.platform})`,
    details: { from: previous || '(فارغ)', to: trimmed || '(فارغ)' },
  })
}

export async function setRollout(version: AppVersion, percent: number): Promise<void> {
  const clamped = Math.min(100, Math.max(0, Math.round(percent)))
  const previous = version.rollout_percent

  if (!isSupabaseConfigured) {
    const target = demoVersions.find((candidate) => candidate.id === version.id)
    if (target) target.rollout_percent = clamped
    await delay(null, 180)
  } else {
    const { error } = await requireSupabase()
      .from('app_versions')
      .update({ rollout_percent: clamped })
      .eq('id', version.id)
    if (error) throw error
  }

  await recordAudit({
    action: 'version.rollout',
    entity: 'version',
    entityId: version.id,
    entityLabel: `${version.version} (${version.platform})`,
    details: { from: `${previous}%`, to: `${clamped}%` },
  })
}
