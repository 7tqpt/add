import { useEffect, useRef, useState } from 'react'

/**
 * Tracks an element's content-box width so SVG charts can lay out in real pixels
 * instead of scaling a fixed viewBox (which would distort text and mark widths).
 */
export function useElementWidth<T extends HTMLElement>(fallback = 640) {
  const ref = useRef<T | null>(null)
  const [width, setWidth] = useState(fallback)

  useEffect(() => {
    const element = ref.current
    if (!element) return

    const observer = new ResizeObserver((entries) => {
      const next = entries[0]?.contentRect.width
      if (next && next > 0) setWidth(next)
    })
    observer.observe(element)
    return () => observer.disconnect()
  }, [])

  return { ref, width }
}
