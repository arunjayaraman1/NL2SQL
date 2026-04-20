import { useState, useRef, useEffect } from 'react'
import ChatMessage from './components/ChatMessage'
import axios from 'axios'

const PROGRESS_STEPS = [
  { step_id: 'schema_profile_loaded', label: 'Schema/profile loaded' },
  { step_id: 'sql_drafted', label: 'SQL drafted' },
  { step_id: 'schema_linking_complete', label: 'Schema linking complete' },
  { step_id: 'sql_validated', label: 'SQL validated' },
  { step_id: 'query_executed', label: 'Query executed' },
  { step_id: 'summary_generated', label: 'Summary generated' },
  { step_id: 'chart_recommendation_generated', label: 'Chart recommendation generated' }
]

const createProgressSteps = () => PROGRESS_STEPS.map((step) => ({ ...step, status: 'pending' }))

const parseSseEvent = (rawEvent) => {
  const lines = rawEvent.split('\n').map((line) => line.trim()).filter(Boolean)
  const eventLine = lines.find((line) => line.startsWith('event:'))
  const dataLine = lines.find((line) => line.startsWith('data:'))
  if (!eventLine || !dataLine) return null

  const event = eventLine.slice('event:'.length).trim()
  const rawData = dataLine.slice('data:'.length).trim()
  try {
    return { event, data: JSON.parse(rawData) }
  } catch {
    return null
  }
}

