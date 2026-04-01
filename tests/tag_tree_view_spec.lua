local helpers = dofile('tests/helpers.lua')
local tag_tree_view = require('taxon.tag_tree_view')

return {
  {
    name = 'build_entries flattens the tag tree into indented lines with note counts',
    run = function()
      local bird_note = {
        path = '/tmp/20260402-010203-bird.md',
        title = 'Bird Note',
      }
      local cat_note = {
        path = '/tmp/20260402-020304-cat.md',
        title = 'Cat Note',
      }

      local entries, lines = tag_tree_view.build_entries({
        {
          children = {
            {
              children = {},
              name = 'bird',
              notes = {
                bird_note,
              },
              tag = 'animal/bird',
            },
            {
              children = {
                {
                  children = {},
                  name = 'cat',
                  notes = {
                    cat_note,
                  },
                  tag = 'animal/mammal/cat',
                },
              },
              name = 'mammal',
              notes = {
                cat_note,
              },
              tag = 'animal/mammal',
            },
          },
          name = 'animal',
          notes = {
            bird_note,
            cat_note,
          },
          tag = 'animal',
        },
      })

      helpers.eq({
        'animal (2)',
        '  bird (1)',
        '  mammal (1)',
        '    cat (1)',
      }, lines)
      helpers.eq({
        {
          depth = 0,
          display = 'animal (2)',
          line = 1,
          name = 'animal',
          notes = {
            bird_note,
            cat_note,
          },
          tag = 'animal',
        },
        {
          depth = 1,
          display = '  bird (1)',
          line = 2,
          name = 'bird',
          notes = {
            bird_note,
          },
          tag = 'animal/bird',
        },
        {
          depth = 1,
          display = '  mammal (1)',
          line = 3,
          name = 'mammal',
          notes = {
            cat_note,
          },
          tag = 'animal/mammal',
        },
        {
          depth = 2,
          display = '    cat (1)',
          line = 4,
          name = 'cat',
          notes = {
            cat_note,
          },
          tag = 'animal/mammal/cat',
        },
      }, entries)
    end,
  },
  {
    name = 'open_entry chooses a note from the selected tag and opens it',
    run = function()
      local opened_path
      local captured_prompt

      local ok = tag_tree_view.open_entry({
        notes = {
          {
            path = '/tmp/20260402-010203-bird.md',
            title = 'Bird Note',
          },
          {
            path = '/tmp/20260402-020304-cat.md',
            title = 'Cat Note',
          },
        },
        tag = 'animal',
      }, {
        open = function(path)
          opened_path = path
          return true
        end,
        select_note = function(notes, opts, on_choice)
          captured_prompt = opts.prompt
          on_choice(notes[2])
          return true
        end,
      })

      helpers.eq(true, ok)
      helpers.eq('Taxon Tag Tree: animal', captured_prompt)
      helpers.eq('/tmp/20260402-020304-cat.md', opened_path)
    end,
  },
  {
    name = 'open uses the current cursor line to open the selected tag entry',
    run = function()
      local opened_path

      local result = tag_tree_view.open({
        {
          children = {
            {
              children = {},
              name = 'bird',
              notes = {
                {
                  path = '/tmp/20260402-010203-bird.md',
                  title = 'Bird Note',
                },
              },
              tag = 'animal/bird',
            },
          },
          name = 'animal',
          notes = {
            {
              path = '/tmp/20260402-010203-bird.md',
              title = 'Bird Note',
            },
          },
          tag = 'animal',
        },
      }, {
        open = function(path)
          opened_path = path
          return true
        end,
        open_window = function(bufnr)
          local win = vim.api.nvim_get_current_win()
          vim.api.nvim_win_set_buf(win, bufnr)
          return win
        end,
      })

      helpers.eq({
        'animal (1)',
        '  bird (1)',
      }, result.lines)

      vim.api.nvim_win_set_cursor(result.win, { 2, 0 })
      local ok = tag_tree_view.open_cursor_entry(result.bufnr, {
        win = result.win,
      })

      helpers.eq(true, ok)
      helpers.eq('/tmp/20260402-010203-bird.md', opened_path)
    end,
  },
}
