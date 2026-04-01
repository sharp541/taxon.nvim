local helpers = dofile('tests/helpers.lua')
local title_search = require('taxon.title_search')

return {
  {
    name = 'build_entries returns Telescope-friendly title entries',
    run = function()
      local entries = title_search.build_entries({
        {
          path = '/tmp/20260402-010203-alpha.md',
          title = 'Alpha',
        },
        {
          path = '/tmp/20260402-020304-beta.md',
          title = 'Beta',
        },
      })

      helpers.eq({
        {
          display = 'Alpha [20260402-010203-alpha.md]',
          ordinal = 'Alpha 20260402-010203-alpha.md /tmp/20260402-010203-alpha.md',
          path = '/tmp/20260402-010203-alpha.md',
          title = 'Alpha',
        },
        {
          display = 'Beta [20260402-020304-beta.md]',
          ordinal = 'Beta 20260402-020304-beta.md /tmp/20260402-020304-beta.md',
          path = '/tmp/20260402-020304-beta.md',
          title = 'Beta',
        },
      }, entries)
    end,
  },
  {
    name = 'open_entry forwards the selected path to the opener',
    run = function()
      local opened_path

      title_search.open_entry({
        path = '/tmp/20260402-010203-alpha.md',
        title = 'Alpha',
      }, {
        open = function(path)
          opened_path = path
        end,
      })

      helpers.eq('/tmp/20260402-010203-alpha.md', opened_path)
    end,
  },
  {
    name = 'pick opens the selected Telescope entry through the opener',
    run = function()
      local closed_prompt
      local captured_prompt_title
      local selected
      local picker_found = false
      local replaced_action

      local ok = title_search.pick({
        {
          display = 'Alpha [20260402-010203-alpha.md]',
          ordinal = 'Alpha 20260402-010203-alpha.md /tmp/20260402-010203-alpha.md',
          path = '/tmp/20260402-010203-alpha.md',
          title = 'Alpha',
        },
      }, {
        open = function(path)
          selected = path
        end,
        telescope = {
          action_state = {
            get_selected_entry = function()
              return {
                value = {
                  display = 'Alpha [20260402-010203-alpha.md]',
                  ordinal = 'Alpha 20260402-010203-alpha.md /tmp/20260402-010203-alpha.md',
                  path = '/tmp/20260402-010203-alpha.md',
                  title = 'Alpha',
                },
              }
            end,
          },
          actions = {
            close = function(prompt_bufnr)
              closed_prompt = prompt_bufnr
            end,
            select_default = {
              replace = function(_, callback)
                replaced_action = callback
              end,
            },
          },
          config = {
            values = {
              generic_sorter = function()
                return function() end
              end,
            },
          },
          finders = {
            new_table = function(spec)
              return spec
            end,
          },
          pickers = {
            new = function(_, spec)
              captured_prompt_title = spec.prompt_title

              return {
                find = function()
                  picker_found = true
                  spec.attach_mappings(42)
                  replaced_action()
                end,
              }
            end,
          },
        },
      })

      helpers.eq(true, ok)
      helpers.truthy(picker_found, 'picker was not started')
      helpers.eq(42, closed_prompt)
      helpers.eq('Taxon Title Search', captured_prompt_title)
      helpers.eq('/tmp/20260402-010203-alpha.md', selected)
    end,
  },
}
