import { useState, useRef, useEffect } from 'react'
import ChatMessage from './components/ChatMessage'
import axios from 'axios'

function App() {
  const [messages, setMessages] = useState([
    {
      id: 0,
      type: 'assistant',
      text: 'Hello! I\'m your NL2SQL assistant. Ask me questions about your database in plain English, and I\'ll convert them to SQL queries.',
      loading: false,
      error: null
    }
  ])
  const [input, setInput] = useState('')
  const [loading, setLoading] = useState(false)
  const [selectedDb, setSelectedDb] = useState('hr')
  const [databases, setDatabases] = useState([])
  const messagesEndRef = useRef(null)
  const inputRef = useRef(null)

  useEffect(() => {
    axios.get('/api/databases')
      .then(res => setDatabases(res.data.databases || []))
      .catch(() => setDatabases([]))
  }, [])

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
      row_count: 0
    }

    setMessages(prev => [...prev, userMessage, assistantMessage])

    try {
      const response = await axios.post('/api/query', {
        question: questionText,
        db_type: selectedDb
      })

      setMessages(prev => prev.map(msg =>
        msg.id === assistantMessage.id
          ? {
              ...msg,
              loading: false,
              summary: response.data.summary,
              sql_query: response.data.sql_query,
              columns: response.data.columns,
              data: response.data.data,
              row_count: response.data.data?.length || 0
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
      error: null
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
            <ChatMessage key={message.id} message={message} />
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
              disabled={!input.trim() || loading}
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
