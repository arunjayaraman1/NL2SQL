interface ResultsTableProps {
  columns: string[]
  data: Record<string, unknown>[]
}

function ResultsTable({ columns, data }: ResultsTableProps) {
  if (!data || data.length === 0) {
    return (
      <div className='bg-white rounded-2xl shadow-sm border border-gray-100 p-8 text-center text-gray-500'>
        No results found
      </div>
    )
  }

  return (
    <div className='bg-white rounded-2xl shadow-sm border border-gray-100 overflow-hidden'>
      <div className='overflow-x-auto'>
        <table className='w-full'>
          <thead>
            <tr className='bg-gray-50'>
              {columns.map((col, idx) => (
                <th key={idx} className='px-4 py-3 text-left text-xs font-semibold text-gray-600 uppercase tracking-wider capitalize'>
                  {col.replace(/_/g, ' ')}
                </th>
              ))}
            </tr>
          </thead>
          <tbody className='divide-y divide-gray-100'>
            {data.map((row, rowIdx) => (
              <tr key={rowIdx} className='hover:bg-gray-50 transition-colors'>
                {columns.map((col, colIdx) => (
                  <td key={colIdx} className='px-4 py-3 text-gray-700'>
                    {row[col] !== null && row[col] !== undefined ? String(row[col]) : '—'}
                  </td>
                ))}
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  )
}

export default ResultsTable
