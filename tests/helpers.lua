local M = {}

function M.eq(expected, actual, message)
  if vim.deep_equal(expected, actual) then
    return
  end

  local parts = {
    message or 'values are not equal',
    'expected: ' .. vim.inspect(expected),
    'actual: ' .. vim.inspect(actual),
  }

  error(table.concat(parts, '\n'))
end

function M.truthy(value, message)
  if value then
    return
  end

  error(message or 'expected a truthy value')
end

function M.with_temp_dir(callback)
  local path = vim.fn.tempname()
  vim.fn.mkdir(path, 'p')

  local ok, result = xpcall(function()
    return callback(path)
  end, debug.traceback)

  vim.fn.delete(path, 'rf')

  if ok then
    return result
  end

  error(result)
end

return M
