import { useCallback, useEffect, useRef, useState } from 'react'

export interface AsyncState<T> {
  data: T | null
  error: string | null
  /** First load only — nothing on screen yet. */
  loading: boolean
  /** A later load while previous data is still displayed. */
  refetching: boolean
  reload: () => void
}

/**
 * Pulls a readable message out of whatever was thrown.
 *
 * Supabase rejects with a plain `{message, details, hint, code}` object, not an
 * `Error`. Checking `instanceof Error` alone therefore swallowed every database
 * error and showed «تعذّر تحميل البيانات» — a sentence that tells the reader
 * nothing they did not already see on the screen. The real text ("relation
 * v_admin_reviews does not exist") names the missing piece outright.
 */
function messageOf(error: unknown): string {
  if (error instanceof Error) return error.message

  if (error && typeof error === 'object') {
    const { message, hint, code } = error as { message?: unknown; hint?: unknown; code?: unknown }
    if (typeof message === 'string' && message.trim()) {
      // Postgres hints are written for whoever has to fix it — keep them.
      const suffix = typeof hint === 'string' && hint.trim() ? ` — ${hint}` : ''
      const prefix = typeof code === 'string' && code.trim() ? `[${code}] ` : ''
      return `${prefix}${message}${suffix}`
    }
  }

  if (typeof error === 'string' && error.trim()) return error
  return 'تعذّر تحميل البيانات.'
}

/**
 * Runs an async loader and re-runs it when `deps` change or `reload()` is called.
 *
 * Keeps the previous `data` in place while a new load is in flight so screens can
 * dim rather than flash a skeleton, and drops results from superseded loads so a
 * slow first request cannot overwrite a fast second one.
 */
export function useAsync<T>(loader: () => Promise<T>, deps: readonly unknown[]): AsyncState<T> {
  const [data, setData] = useState<T | null>(null)
  const [error, setError] = useState<string | null>(null)
  const [pending, setPending] = useState(true)
  const [nonce, setNonce] = useState(0)

  const loaderRef = useRef(loader)
  loaderRef.current = loader

  const hasData = data !== null

  useEffect(() => {
    let active = true
    setPending(true)

    loaderRef
      .current()
      .then((result) => {
        if (!active) return
        setData(result)
        setError(null)
      })
      .catch((cause: unknown) => {
        if (!active) return
        setError(messageOf(cause))
      })
      .finally(() => {
        if (active) setPending(false)
      })

    return () => {
      active = false
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [...deps, nonce])

  const reload = useCallback(() => setNonce((value) => value + 1), [])

  return {
    data,
    error,
    loading: pending && !hasData,
    refetching: pending && hasData,
    reload,
  }
}
