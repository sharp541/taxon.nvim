local M = {}

local state_by_bufnr = {}

local function is_tree_window(win)
  if win == nil or not vim.api.nvim_win_is_valid(win) then
    return false
  end

  local buf = vim.api.nvim_win_get_buf(win)
  return vim.bo[buf].filetype == 'taxon-tag-tree'
end

local function is_normal_window(win)
  if win == nil or not vim.api.nvim_win_is_valid(win) then
    return false
  end

  local config = vim.api.nvim_win_get_config(win)

  return config.relative == ''
end

local function is_open_target_window(win, excluded_win)
  if win == nil or win == excluded_win or is_tree_window(win) then
    return false
  end

  return is_normal_window(win)
end

local function find_fallback_window(excluded_win)
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if is_open_target_window(win, excluded_win) then
      return win
    end
  end

  return nil
end

local function mark_temp_buffer(bufnr)
  if vim.api.nvim_buf_is_valid(bufnr) then
    vim.bo[bufnr].bufhidden = 'wipe'
    vim.bo[bufnr].buflisted = false
    vim.bo[bufnr].swapfile = false
  end
end

local function open_edit_window(tree_win)
  local base_win = tree_win
  if base_win == nil or not vim.api.nvim_win_is_valid(base_win) then
    base_win = vim.api.nvim_get_current_win()
  end

  vim.api.nvim_set_current_win(base_win)
  vim.cmd('leftabove vnew')

  local win = vim.api.nvim_get_current_win()
  mark_temp_buffer(vim.api.nvim_win_get_buf(win))

  return win
end

local function default_open(path, opts)
  opts = opts or {}
  local source_win = opts.source_win
  local current_win = vim.api.nvim_get_current_win()
  local target_win = source_win

  if not is_open_target_window(target_win, opts.tree_win) then
    target_win = find_fallback_window(opts.tree_win)
  end

  if target_win == nil then
    target_win = open_edit_window(opts.tree_win)
  end

  if target_win ~= nil and vim.api.nvim_win_is_valid(target_win) then
    vim.api.nvim_set_current_win(target_win)
    vim.api.nvim_cmd({
      cmd = 'edit',
      args = { path },
    }, {})

    if opts.keep_focus ~= false and vim.api.nvim_win_is_valid(current_win) and current_win ~= target_win then
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

local function is_expanded(expanded_tags, tag, depth)
  if expanded_tags[tag] ~= nil then
    return expanded_tags[tag]
  end

  return depth == 0
end

local function file_line(depth, title, basename, indent)
  return string.rep(indent, depth) .. '  ' .. title .. ' [' .. basename .. ']'
end

local function tag_line(depth, name, expanded, indent)
  local marker = expanded and 'v' or '>'
  return string.rep(indent, depth) .. marker .. ' ' .. name
end

local function note_has_explicit_tag(note, tag)
  for _, explicit_tag in ipairs(note.explicit_tags or {}) do
    if explicit_tag == tag then
      return true
    end
  end

  return false
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
  local expanded_tags = opts.expanded_tags or {}

  local function visit(current_nodes, depth, parent_tag)
    for _, node in ipairs(current_nodes) do
      local expanded = is_expanded(expanded_tags, node.tag, depth)
      local line = tag_line(depth, node.name, expanded, indent)

      table.insert(entries, {
        depth = depth,
        display = line,
        expanded = expanded,
        kind = 'tag',
        line = #lines + 1,
        name = node.name,
        parent_tag = parent_tag,
        tag = node.tag,
      })
      table.insert(lines, line)

      if expanded then
        for _, note in ipairs(node.notes or {}) do
          if note_has_explicit_tag(note, node.tag) then
            local note_line = file_line(depth + 1, note.title, vim.fs.basename(note.path), indent)

            table.insert(entries, {
              depth = depth + 1,
              display = note_line,
              kind = 'file',
              line = #lines + 1,
              parent_tag = node.tag,
              path = note.path,
              title = note.title,
            })
            table.insert(lines, note_line)
          end
        end

        visit(node.children or {}, depth + 1, node.tag)
      end
    end
  end

  visit(nodes, 0, nil)

  return entries, lines
end

local function render(bufnr)
  local state = state_by_bufnr[bufnr]
  if state == nil then
    return nil, 'missing-buffer-state'
  end

  local entries, lines = M.build_entries(state.nodes, {
    expanded_tags = state.expanded_tags,
    indent = state.indent,
  })

  if #lines == 0 then
    lines = { state.empty_message or 'No tags found.' }
  end

  state.entries = entries
  set_buffer_lines(bufnr, lines)

  return {
    entries = entries,
    lines = lines,
  }
end

