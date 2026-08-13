import { useCallback, useEffect, useRef, useState } from 'react'

/** يستخرج رسالةً مقروءة مما رُمي. */
export function messageOf(error: unknown): string {
  if (error instanceof Error) return error.message
  // Supabase يرفض بكائن عادي لا بـ Error، فالاكتفاء بـ instanceof يبتلع كل
  // أخطاء القاعدة ويعرض جملةً لا تدلّ على شيء.
  if (error && typeof error === 'object') {
    const { message, hint, code } = error as {
      message?: unknown
      hint?: unknown
      code?: unknown
    }
    if (typeof message === 'string' && message.trim()) {
      const suffix = typeof hint === 'string' && hint.trim() ? ` — ${hint}` : ''
      const prefix = typeof code === 'string' && code.trim() ? `[${code}] ` : ''
      return `${prefix}${message}${suffix}`
    }
  }
  if (typeof error === 'string' && error.trim()) return error
  return 'تعذّر تحميل البيانات.'
}

export interface AsyncState<T> {
  data: T | null
  error: string | null
  loading: boolean
  reload: () => void
}

export function useAsync<T>(loader: () => Promise<T>, deps: readonly unknown[]): AsyncState<T> {
  const [data, setData] = useState<T | null>(null)
  const [error, setError] = useState<string | null>(null)
  const [pending, setPending] = useState(true)
  const [nonce, setNonce] = useState(0)

  const loaderRef = useRef(loader)
  loaderRef.current = loader

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
        if (active) setError(messageOf(cause))
      })
      .finally(() => {
        if (active) setPending(false)
      })
    return () => {
      active = false
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [...deps, nonce])

  const reload = useCallback(() => setNonce((n) => n + 1), [])

  return { data, error, loading: pending && data === null, reload }
}
