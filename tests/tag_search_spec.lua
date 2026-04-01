local helpers = dofile('tests/helpers.lua')
local tag_search = require('taxon.tag_search')

return {
  {
    name = 'build_entries returns Telescope-friendly tag entries',
    run = function()
      local entries = tag_search.build_entries({
        'animal',
        'animal/mammal/cat',
      })

      helpers.eq({
        {
          display = 'animal',
          ordinal = 'animal animal',
          tag = 'animal',
        },
        {
          display = 'animal/mammal/cat',
          ordinal = 'animal/mammal/cat animal / mammal / cat',
          tag = 'animal/mammal/cat',
        },
      }, entries)
    end,
  },
  {
    name = 'pick forwards the selected Telescope tag entry to the callback',
    run = function()
      local closed_prompt
      local captured_prompt_title
      local picker_found = false
      local replaced_action
      local selected_tag

      local ok = tag_search.pick({
        {
          display = 'animal',
          ordinal = 'animal animal',
          tag = 'animal',
        },
      }, {
        on_select = function(entry)
          selected_tag = entry.tag
        end,
        telescope = {
          action_state = {
            get_selected_entry = function()
              return {
                value = {
                  display = 'animal',
                  ordinal = 'animal animal',
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
      helpers.eq('Taxon Tag Search', captured_prompt_title)
      helpers.eq('animal', selected_tag)
    end,
  },
}
