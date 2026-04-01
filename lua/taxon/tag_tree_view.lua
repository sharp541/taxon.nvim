local M = {}

local state_by_bufnr = {}

local function default_open(path, opts)
  opts = opts or {}
  local source_win = opts.source_win
  local current_win = vim.api.nvim_get_current_win()

  if source_win ~= nil and vim.api.nvim_win_is_valid(source_win) then
    vim.api.nvim_set_current_win(source_win)
    vim.api.nvim_cmd({
      cmd = 'edit',
      args = { path },
    }, {})

    if opts.keep_focus ~= false and vim.api.nvim_win_is_valid(current_win) then
      vim.api.nvim_set_current_win(current_win)
    end

    return true
  end

  vim.api.nvim_cmd({
    cmd = 'edit',
    args = { path },
  }, {})

  return true
end

local function default_select_note(notes, opts, on_choice)
  if #notes == 1 then
    on_choice(notes[1])
    return true
  end

  vim.ui.select(notes, {
    prompt = opts.prompt,
    format_item = function(note)
      return string.format('%s [%s]', note.title, vim.fs.basename(note.path))
    end,
  }, on_choice)

  return true
end

local function set_buffer_lines(bufnr, lines)
  vim.bo[bufnr].modifiable = true
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  vim.bo[bufnr].modifiable = false
end

local function close_buffer(bufnr)
  if vim.api.nvim_buf_is_valid(bufnr) then
    vim.api.nvim_buf_delete(bufnr, {
      force = true,
    })
  end
end

function M.build_entries(nodes, opts)
  vim.validate({
    nodes = { nodes, 'table' },
    opts = { opts, 'table', true },
  })

  opts = opts or {}

  local entries = {}
  local lines = {}
  local indent = opts.indent or '  '

  local function visit(current_nodes, depth)
    for _, node in ipairs(current_nodes) do
      local line = string.rep(indent, depth) .. node.name .. string.format(' (%d)', #node.notes)

      table.insert(entries, {
        depth = depth,
        display = line,
        line = #lines + 1,
        name = node.name,
        notes = node.notes,
        tag = node.tag,
      })
      table.insert(lines, line)

      visit(node.children, depth + 1)
    end
  end

  visit(nodes, 0)

  return entries, lines
end

function M.open_entry(entry, opts)
  vim.validate({
    entry = { entry, 'table' },
    opts = { opts, 'table', true },
  })

  opts = opts or {}

  local notes = entry.notes or {}
  local open = opts.open or default_open
  local select_note = opts.select_note or default_select_note

  if #notes == 0 then
    return nil, 'missing-notes'
  end

  return select_note(notes, {
    prompt = opts.note_prompt_title or ('Taxon Tag Tree: ' .. entry.tag),
  }, function(note)
    if note == nil then
      return
    end

    open(note.path, {
      keep_focus = opts.keep_focus,
      source_win = opts.source_win,
    })
  end)
end

function M.open_cursor_entry(bufnr, opts)
  vim.validate({
    bufnr = { bufnr, 'number' },
    opts = { opts, 'table', true },
  })

  opts = opts or {}

  local state = state_by_bufnr[bufnr]
  if state == nil then
    return nil, 'missing-buffer-state'
  end

  local win = opts.win or state.win
  if win == nil or not vim.api.nvim_win_is_valid(win) then
    win = vim.api.nvim_get_current_win()
  end

  local line = vim.api.nvim_win_get_cursor(win)[1]
  local entry = state.entries[line]

  if entry == nil then
    return nil, 'missing-entry'
  end

  return M.open_entry(entry, {
    keep_focus = state.keep_focus,
    note_prompt_title = state.note_prompt_title,
    open = opts.open or state.open,
    select_note = opts.select_note or state.select_note,
    source_win = opts.source_win or state.source_win,
  })
end

function M.open_window(bufnr, opts)
  vim.validate({
    bufnr = { bufnr, 'number' },
    opts = { opts, 'table', true },
  })

  opts = opts or {}

  vim.cmd(opts.window_command or 'botright vnew')

  local win = vim.api.nvim_get_current_win()
  local width = opts.width or math.max(30, math.floor(vim.o.columns * 0.3))

  vim.api.nvim_win_set_buf(win, bufnr)
  pcall(vim.api.nvim_win_set_width, win, width)

  return win
end

function M.open(nodes, opts)
  vim.validate({
    nodes = { nodes, 'table' },
    opts = { opts, 'table', true },
  })

  opts = opts or {}

  local entries, lines = M.build_entries(nodes, {
    indent = opts.indent,
  })

  if #lines == 0 then
    lines = { opts.empty_message or 'No tags found.' }
  end

  local bufnr = vim.api.nvim_create_buf(false, true)
  local source_win = opts.source_win or vim.api.nvim_get_current_win()
  local open_window = opts.open_window or M.open_window
  local win = open_window(bufnr, opts)

  vim.bo[bufnr].bufhidden = 'wipe'
  vim.bo[bufnr].buftype = 'nofile'
  vim.bo[bufnr].filetype = 'taxon-tag-tree'
  vim.bo[bufnr].modifiable = true
  vim.bo[bufnr].swapfile = false
  vim.bo[bufnr].buflisted = false

  vim.api.nvim_buf_set_name(bufnr, string.format('taxon://tag-tree/%d', bufnr))
  set_buffer_lines(bufnr, lines)

  state_by_bufnr[bufnr] = {
    entries = entries,
    keep_focus = opts.keep_focus,
    note_prompt_title = opts.note_prompt_title,
    open = opts.open,
    select_note = opts.select_note,
    source_win = source_win,
    win = win,
  }

  vim.api.nvim_create_autocmd('BufWipeout', {
    buffer = bufnr,
    once = true,
    callback = function()
      state_by_bufnr[bufnr] = nil
    end,
  })

  vim.keymap.set('n', '<CR>', function()
    M.open_cursor_entry(bufnr)
  end, {
    buffer = bufnr,
    nowait = true,
    silent = true,
  })

  vim.keymap.set('n', 'q', function()
    close_buffer(bufnr)
  end, {
    buffer = bufnr,
    nowait = true,
    silent = true,
  })

  return {
    bufnr = bufnr,
    entries = entries,
    lines = lines,
    win = win,
  }
end

return M
