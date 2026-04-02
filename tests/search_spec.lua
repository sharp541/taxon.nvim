local helpers = dofile('tests/helpers.lua')
local search = require('taxon.search')

return {
  {
    name = 'build_note_entries returns Telescope-friendly note entries',
    run = function()
      local entries = search.build_note_entries({
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
          kind = 'note',
          ordinal = 'Alpha 20260402-010203-alpha.md /tmp/20260402-010203-alpha.md',
          path = '/tmp/20260402-010203-alpha.md',
          title = 'Alpha',
        },
        {
          display = 'Beta [20260402-020304-beta.md]',
          kind = 'note',
          ordinal = 'Beta 20260402-020304-beta.md /tmp/20260402-020304-beta.md',
          path = '/tmp/20260402-020304-beta.md',
          title = 'Beta',
        },
      }, entries)
    end,
  },
  {
    name = 'build_tag_entries returns Telescope-friendly tag entries',
    run = function()
      local entries = search.build_tag_entries({
        'animal',
        'animal/mammal/cat',
      })

      helpers.eq({
        {
          display = 'animal',
          kind = 'tag',
          ordinal = 'animal animal',
          tag = 'animal',
        },
        {
          display = 'animal/mammal/cat',
          kind = 'tag',
          ordinal = 'animal/mammal/cat animal / mammal / cat',
          tag = 'animal/mammal/cat',
        },
      }, entries)
    end,
  },
  {
    name = 'build_entries combines note and tag entries with kind labels',
    run = function()
      local entries = search.build_entries({
        notes = {
          {
            path = '/tmp/20260402-010203-alpha.md',
            title = 'Alpha',
          },
        },
        tags = {
          'animal',
        },
      })

      helpers.eq({
        {
          display = '[Title] Alpha [20260402-010203-alpha.md]',
          kind = 'note',
          ordinal = 'title Alpha 20260402-010203-alpha.md /tmp/20260402-010203-alpha.md',
          path = '/tmp/20260402-010203-alpha.md',
          title = 'Alpha',
        },
        {
          display = '[Tag] animal',
          kind = 'tag',
          ordinal = 'tag animal animal',
          tag = 'animal',
        },
      }, entries)
    end,
  },
  {
    name = 'open_entry forwards the selected path to the opener',
    run = function()
      local opened_path

      search.open_entry({
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
    name = 'pick forwards the selected Telescope entry to the callback',
    run = function()
      local closed_prompt
      local captured_prompt_title
      local picker_found = false
      local replaced_action
      local selected_entry

      local ok = search.pick({
        {
          display = '[Tag] animal',
          kind = 'tag',
          ordinal = 'tag animal animal',
          tag = 'animal',
        },
      }, {
        on_select = function(entry)
          selected_entry = entry
        end,
        telescope = {
          action_state = {
            get_selected_entry = function()
              return {
                value = {
                  display = '[Tag] animal',
                  kind = 'tag',
                  ordinal = 'tag animal animal',
                  tag = 'animal',
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
      helpers.eq('Taxon Search', captured_prompt_title)
      helpers.eq({
        display = '[Tag] animal',
        kind = 'tag',
        ordinal = 'tag animal animal',
        tag = 'animal',
      }, selected_entry)
    end,
  },
}
