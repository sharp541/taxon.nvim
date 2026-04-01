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
  {
    name = 'create_note writes the canonical file and opens it',
    run = function()
      helpers.with_temp_dir(function(temp_dir)
        local notes_dir = vim.fs.joinpath(temp_dir, 'notes')

        taxon.setup({
          notes_dir = notes_dir,
        })

        local path = taxon.create_note('Title', {
          now = {
            year = 2026,
            month = 4,
            day = 2,
            hour = 1,
            min = 2,
            sec = 3,
          },
        })

        helpers.eq(vim.fs.joinpath(notes_dir, '20260402-010203-Title.md'), path)
        helpers.eq(path, vim.api.nvim_buf_get_name(0), 'created note was not opened')
        helpers.eq({
          '---',
          'tags: []',
          '---',
          '',
          '# Title',
        }, vim.fn.readfile(path))
      end)
    end,
  },
  {
    name = 'TaxonNew command dispatches to the module',
    run = function()
      helpers.eq(2, vim.fn.exists(':TaxonNew'), 'TaxonNew command is not registered')

      local called = false
      local original_new_note = taxon.new_note

      taxon.new_note = function()
        called = true
      end

      local ok, err = pcall(vim.api.nvim_cmd, {
        cmd = 'TaxonNew',
      }, {})

      taxon.new_note = original_new_note

      if not ok then
        error(err)
      end

      helpers.truthy(called, 'TaxonNew did not call require("taxon").new_note()')
    end,
  },
}