function M.toggle_tag(bufnr, tag)
  vim.validate({
    bufnr = { bufnr, 'number' },
    tag = { tag, 'string' },
  })

  local state = state_by_bufnr[bufnr]
  if state == nil then
    return nil, 'missing-buffer-state'
  end

  state.expanded_tags[tag] = not state.expanded_tags[tag]

  return render(bufnr)
end

function M.open_entry(entry, opts)
  vim.validate({
    entry = { entry, 'table' },
    opts = { opts, 'table', true },
  })

  opts = opts or {}

  if entry.kind ~= 'file' then
    return nil, 'not-file-entry'
  end

  local open = opts.open or default_open

  return open(entry.path, {
    keep_focus = opts.keep_focus,
    source_win = opts.source_win,
    tree_win = opts.tree_win,
  })
end

local function current_entry(bufnr, opts)
  local state = state_by_bufnr[bufnr]
  if state == nil then
    return nil, 'missing-buffer-state'
  end

  local win = opts.win or state.win
  if win == nil or not vim.api.nvim_win_is_valid(win) then
    win = vim.api.nvim_get_current_win()
  end

  local line = vim.api.nvim_win_get_cursor(win)[1]

  return state.entries[line], nil, win
end

local function focus_tag(bufnr, win, tag)
  if tag == nil then
    return true
  end

  local state = state_by_bufnr[bufnr]
  if state == nil then
    return nil, 'missing-buffer-state'
  end

  for _, entry in ipairs(state.entries) do
    if entry.kind == 'tag' and entry.tag == tag then
      vim.api.nvim_win_set_cursor(win, { entry.line, 0 })
      return true
    end
  end

  return nil, 'missing-entry'
end

function M.open_cursor_entry(bufnr, opts)
  vim.validate({
    bufnr = { bufnr, 'number' },
    opts = { opts, 'table', true },
  })

  opts = opts or {}

  local entry, err = current_entry(bufnr, opts)
  if entry == nil then
    return nil, err or 'missing-entry'
  end

  if entry.kind == 'tag' then
    return M.toggle_tag(bufnr, entry.tag)
  end

  local state = state_by_bufnr[bufnr]

  return M.open_entry(entry, {
    keep_focus = state.keep_focus,
    open = opts.open or state.open,
    source_win = opts.source_win or state.source_win,
    tree_win = opts.tree_win or state.win,
  })
end

function M.expand_cursor_entry(bufnr, opts)
  vim.validate({
    bufnr = { bufnr, 'number' },
    opts = { opts, 'table', true },
  })

  opts = opts or {}

  local entry, err = current_entry(bufnr, opts)
  if entry == nil then
    return nil, err or 'missing-entry'
  end

  if entry.kind == 'file' then
    return M.open_cursor_entry(bufnr, opts)
  end

  if entry.expanded then
    return true
  end

  return M.toggle_tag(bufnr, entry.tag)
end

function M.collapse_cursor_entry(bufnr, opts)
  vim.validate({
    bufnr = { bufnr, 'number' },
    opts = { opts, 'table', true },
  })

  opts = opts or {}

  local entry, err, win = current_entry(bufnr, opts)
  if entry == nil then
    return nil, err or 'missing-entry'
  end

  if entry.kind == 'file' then
    return focus_tag(bufnr, win, entry.parent_tag)
  end

  if entry.expanded then
    return M.toggle_tag(bufnr, entry.tag)
  end

  return focus_tag(bufnr, win, entry.parent_tag)
end

function M.open_window(bufnr, opts)
  vim.validate({
    bufnr = { bufnr, 'number' },
    opts = { opts, 'table', true },
  })

  opts = opts or {}

  vim.cmd(opts.window_command or 'topleft vnew')

  local win = vim.api.nvim_get_current_win()
  local width = opts.width or math.max(30, math.floor(vim.o.columns * 0.3))
  local temp_buf = vim.api.nvim_win_get_buf(win)

  if temp_buf ~= bufnr then
    mark_temp_buffer(temp_buf)
  end

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

  state_by_bufnr[bufnr] = {
    empty_message = opts.empty_message,
    entries = {},
    expanded_tags = vim.deepcopy(opts.expanded_tags or {}),
    indent = opts.indent,
    keep_focus = opts.keep_focus,
    nodes = nodes,
    open = opts.open,
    source_win = source_win,
    win = win,
  }

  render(bufnr)

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

  vim.keymap.set('n', 'l', function()
    M.expand_cursor_entry(bufnr)
  end, {
    buffer = bufnr,
    nowait = true,
    silent = true,
  })

  vim.keymap.set('n', 'h', function()
    M.collapse_cursor_entry(bufnr)
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
    entries = state_by_bufnr[bufnr].entries,
    lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false),
    win = win,
  }
end

return M
