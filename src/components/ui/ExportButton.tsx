import { useState } from 'react'
import { Download } from 'lucide-react'
import { downloadCsv, stampedFilename, type CsvTable } from '@/lib/csv'
import { Button } from './Button'
import { Spinner } from './Feedback'

/**
 * Exports a report as CSV.
 *
 * `build` is async because the export covers the whole filtered result set, not
 * just the page on screen — that means a fresh fetch without the page window.
 */
export function ExportButton({
  filenamePrefix,
  build,
  disabled,
  onError,
}: {
  filenamePrefix: string
  build: () => Promise<CsvTable>
  disabled?: boolean
  onError?: (message: string) => void
}) {
  const [busy, setBusy] = useState(false)

  async function handleClick() {
    setBusy(true)
    try {
      const table = await build()
      downloadCsv(stampedFilename(filenamePrefix), table)
    } catch (cause) {
      onError?.(cause instanceof Error ? cause.message : 'تعذّر إنشاء ملف التصدير.')
    } finally {
      setBusy(false)
    }
  }

  return (
    <Button size="sm" onClick={handleClick} disabled={busy || disabled} title="يفتح مباشرة في Excel">
      {busy ? <Spinner /> : <Download size={14} aria-hidden />}
      تصدير CSV
    </Button>
  )
}