function App() {
  const [messages, setMessages] = useState([
    {
      id: 0,
      type: 'assistant',
      text: 'Hello! I\'m your NL2SQL assistant. Ask me questions about your database in plain English, and I\'ll convert them to SQL queries.',
      loading: false,
      error: null,
      needs_clarification: false,
      suggested_inputs: []
    }
  ])
  const [input, setInput] = useState('')
  const [loading, setLoading] = useState(false)
  const [selectedDb, setSelectedDb] = useState('')
  const [databases, setDatabases] = useState([])
  const [startupSuggestions, setStartupSuggestions] = useState([])
  const messagesEndRef = useRef(null)
  const inputRef = useRef(null)

  const applySuggestion = (suggestionText) => {
    setInput(suggestionText || '')
    inputRef.current?.focus()
  }

  useEffect(() => {
    axios.get('/api/databases')
      .then(res => {
        const list = res.data.databases || []
        setDatabases(list)
        if (list.length > 0) {
          setSelectedDb(prev => prev || list[0].id)
        }
      })
      .catch(() => setDatabases([]))
  }, [])

  useEffect(() => {
    if (!selectedDb) {
      setStartupSuggestions([])
      return
    }

    let cancelled = false
    axios.get('/api/suggestions', { params: { db_id: selectedDb } })
      .then((res) => {
        if (cancelled) return
        const suggestions = Array.isArray(res.data?.suggested_inputs)
          ? res.data.suggested_inputs.slice(0, 3)
          : []
        setStartupSuggestions(suggestions)
      })
      .catch(() => {
        if (!cancelled) setStartupSuggestions([])
      })

    return () => {
      cancelled = true
    }
  }, [selectedDb])

  useEffect(() => {
    setMessages((prev) => prev.map((msg) =>
      msg.id === 0
        ? {
            ...msg,
            needs_clarification: startupSuggestions.length > 0,
            suggested_inputs: startupSuggestions
          }
        : msg
    ))
  }, [startupSuggestions])

  useEffect(() => {
    messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' })
  }, [messages])

  const handleSubmit = async (e) => {
    e.preventDefault()
    if (!input.trim() || loading) return

    const questionText = input.trim()
    setInput('')
    setLoading(true)

    const userMessage = {
      id: Date.now(),
      type: 'user',
      text: questionText,
      loading: false,
      error: null
    }

    const assistantMessage = {
      id: Date.now() + 1,
      type: 'assistant',
      text: '',
      loading: true,
      error: null,
      summary: null,
      sql_query: null,
      columns: [],
      data: [],
      row_count: 0,
      graph_hint: 'none',
      graph_spec: { chart_type: 'none', x_key: '', y_keys: [] },
      progress_steps: createProgressSteps(),
      needs_clarification: false,
      suggested_inputs: []
    }

    setMessages(prev => [...prev, userMessage, assistantMessage])

    try {
      const response = await fetch('/api/query/stream', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          question: questionText,
          db_id: selectedDb
        })
      })

      if (!response.ok || !response.body) {
        const fallback = await axios.post('/api/query', {
          question: questionText,
          db_id: selectedDb
        })
        const fallbackData = fallback.data || {}
        setMessages(prev => prev.map(msg =>
          msg.id === assistantMessage.id
            ? {
                ...msg,
                loading: false,
                error: fallbackData.error || null,
                summary: fallbackData.summary,
                sql_query: fallbackData.sql_query,
                columns: fallbackData.columns,
                data: fallbackData.data,
                row_count: fallbackData.data?.length || 0,
                graph_hint: fallbackData.graph_hint || 'auto',
                graph_spec: fallbackData.graph_spec || { chart_type: 'none', x_key: '', y_keys: [] },
                needs_clarification: Boolean(fallbackData.needs_clarification),
                suggested_inputs: Array.isArray(fallbackData.suggested_inputs) ? fallbackData.suggested_inputs : []
              }
            : msg
        ))
        return
      }

      const reader = response.body.getReader()
      const decoder = new TextDecoder()
      let buffer = ''
      let finalData = null

      while (true) {
        const { value, done } = await reader.read()
        if (done) break
        buffer += decoder.decode(value, { stream: true })

        let separatorIndex = buffer.indexOf('\n\n')
        while (separatorIndex !== -1) {
          const rawEvent = buffer.slice(0, separatorIndex).trim()
          buffer = buffer.slice(separatorIndex + 2)
          separatorIndex = buffer.indexOf('\n\n')

          if (!rawEvent) continue
          const parsed = parseSseEvent(rawEvent)
          if (!parsed) continue

          if (parsed.event === 'progress') {
            const stepId = parsed.data?.step_id
            const status = parsed.data?.status || 'completed'
            setMessages(prev => prev.map(msg =>
              msg.id === assistantMessage.id
                ? {
                    ...msg,
                    progress_steps: (msg.progress_steps || []).map((step) =>
                      step.step_id === stepId ? { ...step, status } : step
                    )
                  }
                : msg
            ))
          } else if (parsed.event === 'result') {
            finalData = parsed.data
          } else if (parsed.event === 'error') {
            throw new Error(parsed.data?.error || 'An error occurred')
          }
        }
      }

      if (!finalData) {
        throw new Error('Stream ended before final result')
      }

      setMessages(prev => prev.map(msg =>
        msg.id === assistantMessage.id
          ? {
              ...msg,
              loading: false,
              error: finalData.error || null,
              summary: finalData.summary || null,
              sql_query: finalData.sql_query || null,
              columns: finalData.columns || [],
              data: finalData.data || [],
              row_count: finalData.data?.length || 0,
              graph_hint: finalData.graph_hint || 'auto',
              graph_spec: finalData.graph_spec || { chart_type: 'none', x_key: '', y_keys: [] },
              needs_clarification: Boolean(finalData.needs_clarification),
              suggested_inputs: Array.isArray(finalData.suggested_inputs) ? finalData.suggested_inputs : [],
              progress_steps: (msg.progress_steps || []).map((step) => ({ ...step, status: 'completed' }))
            }
          : msg
      ))
    } catch (err) {
      setMessages(prev => prev.map(msg =>
        msg.id === assistantMessage.id
          ? { ...msg, loading: false, error: err.response?.data?.error || err.message || 'An error occurred' }
          : msg
      ))
    } finally {
      setLoading(false)
      inputRef.current?.focus()
    }
  }

  const clearChat = () => {
    setMessages([{
      id: Date.now(),
      type: 'assistant',
      text: 'Chat cleared! Ask me a new question about your database.',
      loading: false,
      error: null,
      needs_clarification: startupSuggestions.length > 0,
      suggested_inputs: startupSuggestions
    }])
  }

  return (
    <div className="h-screen flex flex-col bg-gray-50">
      {/* Header */}
      <header className="bg-white border-b border-gray-200 px-4 py-3 flex items-center justify-between flex-shrink-0">
        <div className="flex items-center gap-3">
          <div className="w-10 h-10 bg-indigo-600 rounded-xl flex items-center justify-center">
            <span className="text-xl">🤖</span>
          </div>
          <div>
            <h1 className="text-lg font-semibold text-gray-900">NL2SQL Assistant</h1>
            <p className="text-xs text-gray-500">Natural Language to SQL</p>
          </div>
        </div>
        
        <div className="flex items-center gap-3">
          <select
            value={selectedDb}
            onChange={(e) => setSelectedDb(e.target.value)}
            className="px-3 py-2 bg-gray-100 text-gray-700 rounded-lg text-sm font-medium border-0 focus:outline-none focus:ring-2 focus:ring-indigo-500"
          >
            {databases.map(db => (
              <option key={db.id} value={db.id}>
                {db.name}
              </option>
            ))}
          </select>
          
          {messages.length > 2 && (
            <button
              onClick={clearChat}
              className="px-3 py-2 text-gray-500 hover:text-gray-700 hover:bg-gray-100 rounded-lg text-sm transition-colors"
            >
              Clear
            </button>
          )}
        </div>
      </header>

      {/* Messages */}
      <main className="flex-1 overflow-y-auto">
        <div className="w-full px-6 py-6 space-y-6">
          {messages.map((message) => (
            <ChatMessage
              key={message.id}
              message={message}
              onSuggestionClick={applySuggestion}
            />
          ))}
          <div ref={messagesEndRef} />
        </div>
      </main>

      {/* Input */}
      <footer className="bg-white border-t border-gray-200 px-4 py-4 flex-shrink-0">
        <div className="max-w-3xl mx-auto">
          <form onSubmit={handleSubmit} className="flex gap-3">
            <input
              ref={inputRef}
              type="text"
              value={input}
              onChange={(e) => setInput(e.target.value)}
              placeholder="Ask a question in natural language..."
              disabled={loading}
              className="flex-1 px-4 py-3 bg-gray-100 border-0 rounded-xl text-gray-900 placeholder-gray-500 focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:bg-white transition-all disabled:opacity-50"
            />
            <button
              type="submit"
              disabled={!input.trim() || loading || !selectedDb}
              className="px-6 py-3 bg-indigo-600 text-white font-medium rounded-xl hover:bg-indigo-700 disabled:opacity-50 disabled:cursor-not-allowed transition-colors flex items-center gap-2"
            >
              {loading ? (
                <>
                  <svg className="animate-spin h-4 w-4" fill="none" viewBox="0 0 24 24">
                    <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4" />
                    <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4z" />
                  </svg>
                  <span className="hidden sm:inline">Sending</span>
                </>
              ) : (
                <>
                  <span>Send</span>
                  <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 19l9 2-9-18-9 18 9-2zm0 0v-8" />
                  </svg>
                </>
              )}
            </button>
          </form>
          <p className="text-xs text-gray-400 mt-2 text-center">
            Press Enter to send, Shift+Enter for new line
          </p>
        </div>
      </footer>
    </div>
  )
}

export default App
