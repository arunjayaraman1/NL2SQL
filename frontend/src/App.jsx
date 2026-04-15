import { useState, useRef, useEffect } from 'react'
import {
  Chart as ChartJS,
  CategoryScale,
  LinearScale,
  BarElement,
  LineElement,
  PointElement,
  ArcElement,
  Title,
  Tooltip,
  Legend,
} from 'chart.js'
import { Bar, Line, Pie } from 'react-chartjs-2'
import QueryInput from './components/QueryInput'
import ResultsTable from './components/ResultsTable'
import LoadingSpinner from './components/LoadingSpinner'
import axios from 'axios'

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

function App() {
  const [messages, setMessages] = useState([])
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState('')
  const [selectedDb, setSelectedDb] = useState('hr')
  const [databases, setDatabases] = useState([])
  const inputRef = useRef(null)
  const messagesEndRef = useRef(null)

  useEffect(() => {
    axios.get('/api/databases')
      .then(res => setDatabases(res.data.databases || []))
      .catch(() => setDatabases([]))
  }, [])

  useEffect(() => {
    if (messages.length > 0) {
      messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' })
    }
  }, [messages])

  const handleSubmit = async (questionText) => {
    if (!questionText.trim()) return
    
    setLoading(true)
    setError('')
    
    const messageId = Date.now()
    const tempMessage = {
      id: messageId,
      question: questionText,
      sql_query: '',
      columns: [],
      data: [],
      summary: '',
      loading: true,
      error: '',
      showGraph: true,
    }
    
    setMessages(prev => [...prev, tempMessage])
    
    try {
      const response = await axios.post('/api/query', { 
        question: questionText,
        db_type: selectedDb
      })
      
      setMessages(prev => prev.map(msg => 
        msg.id === messageId 
          ? { ...msg, loading: false, ...response.data }
          : msg
      ))
    } catch (err) {
      setMessages(prev => prev.map(msg => 
        msg.id === messageId 
          ? { ...msg, loading: false, error: err.response?.data?.error || err.message || 'An error occurred' }
          : msg
      ))
    } finally {
      setLoading(false)
    }
  }

  const toggleGraph = (msgId) => {
    setMessages(prev => prev.map(msg => 
      msg.id === msgId 
        ? { ...msg, showGraph: !msg.showGraph }
        : msg
    ))
  }

  const scrollToInput = () => {
    inputRef.current?.focus()
    window.scrollTo({ top: document.body.scrollHeight, behavior: 'smooth' })
  }

  const clearChat = () => {
    setMessages([])
    setError('')
  }

  const getColumnTypes = (columns, data) => {
    const labelCols = []
    const valueCols = []
    
    if (!data || data.length === 0 || columns.length === 0) {
      return { labelCols: columns.slice(0, 1), valueCols: columns.slice(1) }
    }
    
    columns.forEach(col => {
      let numberCount = 0
      let total = 0
      
      data.forEach(row => {
        const val = row[col]
        if (val !== null && val !== undefined && val !== '') {
          total++
          const parsed = parseFloat(val)
          if (!isNaN(parsed)) numberCount++
        }
      })
      
      if (total > 0 && numberCount / total > 0.7) {
        valueCols.push(col)
      } else {
        labelCols.push(col)
      }
    })
    
    if (labelCols.length === 0 && columns.length > 0) {
      labelCols.push(columns[0])
    }
    
    return { labelCols, valueCols }
  }

  const getChartType = (labelCols, valueCols, data) => {
    if (!data || data.length === 0) return null
    
    const hasDate = labelCols.some(col => 
      col.toLowerCase().includes('date') || 
      col.toLowerCase().includes('year') || 
      col.toLowerCase().includes('month')
    )
    
    if (hasDate && valueCols.length >= 1) {
      return 'LineChart'
    }
    
    return 'BarChart'
  }

  const getNumericValue = (value) => {
    if (value === null || value === undefined || value === '') return 0
    if (typeof value === 'number') return value
    const parsed = parseFloat(value)
    return isNaN(parsed) ? 0 : parsed
  }

  const renderGraph = (message) => {
    const { columns, data } = message
    
    if (!data || data.length === 0) return null
    
    const { labelCols, valueCols } = getColumnTypes(columns, data)
    
    if (valueCols.length === 0) return null
    
    const chartType = getChartType(labelCols, valueCols, data)
    if (!chartType) return null
    
    const labelKey = labelCols[0]
    const labels = data.map(row => String(row[labelKey] ?? 'Unknown'))
    
    if (chartType === 'LineChart') {
      const datasets = valueCols.map((col, idx) => {
        const values = data.map(row => getNumericValue(row[col]))
        
        return {
          label: col,
          data: values,
          borderColor: CHART_COLORS[idx % CHART_COLORS.length],
          backgroundColor: CHART_COLORS[idx % CHART_COLORS.length],
          tension: 0.3,
          fill: false,
          pointRadius: 4,
          pointHoverRadius: 6,
        }
      })
      
      const chartData = { labels, datasets }
      
      return (
        <Line 
          data={chartData} 
          options={{
            responsive: true,
            maintainAspectRatio: false,
            plugins: {
              legend: { position: 'bottom' },
              tooltip: { enabled: true }
            },
            scales: {
              x: { ticks: { maxRotation: 45 } },
              y: { beginAtZero: true }
            }
          }}
        />
      )
    }
    
    const datasets = valueCols.map((col, idx) => {
      const values = data.map(row => getNumericValue(row[col]))
      
      return {
        label: col,
        data: values,
        backgroundColor: CHART_COLORS[idx % CHART_COLORS.length],
        borderColor: CHART_COLORS[idx % CHART_COLORS.length],
        borderWidth: 1,
        borderRadius: 4,
      }
    })
    
    const chartData = { labels, datasets }
    
    return (
      <Bar 
        data={chartData} 
        options={{
          responsive: true,
          maintainAspectRatio: false,
          plugins: {
            legend: { position: 'bottom' },
            tooltip: { enabled: true }
          },
          scales: {
            x: { 
              ticks: { maxRotation: 45 },
              grid: { display: false }
            },
            y: { 
              beginAtZero: true,
              grid: { color: '#f0f0f0' }
            }
          }
        }}
      />
    )
  }

  return (
    <div className='min-h-screen bg-gradient-to-br from-slate-50 to-indigo-50 pb-24'>
      <header className='bg-gradient-to-r from-indigo-600 to-purple-600 text-white py-6 px-4 shadow-lg'>
        <div className='max-w-6xl mx-auto flex items-center justify-between'>
          <div className='flex items-center gap-3'>
            <span className='text-3xl'>📊</span>
            <div>
              <h1 className='text-2xl font-bold'>NL2SQL</h1>
              <p className='text-indigo-100 text-sm'>Transform natural language into SQL</p>
            </div>
          </div>
          <div className='flex items-center gap-4'>
            <select
              value={selectedDb}
              onChange={(e) => setSelectedDb(e.target.value)}
              className='px-3 py-2 bg-white/20 text-white rounded-lg text-sm font-medium border border-white/30 focus:outline-none focus:ring-2 focus:ring-white/50'
            >
              {databases.map(db => (
                <option key={db.id} value={db.id} className='text-gray-800'>
                  {db.name} ({db.table_count} tables)
                </option>
              ))}
            </select>
          </div>
            <div className='flex items-center gap-3'>
            {messages.length > 0 && (
              <button 
                onClick={scrollToInput}
                className='px-4 py-2 bg-white/20 hover:bg-white/30 rounded-lg text-sm font-medium transition-colors'
              >
                + New Question
              </button>
            )}
            {messages.length > 0 && (
              <button 
                onClick={clearChat}
                className='px-4 py-2 bg-white/20 hover:bg-white/30 rounded-lg text-sm font-medium transition-colors'
              >
                Clear Chat
              </button>
            )}
          </div>
        </div>
      </header>

      <main className='max-w-6xl mx-auto px-4 py-6'>
        {error && (
          <div className='bg-red-50 border border-red-200 text-red-700 px-6 py-4 rounded-xl flex items-center gap-3 mb-6'>
            <span className='text-xl'>⚠️</span>
            <p>{error}</p>
          </div>
        )}
        
        <div className='space-y-6'>
          {messages.map((message, idx) => (
            <div key={message.id} className='space-y-4'>
              <div className='flex items-start gap-3'>
                <div className='w-8 h-8 rounded-full bg-indigo-600 flex items-center justify-center text-white font-bold text-sm flex-shrink-0'>
                  {idx + 1}
                </div>
                <div className='flex-1 bg-white rounded-2xl shadow-sm p-4'>
                  <p className='text-gray-800 font-medium'>{message.question}</p>
                </div>
              </div>
              
              {message.loading ? (
                <div className='ml-11'>
                  <LoadingSpinner />
                </div>
              ) : message.error ? (
                <div className='ml-11 bg-red-50 border border-red-200 text-red-700 px-6 py-4 rounded-xl'>
                  <p>{message.error}</p>
                </div>
              ) : (
                <div className='ml-11 space-y-4'>
                  {message.summary && (
                    <div className='bg-indigo-50 border border-indigo-100 rounded-xl p-4'>
                      <pre className='text-indigo-800 whitespace-pre-wrap text-sm'>{message.summary}</pre>
                    </div>
                  )}
                  
                  <div className='bg-slate-800 rounded-xl p-4'>
                    <pre className='text-slate-100 font-mono text-sm whitespace-pre-wrap'>{message.sql_query}</pre>
                  </div>
                  
                  {message.data.length > 0 && (
                    <>
                      <div className='flex items-center justify-between'>
                        <h3 className='text-lg font-semibold text-gray-800'>
                          Results ({message.data.length} rows)
                        </h3>
                        <label className='flex items-center gap-2 cursor-pointer text-gray-600 text-sm'>
                          <input 
                            type='checkbox' 
                            checked={message.showGraph} 
                            onChange={() => toggleGraph(message.id)}
                            className='w-4 h-4 text-indigo-600 rounded focus:ring-indigo-500'
                          />
                          <span>Show Graph</span>
                        </label>
                      </div>
                      
                      <ResultsTable columns={message.columns} data={message.data} />
                      
                      {message.showGraph && (
                        <div className='bg-white rounded-2xl shadow-sm border border-gray-100 p-4 min-h-[400px]'>
                          {renderGraph(message)}
                        </div>
                      )}
                    </>
                  )}
                </div>
              )}
            </div>
          ))}
        </div>
        
        <div ref={messagesEndRef} />
      </main>
      
      <div className='fixed bottom-0 left-0 right-0 bg-white border-t border-gray-200 shadow-lg'>
        <div className='max-w-6xl mx-auto px-4 py-4'>
          <QueryInput 
            ref={inputRef}
            onSubmit={handleSubmit} 
            loading={loading} 
          />
        </div>
      </div>
    </div>
  )
}

export default App