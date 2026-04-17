import { Bar, Line } from 'react-chartjs-2'

const CHART_COLORS = [
  '#6366f1', '#8b5cf6', '#ec4899', '#f43f5e', '#f97316',
  '#eab308', '#22c55e', '#14b8a6', '#0ea5e9', '#10b981'
]

function ChatMessage({ message }) {
  const isUser = message.type === 'user'
  const isError = message.error && !message.loading

  const renderContent = () => {
    if (message.loading) {
      return (
        <div className="flex items-center gap-2">
          <div className="flex gap-1">
            <span className="w-2 h-2 bg-gray-400 rounded-full animate-bounce" style={{ animationDelay: '0ms' }} />
            <span className="w-2 h-2 bg-gray-400 rounded-full animate-bounce" style={{ animationDelay: '150ms' }} />
            <span className="w-2 h-2 bg-gray-400 rounded-full animate-bounce" style={{ animationDelay: '300ms' }} />
          </div>
          <span className="text-gray-500 text-sm">Processing your question...</span>
        </div>
      )
    }

    if (isError) {
      return (
        <div className="text-red-500 text-sm">
          <span className="font-semibold">Error:</span> {message.error}
        </div>
      )
    }

    if (isUser) {
      return <p className="text-white">{message.text}</p>
    }

    if (!message.summary && !message.sql_query && !message.data && message.text) {
      return <p className="text-gray-700">{message.text}</p>
    }

    return (
      <div className="space-y-4">
        {message.summary && (
          <div className="bg-indigo-50 rounded-lg p-3 text-sm text-indigo-800">
            <p className="font-medium mb-1">Summary:</p>
            <p>{message.summary}</p>
          </div>
        )}

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
            </div>
            <div className="bg-white rounded-lg border border-gray-200 overflow-hidden">
              <table className="w-full text-sm">
                <thead className="bg-gray-50">
                  <tr>
                    {message.columns?.map((col, i) => (
                      <th key={i} className="px-3 py-2 text-left text-xs font-semibold text-gray-600 uppercase tracking-wider">
                        {col.replace(/_/g, ' ')}
                      </th>
                    ))}
                  </tr>
                </thead>
                <tbody className="divide-y divide-gray-100">
                  {message.data.map((row, i) => (
                    <tr key={i} className="hover:bg-gray-50">
                      {message.columns?.map((col, j) => (
                        <td key={j} className="px-3 py-2 text-gray-700 text-xs">
                          {row[col] !== null && row[col] !== undefined ? String(row[col]) : '—'}
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
