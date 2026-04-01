local suites = {
  'tests/taxon_spec.lua',
}

local failures = {}
local passed = 0

for _, suite_path in ipairs(suites) do
  local ok, suite = xpcall(function()
    return dofile(suite_path)
  end, debug.traceback)

  if not ok then
    table.insert(failures, {
      name = suite_path,
      error = suite,
    })
  else
    for _, case in ipairs(suite) do
      local case_ok, result = xpcall(case.run, debug.traceback)

      if case_ok then
        passed = passed + 1
        print('ok - ' .. case.name)
      else
        table.insert(failures, {
          name = case.name,
          error = result,
        })
        print('not ok - ' .. case.name)
      end
    end
  end
end

if #failures > 0 then
  print('')
  print('Failures:')

  for _, failure in ipairs(failures) do
    print('- ' .. failure.name)
    print(failure.error)
  end

  vim.cmd.cquit(#failures)
end

print(string.format('%d tests passed', passed))
vim.cmd.quitall()
