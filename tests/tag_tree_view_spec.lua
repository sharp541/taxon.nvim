local helpers = dofile('tests/helpers.lua')
local tag_tree_view = require('taxon.tag_tree_view')

return {
  {
    name = 'build_entries flattens expanded tag nodes into tag and file lines',
    run = function()
      local bird_note = {
        explicit_tags = { 'animal/bird' },
        path = '/tmp/20260402-010203-bird.md',
        title = 'Bird Note',
      }
      local cat_note = {
        explicit_tags = { 'animal/mammal/cat' },
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
      }, {
        expanded_tags = {
          ['animal'] = true,
          ['animal/mammal'] = true,
        },
      })

      helpers.eq({
        'v animal',
        '  > bird',
        '  v mammal',
        '    > cat',
      }, lines)
      helpers.eq({
        {
          depth = 0,
          display = 'v animal',
          expanded = true,
          kind = 'tag',
          line = 1,
          name = 'animal',
          parent_tag = nil,
          tag = 'animal',
        },
        {
          depth = 1,
          display = '  > bird',
          expanded = false,
          kind = 'tag',
          line = 2,
          name = 'bird',
          parent_tag = 'animal',
          tag = 'animal/bird',
        },
        {
          depth = 1,
          display = '  v mammal',
          expanded = true,
          kind = 'tag',
          line = 3,
          name = 'mammal',
          parent_tag = 'animal',
          tag = 'animal/mammal',
        },
        {
          depth = 2,
          display = '    > cat',
          expanded = false,
          kind = 'tag',
          line = 4,
          name = 'cat',
          parent_tag = 'animal/mammal',
          tag = 'animal/mammal/cat',
        },
      }, entries)
    end,
  },
  {
    name = 'open_entry opens file entries and rejects tag entries',
    run = function()
      local opened_path

      local ok = tag_tree_view.open_entry({
        kind = 'file',
        path = '/tmp/20260402-020304-cat.md',
        title = 'Cat Note',
      }, {
        open = function(path)
          opened_path = path
          return true
        end,
      })

      local tag_ok, tag_err = tag_tree_view.open_entry({
        kind = 'tag',
        tag = 'animal',
      })

      helpers.eq(true, ok)
      helpers.eq('/tmp/20260402-020304-cat.md', opened_path)
      helpers.eq(nil, tag_ok)
      helpers.eq('not-file-entry', tag_err)
    end,
  },
  {
    name = 'open_entry falls back to another non-tree window when source_win is invalid',
    run = function()
      local initial_win = vim.api.nvim_get_current_win()
      local initial_buf = vim.api.nvim_win_get_buf(initial_win)

      vim.cmd('vsplit')
      local edit_win = vim.api.nvim_get_current_win()
      vim.cmd('enew')
      local edit_buf = vim.api.nvim_win_get_buf(edit_win)

      vim.api.nvim_set_current_win(initial_win)
      vim.bo[initial_buf].filetype = 'taxon-tag-tree'

      local ok = tag_tree_view.open_entry({
        kind = 'file',
        path = '/tmp/20260402-020304-cat.md',
        title = 'Cat Note',
      }, {
        source_win = -1,
        tree_win = initial_win,
      })

      helpers.eq(true, ok)
      helpers.eq(edit_win, vim.fn.bufwinid(edit_buf))
      helpers.eq('/tmp/20260402-020304-cat.md', vim.api.nvim_buf_get_name(edit_buf))

      vim.api.nvim_set_current_win(edit_win)
      vim.cmd('bwipeout!')
      vim.api.nvim_set_current_win(initial_win)
      vim.bo[initial_buf].filetype = ''
    end,
  },
  {
    name = 'open_entry reuses a nofile dashboard-like source window',
    run = function()
      local source_win = vim.api.nvim_get_current_win()
      local source_buf = vim.api.nvim_win_get_buf(source_win)
      local windows_before = vim.api.nvim_tabpage_list_wins(0)

      vim.bo[source_buf].buftype = 'nofile'

      local ok = tag_tree_view.open_entry({
        kind = 'file',
        path = '/tmp/20260402-030404-dashboard.md',
        title = 'Dashboard Note',
      }, {
        source_win = source_win,
        tree_win = -1,
      })

      local windows_after = vim.api.nvim_tabpage_list_wins(0)

      helpers.eq(true, ok)
      helpers.eq(#windows_before, #windows_after)
      helpers.eq('/tmp/20260402-030404-dashboard.md', vim.api.nvim_buf_get_name(vim.api.nvim_win_get_buf(source_win)))
    end,
  },
  {
    name = 'open_entry creates a new edit window when the tree is the only window left',
    run = function()
      local tree_win = vim.api.nvim_get_current_win()
      local tree_buf = vim.api.nvim_win_get_buf(tree_win)
      local windows_before = vim.api.nvim_tabpage_list_wins(0)

      vim.bo[tree_buf].filetype = 'taxon-tag-tree'

      local ok = tag_tree_view.open_entry({
        kind = 'file',
        path = '/tmp/20260402-030405-dog.md',
        title = 'Dog Note',
      }, {
        source_win = tree_win,
        tree_win = tree_win,
      })

      local windows_after = vim.api.nvim_tabpage_list_wins(0)
      local edit_win

      for _, win in ipairs(windows_after) do
        if win ~= tree_win then
          edit_win = win
          break
        end
      end

      helpers.eq(true, ok)
      helpers.eq(#windows_before + 1, #windows_after)
      helpers.truthy(edit_win ~= nil, 'expected a new edit window to be created')
      helpers.eq(tree_buf, vim.api.nvim_win_get_buf(tree_win))
      helpers.eq('/tmp/20260402-030405-dog.md', vim.api.nvim_buf_get_name(vim.api.nvim_win_get_buf(edit_win)))
      helpers.eq(tree_win, vim.api.nvim_get_current_win())

      vim.api.nvim_set_current_win(edit_win)
      vim.cmd('close')
      vim.api.nvim_set_current_win(tree_win)
      vim.bo[tree_buf].filetype = ''
    end,
  },
  {
    name = 'open_window wipes the temporary unnamed buffer created by vnew',
    run = function()
      local bufnr = vim.api.nvim_create_buf(false, true)
      local listed_before = {}

      for _, info in ipairs(vim.fn.getbufinfo({ buflisted = 1 })) do
        listed_before[info.bufnr] = true
      end

      local win = tag_tree_view.open_window(bufnr)
      local listed_after = vim.fn.getbufinfo({ buflisted = 1 })
      local new_listed = {}

      for _, info in ipairs(listed_after) do
        if not listed_before[info.bufnr] then
          table.insert(new_listed, info.bufnr)
        end
      end

      helpers.eq(bufnr, vim.api.nvim_win_get_buf(win))
      helpers.eq({}, new_listed)
      helpers.eq('', vim.fn.bufname(bufnr))
    end,
  },
  {
    name = 'open_window opens the tag tree to the left of the existing window by default',
    run = function()
      local original_win = vim.api.nvim_get_current_win()
      local bufnr = vim.api.nvim_create_buf(false, true)
      local win = tag_tree_view.open_window(bufnr)
      local layout = vim.fn.winlayout()

      helpers.eq('row', layout[1])
      helpers.eq({ 'leaf', win }, layout[2][1])
      helpers.eq({ 'leaf', original_win }, layout[2][2])
    end,
  },
  {
    name = 'open toggles tags and opens files from the current cursor line',
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
                  explicit_tags = { 'animal/bird' },
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
              explicit_tags = { 'animal/bird' },
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
        'v animal',
        '  > bird',
      }, result.lines)

      vim.api.nvim_win_set_cursor(result.win, { 2, 0 })
      local toggled = tag_tree_view.open_cursor_entry(result.bufnr, {
        win = result.win,
      })

      helpers.eq({
        'v animal',
        '  v bird',
        '      Bird Note [20260402-010203-bird.md]',
      }, toggled.lines)

      vim.api.nvim_win_set_cursor(result.win, { 3, 0 })
      local opened = tag_tree_view.open_cursor_entry(result.bufnr, {
        win = result.win,
      })

      helpers.eq(true, opened)
      helpers.eq('/tmp/20260402-010203-bird.md', opened_path)
    end,
  },
  {
    name = 'collapse_cursor_entry closes expanded tags and moves to the parent from collapsed tags',
    run = function()
      local result = tag_tree_view.open({
        {
          children = {
            {
              children = {
                {
                  children = {},
                  name = 'cat',
                  notes = {},
                  tag = 'animal/mammal/cat',
                },
              },
              name = 'mammal',
              notes = {},
              tag = 'animal/mammal',
            },
          },
          name = 'animal',
          notes = {},
          tag = 'animal',
        },
      }, {
        expanded_tags = {
          ['animal'] = true,
          ['animal/mammal'] = true,
        },
        open_window = function(bufnr)
          local win = vim.api.nvim_get_current_win()
          vim.api.nvim_win_set_buf(win, bufnr)
          return win
        end,
      })

      vim.api.nvim_win_set_cursor(result.win, { 2, 0 })
      local collapse_ok = tag_tree_view.collapse_cursor_entry(result.bufnr, {
        win = result.win,
      })

      helpers.eq({
        'v animal',
        '  > mammal',
      }, vim.api.nvim_buf_get_lines(result.bufnr, 0, -1, false))
      helpers.eq({
        'v animal',
        '  > mammal',
      }, collapse_ok.lines)

      vim.api.nvim_win_set_cursor(result.win, { 2, 0 })
      local parent_ok = tag_tree_view.collapse_cursor_entry(result.bufnr, {
        win = result.win,
      })

      helpers.eq(true, parent_ok)
      helpers.eq({ 1, 0 }, vim.api.nvim_win_get_cursor(result.win))
    end,
  },
}
