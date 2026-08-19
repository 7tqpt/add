import { useId, useState, type ReactNode } from 'react'
import { Table2, LineChart as LineChartIcon } from 'lucide-react'
import { Card, CardHeader } from '@/components/ui/Card'
import { cn } from '@/lib/cn'
import type { SeriesDef } from './chart-utils'

export interface TableView {
  columns: string[]
  rows: (string | number)[][]
}

/**
 * Frame shared by every chart: title, legend, and the table-view twin.
 *
 * The table is not a nicety — it is the WCAG-clean equivalent that keeps values
 * reachable when color or hover is not, so every chart on the dashboard has one.
 */
export function ChartCard({
  title,
  subtitle,
  series,
  table,
  refetching,
  children,
}: {
  title: string
  subtitle?: string
  /** Omit for a single-series chart — the title already names it. */
  series?: SeriesDef[]
  table: TableView
  refetching?: boolean
  children: ReactNode
}) {
  const [view, setView] = useState<'chart' | 'table'>('chart')
  const panelId = useId()

  return (
    <Card className="flex flex-col">
      <CardHeader
        title={title}
        subtitle={subtitle}
        actions={
          <div className="flex items-center gap-1 rounded-lg border border-hairline p-0.5">
            <ViewTab
              active={view === 'chart'}
              onClick={() => setView('chart')}
              icon={<LineChartIcon size={14} aria-hidden />}
              label="رسم"
              controls={panelId}
            />
            <ViewTab
              active={view === 'table'}
              onClick={() => setView('table')}
              icon={<Table2 size={14} aria-hidden />}
              label="جدول"
              controls={panelId}
            />
          </div>
        }
      />

      {series && series.length > 1 ? (
        <ul className="flex flex-wrap items-center gap-x-4 gap-y-1.5 px-4 pt-3 sm:px-5">
          {series.map((entry) => (
            <li key={entry.label} className="flex items-center gap-1.5 text-xs text-ink-2">
              <span
                aria-hidden
                className="h-2.5 w-2.5 shrink-0 rounded-[2px]"
                style={{ background: entry.color }}
              />
              {entry.label}
            </li>
          ))}
        </ul>
      ) : null}

      <div id={panelId} className={cn('px-4 pt-2 pb-4 sm:px-5', refetching && 'is-refetching')}>
        {view === 'chart' ? children : <DataTable table={table} />}
      </div>
    </Card>
  )
}

function ViewTab({
  active,
  onClick,
  icon,
  label,
  controls,
}: {
  active: boolean
  onClick: () => void
  icon: ReactNode
  label: string
  controls: string
}) {
  return (
    <button
      type="button"
      onClick={onClick}
      aria-pressed={active}
      aria-controls={controls}
      className={cn(
        'inline-flex h-7 cursor-pointer items-center gap-1.5 rounded-md px-2 text-xs font-medium transition-colors',
        active ? 'bg-surface-2 text-ink' : 'text-muted hover:text-ink',
      )}
    >
      {icon}
      {label}
    </button>
  )
}

function DataTable({ table }: { table: TableView }) {
  return (
    <div className="max-h-72 overflow-auto rounded-lg border border-hairline">
      <table className="w-full border-collapse text-xs">
        <thead className="sticky top-0 bg-surface-2">
          <tr>
            {table.columns.map((column) => (
              <th
                key={column}
                scope="col"
                className="border-b border-hairline px-3 py-2 text-start font-medium text-ink-2 whitespace-nowrap"
              >
                {column}
              </th>
            ))}
          </tr>
        </thead>
        <tbody>
          {table.rows.map((row, rowIndex) => (
            <tr key={rowIndex} className="glass-row border-b border-hairline last:border-0">
              {row.map((cell, cellIndex) => (
                <td
                  key={cellIndex}
                  className={cn(
                    'px-3 py-1.5 whitespace-nowrap',
                    cellIndex === 0 ? 'text-ink-2' : 'tnum text-ink',
                  )}
                >
                  {cell}
                </td>
              ))}
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  )
}
