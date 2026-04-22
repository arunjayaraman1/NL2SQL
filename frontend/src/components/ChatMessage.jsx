import { useEffect, useMemo, useState } from 'react'
import { Bar, Line, Pie } from 'react-chartjs-2'
import {
  ArcElement,
  BarElement,
  CategoryScale,
  Chart as ChartJS,
  Legend,
  LineElement,
  LinearScale,
  PointElement,
  Title,
  Tooltip
} from 'chart.js'

ChartJS.register(
  CategoryScale,
  LinearScale,
  BarElement,
  LineElement,
  PointElement,
  ArcElement,
  Title,
  Tooltip,
  Legend
)

const CHART_COLORS = [
  '#6366f1', '#8b5cf6', '#ec4899', '#f43f5e', '#f97316',
  '#eab308', '#22c55e', '#14b8a6', '#0ea5e9', '#10b981'
]

const EMPTY_GRAPH_SPEC = { chart_type: 'none', x_key: '', y_keys: [] }

const numberFromValue = (value) => {
  if (value === null || value === undefined || value === '') return null
  if (typeof value === 'number' && Number.isFinite(value)) return value
  if (typeof value === 'string') {
    const normalized = value.trim().replaceAll(',', '')
    if (!normalized) return null
    const parsed = Number(normalized)
    return Number.isFinite(parsed) ? parsed : null
  }
  return null
}

const isDateLikeValue = (value) => {
  if (typeof value !== 'string') return false
  if (!value.trim()) return false
  const parsed = Date.parse(value)
  return Number.isFinite(parsed)
}

const getColumnValues = (data, column) => data.map((row) => row?.[column])

const isNumericColumn = (data, column) => {
  const values = getColumnValues(data, column).filter((value) => value !== null && value !== undefined)
  if (values.length === 0) return false
  const hits = values.filter((value) => numberFromValue(value) !== null).length
  return hits >= Math.max(1, Math.floor(values.length * 0.7))
}

const isTemporalColumn = (data, column) => {
  const lower = column.toLowerCase()
  if (['date', 'time', 'month', 'year', 'day'].some((token) => lower.includes(token))) {
    return true
  }
  const values = getColumnValues(data, column).filter((value) => value !== null && value !== undefined).slice(0, 20)
  if (values.length === 0) return false
  const hits = values.filter((value) => isDateLikeValue(value)).length
  return hits >= Math.max(1, Math.floor(values.length * 0.6))
}

const validateGraphSpec = (graphSpec, columns, data) => {
  if (!graphSpec || typeof graphSpec !== 'object') return null
  const chartType = String(graphSpec.chart_type || '').toLowerCase()
  if (!['bar', 'line', 'pie', 'none'].includes(chartType)) return null
  if (chartType === 'none') return EMPTY_GRAPH_SPEC

  const xKey = String(graphSpec.x_key || '')
  if (!columns.includes(xKey)) return null

  const inputY = Array.isArray(graphSpec.y_keys) ? graphSpec.y_keys : []
  const yKeys = [...new Set(inputY.filter((key) => columns.includes(key) && isNumericColumn(data, key)))]
  if (yKeys.length === 0) return null

  return {
    chart_type: chartType,
    x_key: xKey,
    y_keys: chartType === 'pie' ? yKeys.slice(0, 1) : yKeys.slice(0, 3)
  }
}

const buildHeuristicGraphSpec = (columns, data) => {
  if (!data?.length || !columns?.length) return EMPTY_GRAPH_SPEC
  const numericColumns = columns.filter((column) => isNumericColumn(data, column))
  if (!numericColumns.length) return EMPTY_GRAPH_SPEC

  const xCandidates = columns.filter((column) => !numericColumns.includes(column))
  if (!xCandidates.length) return EMPTY_GRAPH_SPEC
  const xKey = xCandidates[0]

  let chartType = 'bar'
  if (isTemporalColumn(data, xKey)) {
    chartType = 'line'
  } else if (numericColumns.length === 1) {
    const distinctX = new Set(data.map((row) => String(row?.[xKey] ?? ''))).size
    if (distinctX >= 2 && distinctX <= 8) {
      chartType = 'pie'
    }
  }

  const yKeys = chartType === 'pie' ? numericColumns.slice(0, 1) : numericColumns.slice(0, 3)
  return { chart_type: chartType, x_key: xKey, y_keys: yKeys }
}

