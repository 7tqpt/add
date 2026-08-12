/** Wraps a cell in quotes when it contains a delimiter, quote or newline. */
function escapeCell(value: string | number | null | undefined): string {
  const text = value === null || value === undefined ? '' : String(value)
  return /[",\n\r]/.test(text) ? `"${text.replace(/"/g, '""')}"` : text
}

export interface CsvTable {
  columns: string[]
  rows: (string | number | null | undefined)[][]
}

/**
 * Triggers a CSV download in the browser.
 *
 * The leading BOM is what makes Excel read the file as UTF-8; without it Arabic
 * column headers and names arrive as mojibake. CRLF line endings are what Excel
 * expects on every platform.
 */
export function downloadCsv(filename: string, table: CsvTable): void {
  const lines = [table.columns, ...table.rows].map((row) => row.map(escapeCell).join(','))
  const blob = new Blob(['﻿' + lines.join('\r\n')], {
    type: 'text/csv;charset=utf-8;',
  })

  const url = URL.createObjectURL(blob)
  const link = document.createElement('a')
  link.href = url
  link.download = filename.endsWith('.csv') ? filename : `${filename}.csv`
  document.body.appendChild(link)
  link.click()
  link.remove()
  // Revoking synchronously races the browser's read of the blob and can cost the
  // download its filename, so hand the URL back on the next tick instead.
  setTimeout(() => URL.revokeObjectURL(url), 0)
}

/** `تقرير-المستخدمين-2026-08-11.csv` */
export function stampedFilename(prefix: string): string {
  return `${prefix}-${new Date().toISOString().slice(0, 10)}.csv`
}
