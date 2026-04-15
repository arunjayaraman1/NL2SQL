function LoadingSpinner() {
  return (
    <div className='flex flex-col items-center justify-center py-12 gap-4'>
      <div className='w-12 h-12 border-4 border-gray-200 border-t-indigo-600 rounded-full animate-spin'></div>
      <p className='text-gray-500'>Processing your query...</p>
    </div>
  )
}

export default LoadingSpinner