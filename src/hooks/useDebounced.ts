import { useEffect, useState } from 'react'

/** Delays a fast-changing value (search input) so it does not drive a query per keystroke. */
export function useDebounced<T>(value: T, delayMs = 300): T {
  const [settled, setSettled] = useState(value)

  useEffect(() => {
    const timer = setTimeout(() => setSettled(value), delayMs)
    return () => clearTimeout(timer)
  }, [value, delayMs])

  return settled
}