const buildChartRows = (rows, xKey, yKey, sortMode) => {
  const grouped = new Map()
  rows.forEach((row) => {
    const label = row?.[xKey] === null || row?.[xKey] === undefined ? 'N/A' : String(row[xKey])
    const numeric = numberFromValue(row?.[yKey])
    if (numeric === null) return
    grouped.set(label, (grouped.get(label) || 0) + numeric)
  })

  const items = Array.from(grouped.entries()).map(([label, value]) => ({ label, value }))
  if (sortMode === 'asc') {
    items.sort((a, b) => a.value - b.value)
  } else if (sortMode === 'desc') {
    items.sort((a, b) => b.value - a.value)
  } else {
    items.sort((a, b) => a.label.localeCompare(b.label))
  }
  return items
}

const escapeCsvValue = (value) => {
  const text = value === null || value === undefined ? '' : String(value)
  return `"${text.replaceAll('"', '""')}"`
}

const buildCsv = (rows, columns) => {
  if (!columns?.length) return ''
  const header = columns.map((column) => escapeCsvValue(column)).join(',')
  const body = rows.map((row) => (
    columns.map((column) => escapeCsvValue(row?.[column])).join(',')
  )).join('\n')
  return `${header}\n${body}`
}

const formatTableCellValue = (value) => {
  if (value === null || value === undefined) return '—'
  if (typeof value === 'object') return JSON.stringify(value)
  return String(value)
}

const downloadTextFile = (filename, content, mimeType) => {
  const blob = new Blob([content], { type: mimeType })
  const objectUrl = URL.createObjectURL(blob)
  const link = document.createElement('a')
  link.href = objectUrl
  link.download = filename
  link.click()
  URL.revokeObjectURL(objectUrl)
}

