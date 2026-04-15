import { useState, forwardRef } from 'react'

const QueryInput = forwardRef(function QueryInput({ onSubmit, loading }, ref) {
  const [question, setQuestion] = useState('')

  const handleSubmit = (e) => {
    e.preventDefault()
    if (question.trim() && !loading) {
      onSubmit(question)
      setQuestion('')
    }
  }

  const handleKeyPress = (e) => {
    if (e.key === 'Enter' && !e.shiftKey) {
      handleSubmit(e)
    }
  }

  return (
    <form onSubmit={handleSubmit}>
      <div className='flex gap-4 items-stretch'>
        <input
          ref={ref}
          type='text'
          className='flex-1 px-5 py-4 text-lg border-2 border-gray-200 rounded-xl focus:outline-none focus:border-indigo-500 focus:ring-4 focus:ring-indigo-100 transition-all duration-200 placeholder:text-gray-400'
          placeholder='Ask a question in natural language...'
          value={question}
          onChange={(e) => setQuestion(e.target.value)}
          onKeyPress={handleKeyPress}
          disabled={loading}
        />
        <button 
          type='submit' 
          className={`px-8 py-4 rounded-xl font-semibold text-white transition-all duration-200 flex items-center gap-2 ${
            loading || !question.trim() 
              ? 'bg-gray-400 cursor-not-allowed' 
              : 'bg-indigo-600 hover:bg-indigo-700 hover:-translate-y-0.5 hover:shadow-lg'
          }`}
          disabled={loading || !question.trim()}
        >
          {loading ? 'Processing...' : 'Ask'}
          {!loading && <span>→</span>}
        </button>
      </div>
    </form>
  )
})

export default QueryInput