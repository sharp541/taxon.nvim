local helpers = dofile('tests/helpers.lua')
local taxon = require('taxon')

return {
  {
    name = 'setup creates the configured notes directory',
    run = function()
      helpers.with_temp_dir(function(temp_dir)
        local notes_dir = vim.fs.joinpath(temp_dir, 'notes')

        taxon.setup({
          notes_dir = notes_dir,
        })

        local stat = vim.uv.fs_stat(notes_dir)

        helpers.truthy(stat ~= nil, 'notes directory was not created')
        helpers.eq('directory', stat.type, 'notes path is not a directory')
        helpers.eq(notes_dir, taxon.config.notes_dir, 'setup did not persist config')
      end)
    end,
  },
  {
    name = 'TaxonOpen command dispatches to the module',
    run = function()
      helpers.eq(2, vim.fn.exists(':TaxonOpen'), 'TaxonOpen command is not registered')

      local called = false
      local original_open = taxon.open

      taxon.open = function()
        called = true
      end

      local ok, err = pcall(vim.api.nvim_cmd, {
        cmd = 'TaxonOpen',
      }, {})

      taxon.open = original_open

      if not ok then
        error(err)
      end

      helpers.truthy(called, 'TaxonOpen did not call require("taxon").open()')
    end,
  },
}