function ChatMessage({ message, onSuggestionClick }) {
  const isUser = message.type === 'user'
  const isError = message.error && !message.loading
  const columns = useMemo(() => {
    if (Array.isArray(message.columns) && message.columns.length) {
      return message.columns
    }
    return message.data?.length ? Object.keys(message.data[0]) : []
  }, [message.columns, message.data])

  const resolvedGraphSpec = useMemo(() => {
    if (!message.data?.length) return EMPTY_GRAPH_SPEC
    const llmSpec = validateGraphSpec(message.graph_spec, columns, message.data)
    return llmSpec || buildHeuristicGraphSpec(columns, message.data)
  }, [message.graph_spec, columns, message.data])

  const [viewMode, setViewMode] = useState('auto')
  const [selectedMetric, setSelectedMetric] = useState('')
  const [sortMode, setSortMode] = useState('desc')
  const [topN, setTopN] = useState(20)

  useEffect(() => {
    setViewMode('auto')
    setSortMode('desc')
    setTopN(20)
    setSelectedMetric(resolvedGraphSpec.y_keys?.[0] || '')
  }, [message.id, resolvedGraphSpec.y_keys])

  const effectiveChartType = viewMode === 'auto' ? resolvedGraphSpec.chart_type : viewMode
  const effectiveMetric = selectedMetric || resolvedGraphSpec.y_keys?.[0] || ''

  const chartRows = useMemo(() => {
    if (!message.data?.length || !resolvedGraphSpec.x_key || !effectiveMetric) return []
    const rows = buildChartRows(message.data, resolvedGraphSpec.x_key, effectiveMetric, sortMode)
    return rows.slice(0, topN)
  }, [message.data, resolvedGraphSpec.x_key, effectiveMetric, sortMode, topN])

  const chartData = useMemo(() => {
    if (!chartRows.length) return null
    const labels = chartRows.map((row) => row.label)
    const values = chartRows.map((row) => row.value)
    return {
      labels,
      datasets: [
        {
          label: effectiveMetric.replaceAll('_', ' '),
          data: values,
          backgroundColor: labels.map((_, index) => CHART_COLORS[index % CHART_COLORS.length] + '99'),
          borderColor: labels.map((_, index) => CHART_COLORS[index % CHART_COLORS.length]),
          borderWidth: 2,
          pointRadius: 3,
          tension: 0.2
        }
      ]
    }
  }, [chartRows, effectiveMetric])

  const chartOptions = useMemo(() => ({
    responsive: true,
    maintainAspectRatio: false,
    interaction: {
      mode: 'index',
      intersect: false
    },
    plugins: {
      legend: {
        display: true,
        position: effectiveChartType === 'pie' ? 'right' : 'top'
      },
      tooltip: {
        usePointStyle: true
      }
    }
  }), [effectiveChartType])

  const handleDownloadCsv = () => {
    const csv = buildCsv(message.data || [], columns || [])
    if (!csv) return
    downloadTextFile(`query-results-${message.id}.csv`, csv, 'text/csv;charset=utf-8;')
  }

  const handleDownloadJson = () => {
    const json = JSON.stringify(message.data || [], null, 2)
    downloadTextFile(`query-results-${message.id}.json`, json, 'application/json;charset=utf-8;')
  }

  const renderSuggestions = () => {
    const suggestions = Array.isArray(message.suggested_inputs) ? message.suggested_inputs : []
    if (!message.needs_clarification || suggestions.length === 0) return null
    return (
      <div className="bg-amber-50 border border-amber-200 rounded-lg p-3">
        <p className="text-xs font-medium text-amber-800 mb-2">
          Try one of these:
        </p>
        <div className="flex flex-wrap gap-2">
          {suggestions.slice(0, 3).map((suggestion, idx) => (
            <button
              key={`${message.id}-suggestion-${idx}`}
              type="button"
              onClick={() => onSuggestionClick?.(suggestion)}
              className="px-2 py-1 text-xs rounded-md border border-amber-300 bg-white text-amber-800 hover:bg-amber-100 text-left"
            >
              {suggestion}
            </button>
          ))}
        </div>
      </div>
    )
  }

  const renderContent = () => {
    if (message.loading) {
      const progressSteps = Array.isArray(message.progress_steps) ? message.progress_steps : []
      return (
        <div className="space-y-3">
          <div className="flex items-center gap-2">
            <div className="flex gap-1">
              <span className="w-2 h-2 bg-gray-400 rounded-full animate-bounce" style={{ animationDelay: '0ms' }} />
              <span className="w-2 h-2 bg-gray-400 rounded-full animate-bounce" style={{ animationDelay: '150ms' }} />
              <span className="w-2 h-2 bg-gray-400 rounded-full animate-bounce" style={{ animationDelay: '300ms' }} />
            </div>
            <span className="text-gray-500 text-sm">Processing your question...</span>
          </div>

          {progressSteps.length > 0 && (
            <div className="bg-gray-50 border border-gray-200 rounded-lg p-3">
              <ul className="space-y-1">
                {progressSteps.map((step) => (
                  <li key={step.step_id} className="text-xs flex items-center gap-2">
                    <span className={step.status === 'completed' ? 'text-green-600 font-semibold' : 'text-gray-400'}>
                      {step.status === 'completed' ? '✓' : '•'}
                    </span>
                    <span className={step.status === 'completed' ? 'text-gray-700' : 'text-gray-500'}>
                      {step.label}
                    </span>
                  </li>
                ))}
              </ul>
            </div>
          )}
        </div>
      )
    }

    if (isError) {
      return (
        <div className="space-y-3">
          <div className="text-red-500 text-sm">
            <span className="font-semibold">Error:</span> {message.error}
          </div>
          {renderSuggestions()}
        </div>
      )
    }

    if (isUser) {
      return <p className="text-white">{message.text}</p>
    }

    if (!message.summary && !message.sql_query && !message.data && message.text) {
      return (
        <div className="space-y-3">
          <p className="text-gray-700">{message.text}</p>
          {renderSuggestions()}
        </div>
      )
    }

    return (
      <div className="space-y-4">
        {message.summary && (
          <div className="bg-indigo-50 rounded-lg p-3 text-sm text-indigo-800">
            <p className="font-medium mb-1">Summary:</p>
            <p>{message.summary}</p>
          </div>
        )}

        {renderSuggestions()}

        {message.sql_query && (
          <div className="bg-gray-900 rounded-lg p-3 overflow-x-auto">
            <p className="text-xs text-gray-400 mb-2 font-medium">SQL Query:</p>
            <pre className="text-green-400 text-xs font-mono whitespace-pre-wrap">
              {message.sql_query}
            </pre>
          </div>
        )}

        {message.data && message.data.length > 0 && (
          <div>
            <div className="flex items-center justify-between mb-2">
              <p className="text-xs text-gray-500 font-medium">
                {message.row_count || message.data.length} results
              </p>
              <div className="flex items-center gap-2">
                <button
                  type="button"
                  onClick={handleDownloadCsv}
                  className="px-2 py-1 text-xs rounded-md border border-gray-300 bg-white text-gray-700 hover:bg-gray-50"
                >
                  Download CSV
                </button>
                <button
                  type="button"
                  onClick={handleDownloadJson}
                  className="px-2 py-1 text-xs rounded-md border border-gray-300 bg-white text-gray-700 hover:bg-gray-50"
                >
                  Download JSON
                </button>
              </div>
            </div>
            {resolvedGraphSpec.chart_type !== 'none' && (
              <div className="mb-3 bg-gray-50 border border-gray-200 rounded-lg p-3">
                <div className="flex flex-wrap items-center gap-2 mb-3">
                  {['auto', 'bar', 'line', 'pie', 'table'].map((mode) => (
                    <button
                      key={mode}
                      type="button"
                      onClick={() => setViewMode(mode)}
                      className={`px-2 py-1 text-xs rounded-md border ${
                        viewMode === mode
                          ? 'bg-indigo-600 text-white border-indigo-600'
                          : 'bg-white text-gray-600 border-gray-300'
                      }`}
                    >
                      {mode.toUpperCase()}
                    </button>
                  ))}

                  {resolvedGraphSpec.y_keys.length > 1 && (
                    <select
                      value={effectiveMetric}
                      onChange={(e) => setSelectedMetric(e.target.value)}
                      className="px-2 py-1 text-xs border border-gray-300 rounded-md bg-white"
                    >
                      {resolvedGraphSpec.y_keys.map((metric) => (
                        <option key={metric} value={metric}>
                          {metric.replaceAll('_', ' ')}
                        </option>
                      ))}
                    </select>
                  )}

                  <select
                    value={sortMode}
                    onChange={(e) => setSortMode(e.target.value)}
                    className="px-2 py-1 text-xs border border-gray-300 rounded-md bg-white"
                  >
                    <option value="desc">Sort: High to low</option>
                    <option value="asc">Sort: Low to high</option>
                    <option value="label">Sort: Label</option>
                  </select>

                  <select
                    value={topN}
                    onChange={(e) => setTopN(Number(e.target.value))}
                    className="px-2 py-1 text-xs border border-gray-300 rounded-md bg-white"
                  >
                    <option value={10}>Top 10</option>
                    <option value={20}>Top 20</option>
                    <option value={50}>Top 50</option>
                  </select>
                </div>

                {viewMode !== 'table' && chartData && effectiveChartType !== 'none' && (
                  <div className="h-64">
                    {effectiveChartType === 'line' && <Line data={chartData} options={chartOptions} />}
                    {effectiveChartType === 'bar' && <Bar data={chartData} options={chartOptions} />}
                    {effectiveChartType === 'pie' && <Pie data={chartData} options={chartOptions} />}
                  </div>
                )}
              </div>
            )}
            <div className="bg-white rounded-lg border border-gray-200 overflow-hidden">
              <table className="w-full text-sm">
                <thead className="bg-gray-50">
                  <tr>
                    {columns?.map((col, i) => (
                      <th key={i} className="px-3 py-2 text-left text-xs font-semibold text-gray-600 uppercase tracking-wider">
                        {col.replace(/_/g, ' ')}
                      </th>
                    ))}
                  </tr>
                </thead>
                <tbody className="divide-y divide-gray-100">
                  {message.data.map((row, i) => (
                    <tr key={i} className="hover:bg-gray-50">
                      {columns?.map((col, j) => (
                        <td key={j} className="px-3 py-2 text-gray-700 text-xs">
                          {formatTableCellValue(row[col])}
                        </td>
                      ))}
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </div>
        )}
      </div>
    )
  }

  return (
    <div className={`flex ${isUser ? 'justify-end' : 'justify-start'} animate-fadeIn`}>
      <div className={`flex gap-3 max-w-[80%] ${isUser ? 'flex-row-reverse' : ''}`}>
        <div className={`flex-shrink-0 w-8 h-8 rounded-full flex items-center justify-center ${
          isUser ? 'bg-indigo-600' : 'bg-gray-200'
        }`}>
          {isUser ? (
            <svg className="w-4 h-4 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z" />
            </svg>
          ) : (
            <span className="text-lg">🤖</span>
          )}
        </div>
        
        <div className={`rounded-2xl px-4 py-3 ${
          isUser 
            ? 'bg-indigo-600 text-white rounded-br-md' 
            : isError
              ? 'bg-red-50 text-red-800 border border-red-200 rounded-bl-md'
              : 'bg-white text-gray-800 border border-gray-200 rounded-bl-md shadow-sm'
        }`}>
          {renderContent()}
        </div>
      </div>
    </div>
  )
}

export default ChatMessage
