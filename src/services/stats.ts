import { requireSupabase } from '@/lib/supabase'
import type { DailyBreakdown, DashboardStats, MetricPoint, Platform, RangeDays } from '@/lib/types'
import {
  mockCrashFreeRate,
  mockInstallsByDay,
  mockRevenueByDay,
  mockSessionsByDay,
  mockUsers,
} from '@/data/mock'
import { delay, isSupabaseConfigured, isoDaysAgo, lastDays, periodChange, sum } from './base'

/** Sessions-per-active-user, used to derive DAU from the sessions series in demo mode. */
const SESSIONS_PER_ACTIVE_USER = 2.4

function tally<T extends string>(items: T[]): Map<T, number> {
  const counts = new Map<T, number>()
  for (const item of items) counts.set(item, (counts.get(item) ?? 0) + 1)
  return counts
}

function topCountriesFrom(countries: string[]) {
  return [...tally(countries)]
    .map(([country, users]) => ({ country, users }))
    .sort((a, b) => b.users - a.users)
    .slice(0, 5)
}

/**
 * Assembles every figure the dashboard shows for the selected range.
 *
 * Each KPI carries its own change vs. the preceding window of equal length, so
 * the series are fetched at twice the range and split rather than fetched twice.
 */
export async function getDashboardStats(range: RangeDays): Promise<DashboardStats> {
  if (isSupabaseConfigured) return fromSupabase(range)
  return delay(buildStats(range, demoSeries()))
}

interface Series {
  installs: DailyBreakdown[]
  sessions: MetricPoint[]
  revenue: MetricPoint[]
  active: MetricPoint[]
  countries: string[]
  crashFreeRate: number
}

function demoSeries(): Series {
  return {
    installs: mockInstallsByDay,
    sessions: mockSessionsByDay,
    revenue: mockRevenueByDay,
    active: mockSessionsByDay.map((point, i) => ({
      date: point.date,
      // Sessions-per-user drifts day to day, so a fixed sinusoid keeps DAU
      // correlated with sessions without making it a scaled copy — otherwise
      // both KPIs would report the identical period-over-period change.
      value: Math.round(point.value / (SESSIONS_PER_ACTIVE_USER + 0.4 * Math.sin(i * 1.7))),
    })),
    countries: mockUsers.map((user) => user.country),
    crashFreeRate: mockCrashFreeRate,
  }
}

function buildStats(range: RangeDays, series: Series): DashboardStats {
  const installsWindow = lastDays(series.installs, range)
  const installTotals = series.installs.map((day) => day.ios + day.android)
  const sessionValues = series.sessions.map((point) => point.value)
  const revenueValues = series.revenue.map((point) => point.value)
  const activeValues = series.active.map((point) => point.value)
  const activeWindow = lastDays(activeValues, range)

  const platformTotals: { platform: Platform; users: number }[] = [
    { platform: 'ios', users: sum(series.installs.map((day) => day.ios)) },
    { platform: 'android', users: sum(series.installs.map((day) => day.android)) },
  ]

  return {
    // Average DAU reads as a level, not a total — summing daily actives would
    // double-count anyone who opened the app on more than one day.
    activeUsers: {
      value: activeWindow.length ? Math.round(sum(activeWindow) / activeWindow.length) : 0,
      change: periodChange(activeValues, range),
    },
    installs: {
      value: sum(lastDays(installTotals, range)),
      change: periodChange(installTotals, range),
    },
    sessions: {
      value: sum(lastDays(sessionValues, range)),
      change: periodChange(sessionValues, range),
    },
    revenue: {
      value: sum(lastDays(revenueValues, range)),
      change: periodChange(revenueValues, range),
    },
    installsByDay: installsWindow,
    sessionsByDay: lastDays(series.sessions, range),
    platformSplit: platformTotals,
    topCountries: topCountriesFrom(series.countries),
    crashFreeRate: series.crashFreeRate,
  }
}

interface MetricRow {
  day: string
  platform: Platform
  installs: number
  sessions: number
  active_users: number
  revenue: number
}

async function fromSupabase(range: RangeDays): Promise<DashboardStats> {
  const client = requireSupabase()

  // Twice the range so each KPI can compare against the preceding window.
  const [metrics, users] = await Promise.all([
    client
      .from('daily_metrics')
      .select('day, platform, installs, sessions, active_users, revenue')
      .gte('day', isoDaysAgo(range * 2))
      .order('day', { ascending: true }),
    client.from('app_users').select('country'),
  ])

  if (metrics.error) throw metrics.error
  if (users.error) throw users.error

  const byDay = new Map<string, { ios: number; android: number; sessions: number; revenue: number; active: number }>()
  for (const row of (metrics.data ?? []) as MetricRow[]) {
    const entry = byDay.get(row.day) ?? { ios: 0, android: 0, sessions: 0, revenue: 0, active: 0 }
    entry[row.platform] += row.installs
    entry.sessions += row.sessions
    entry.revenue += Number(row.revenue)
    entry.active += row.active_users
    byDay.set(row.day, entry)
  }

  const days = [...byDay.keys()].sort()

  return buildStats(range, {
    installs: days.map((date) => ({
      date,
      ios: byDay.get(date)!.ios,
      android: byDay.get(date)!.android,
    })),
    sessions: days.map((date) => ({ date, value: byDay.get(date)!.sessions })),
    revenue: days.map((date) => ({ date, value: byDay.get(date)!.revenue })),
    active: days.map((date) => ({ date, value: byDay.get(date)!.active })),
    countries: ((users.data ?? []) as { country: string }[])
      .map((row) => row.country)
      .filter(Boolean),
    // No crash reporting table yet — the tile renders "—" rather than a guess.
    crashFreeRate: Number.NaN,
  })
}
