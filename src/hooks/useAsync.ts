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

function messageOf(error: unknown): string {
  if (error instanceof Error) return error.message
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
