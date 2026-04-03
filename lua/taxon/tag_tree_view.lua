local M = {}

local note = require('taxon.note')
local tag = require('taxon.tag')

local state_by_bufnr = {}
local namespace = vim.api.nvim_create_namespace('taxon-tag-tree')

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

    if
      opts.keep_focus ~= false
      and vim.api.nvim_win_is_valid(current_win)
      and current_win ~= target_win
    then
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
end

local function close_buffer(bufnr)
  if vim.api.nvim_buf_is_valid(bufnr) then
    vim.api.nvim_buf_delete(bufnr, {
      force = true,
    })
  end
end

function M.close(bufnr)
  vim.validate({
    bufnr = { bufnr, 'number' },
  })

  local state = state_by_bufnr[bufnr]
  local win = state and state.win or nil

  if win ~= nil and vim.api.nvim_win_is_valid(win) then
    local ok = pcall(vim.api.nvim_win_close, win, true)
    if ok then
      return true
    end
  end

  close_buffer(bufnr)

  return true
end

local function is_expanded(expanded_tags, current_tag, depth)
  if expanded_tags[current_tag] ~= nil then
    return expanded_tags[current_tag]
  end

  return depth == 0
end

local function set_tree_window_options(win)
  if win == nil or not vim.api.nvim_win_is_valid(win) then
    return
  end

  local options = {
    cursorline = true,
    foldcolumn = '0',
    list = false,
    number = false,
    relativenumber = false,
    signcolumn = 'no',
    spell = false,
    wrap = false,
  }

  for name, value in pairs(options) do
    pcall(vim.api.nvim_set_option_value, name, value, {
      scope = 'local',
      win = win,
    })
  end
end

local function note_line(depth, basename, indent)
  return string.rep(indent, depth) .. basename
end

local function tag_line(depth, name, expanded, indent)
  local marker = expanded and '- ' or '+ '
  return string.rep(indent, depth) .. marker .. name .. '/'
end

local function apply_highlights(bufnr, entries)
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end

  vim.api.nvim_buf_clear_namespace(bufnr, namespace, 0, -1)

  for _, entry in ipairs(entries) do
    local line = entry.line - 1

    if entry.kind == 'tag' then
      local marker_width = #string.rep(entry.indent or '  ', entry.depth) + 2

      vim.api.nvim_buf_add_highlight(bufnr, namespace, 'Comment', line, 0, marker_width)
      vim.api.nvim_buf_add_highlight(bufnr, namespace, 'Directory', line, marker_width, -1)
    elseif entry.kind == 'file' then
      vim.api.nvim_buf_add_highlight(bufnr, namespace, 'Normal', line, 0, -1)
    end
  end
end

local function note_has_explicit_tag(current_note, current_tag)
  for _, explicit_tag in ipairs(current_note.explicit_tags or {}) do
    if explicit_tag == current_tag then
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
        indent = indent,
        kind = 'tag',
        line = #lines + 1,
        name = node.name,
        parent_tag = parent_tag,
        tag = node.tag,
      })
      table.insert(lines, line)

      if expanded then
        for _, current_note in ipairs(node.notes or {}) do
          if note_has_explicit_tag(current_note, node.tag) then
            local basename = vim.fs.basename(current_note.path)
            local rendered_line = note_line(depth + 1, basename, indent)

            table.insert(entries, {
              basename = basename,
              depth = depth + 1,
              display = rendered_line,
              indent = indent,
              kind = 'file',
              line = #lines + 1,
              parent_tag = node.tag,
              path = current_note.path,
              title = current_note.title,
            })
            table.insert(lines, rendered_line)
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
  state.original_lines = vim.deepcopy(lines)
  set_buffer_lines(bufnr, lines)
  apply_highlights(bufnr, entries)
  vim.bo[bufnr].modified = false

  return {
    entries = entries,
    lines = lines,
  }
end

function M.toggle_tag(bufnr, current_tag)
  vim.validate({
    bufnr = { bufnr, 'number' },
    current_tag = { current_tag, 'string' },
  })

  local state = state_by_bufnr[bufnr]
  if state == nil then
    return nil, 'missing-buffer-state'
  end

  state.expanded_tags[current_tag] = not state.expanded_tags[current_tag]

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

local function focus_tag(bufnr, win, current_tag)
  if current_tag == nil then
    return true
  end

  local state = state_by_bufnr[bufnr]
  if state == nil then
    return nil, 'missing-buffer-state'
  end

  for _, entry in ipairs(state.entries) do
    if entry.kind == 'tag' and entry.tag == current_tag then
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

local function parse_tag_line(line, entry)
  local marker = entry.expanded and '- ' or '+ '
  local prefix = string.rep(entry.indent or '  ', entry.depth) .. marker
  if not vim.startswith(line, prefix) or not line:match('/$') then
    return nil, 'invalid-tag-line'
  end

  local name = line:sub(#prefix + 1, -2)
  if vim.trim(name) == '' then
    return nil, 'invalid-tag-line'
  end

  local full_tag = entry.parent_tag and (entry.parent_tag .. '/' .. name) or name
  local normalized_tag, err = tag.normalize(full_tag)
  if normalized_tag == nil then
    return nil, err
  end

  return {
    kind = 'tag',
    line = line,
    name = name,
    tag = normalized_tag,
  }
end

local function parse_file_line(line, entry)
  local prefix = string.rep(entry.indent or '  ', entry.depth)
  if not vim.startswith(line, prefix) then
    return nil, 'invalid-file-line'
  end

  local basename = line:sub(#prefix + 1)
  if vim.trim(basename) == '' then
    return nil, 'invalid-file-line'
  end

  if basename:find('/') ~= nil or basename:find('\\') ~= nil then
    return nil, 'invalid-file-line'
  end

  return {
    basename = basename,
    kind = 'file',
    line = line,
  }
end

local function parse_replacement_line(line, entry)
  if entry.kind == 'tag' then
    return parse_tag_line(line, entry)
  end

  return parse_file_line(line, entry)
end

local function line_diff(original_lines, current_lines)
  local row_count = #original_lines
  local col_count = #current_lines
  local lcs = {}

  for row = 0, row_count + 1 do
    lcs[row] = {}
    for col = 0, col_count + 1 do
      lcs[row][col] = 0
    end
  end

  for row = row_count, 1, -1 do
    for col = col_count, 1, -1 do
      if original_lines[row] == current_lines[col] then
        lcs[row][col] = lcs[row + 1][col + 1] + 1
      else
        lcs[row][col] = math.max(lcs[row + 1][col], lcs[row][col + 1])
      end
    end
  end

  local ops = {}
  local row = 1
  local col = 1

  while row <= row_count and col <= col_count do
    if original_lines[row] == current_lines[col] then
      table.insert(ops, {
        kind = 'equal',
        line = original_lines[row],
      })
      row = row + 1
      col = col + 1
    elseif lcs[row + 1][col] >= lcs[row][col + 1] then
      table.insert(ops, {
        kind = 'delete',
        line = original_lines[row],
      })
      row = row + 1
    else
      table.insert(ops, {
        kind = 'insert',
        line = current_lines[col],
      })
      col = col + 1
    end
  end

  while row <= row_count do
    table.insert(ops, {
      kind = 'delete',
      line = original_lines[row],
    })
    row = row + 1
  end

  while col <= col_count do
    table.insert(ops, {
      kind = 'insert',
      line = current_lines[col],
    })
    col = col + 1
  end

  return ops
end

local function collect_operations(state, current_lines)
  local operations = {}
  local original_entries = state.entries
  local ops = line_diff(state.original_lines or {}, current_lines)
  local entry_index = 1
  local op_index = 1

  while op_index <= #ops do
    local diff_op = ops[op_index]

    if diff_op.kind == 'equal' then
      entry_index = entry_index + 1
      op_index = op_index + 1
    elseif diff_op.kind == 'insert' then
      return nil, 'insert-not-supported'
    else
      local deleted_entries = {}
      local inserted_lines = {}

      while op_index <= #ops and ops[op_index].kind == 'delete' do
        table.insert(deleted_entries, original_entries[entry_index])
        entry_index = entry_index + 1
        op_index = op_index + 1
      end

      while op_index <= #ops and ops[op_index].kind == 'insert' do
        table.insert(inserted_lines, ops[op_index].line)
        op_index = op_index + 1
      end

      if #inserted_lines > #deleted_entries then
        return nil, 'insert-not-supported'
      end

      for index = 1, #inserted_lines do
        local entry = deleted_entries[index]
        local parsed_line, err = parse_replacement_line(inserted_lines[index], entry)
        if parsed_line == nil then
          return nil, err
        end

        if entry.kind == 'tag' then
          if parsed_line.tag ~= entry.tag then
            table.insert(operations, {
              kind = 'rename_tag',
              new_tag = parsed_line.tag,
              old_tag = entry.tag,
            })
          end
        elseif parsed_line.basename ~= entry.basename then
          table.insert(operations, {
            kind = 'rename_file',
            new_basename = parsed_line.basename,
            path = entry.path,
          })
        end
      end

      for index = #inserted_lines + 1, #deleted_entries do
        local entry = deleted_entries[index]
        if entry.kind ~= 'file' then
          return nil, 'tag-delete-not-supported'
        end

        table.insert(operations, {
          basename = entry.basename,
          kind = 'delete_file',
          path = entry.path,
        })
      end
    end
  end

  return operations
end

local function default_confirm_deletes(paths)
  local prompt
  if #paths == 1 then
    prompt = 'Delete note ' .. vim.fs.basename(paths[1]) .. '?'
  else
    prompt = string.format('Delete %d notes?', #paths)
  end

  return vim.fn.confirm(prompt, '&Yes\n&No', 2) == 1
end

local function rename_expanded_tags(expanded_tags, old_tag, new_tag)
  local updated = {}

  for current_tag, expanded in pairs(expanded_tags) do
    if current_tag == old_tag then
      updated[new_tag] = expanded
    elseif vim.startswith(current_tag, old_tag .. '/') then
      updated[new_tag .. current_tag:sub(#old_tag + 1)] = expanded
    else
      updated[current_tag] = expanded
    end
  end

  return updated
end

local function apply_tag_rename_to_tags(tags, old_tag, new_tag)
  local changed = false
  local updated = {}

  for _, current_tag in ipairs(tags) do
    if current_tag == old_tag then
      table.insert(updated, new_tag)
      changed = true
    elseif vim.startswith(current_tag, old_tag .. '/') then
      table.insert(updated, new_tag .. current_tag:sub(#old_tag + 1))
      changed = true
    else
      table.insert(updated, current_tag)
    end
  end

  return updated, changed
end

local function apply_operations(bufnr, operations)
  local state = state_by_bufnr[bufnr]
  if state == nil then
    return nil, 'missing-buffer-state'
  end

  local model, err = state.scan()
  if model == nil then
    return nil, err
  end

  for _, operation in ipairs(operations) do
    if operation.kind == 'rename_tag' then
      for _, current_note in ipairs(model.notes) do
        local updated_tags, changed =
          apply_tag_rename_to_tags(current_note.explicit_tags, operation.old_tag, operation.new_tag)
        if changed then
          local ok, write_err = note.write_tags(current_note.path, updated_tags)
          if ok == nil then
            return nil, write_err
          end

          current_note.explicit_tags = updated_tags
        end
      end

      state.expanded_tags =
        rename_expanded_tags(state.expanded_tags, operation.old_tag, operation.new_tag)
    end
  end

  for _, operation in ipairs(operations) do
    if operation.kind == 'rename_file' then
      local new_path, rename_err = note.rename_file(operation.path, operation.new_basename)
      if new_path == nil then
        return nil, rename_err
      end

      operation.path = new_path
    end
  end

  local delete_paths = {}
  for _, operation in ipairs(operations) do
    if operation.kind == 'delete_file' then
      table.insert(delete_paths, operation.path)
    end
  end

  if #delete_paths > 0 then
    local confirm = state.confirm_deletes or default_confirm_deletes
    if not confirm(delete_paths) then
      return nil, 'delete-cancelled'
    end

    for _, path in ipairs(delete_paths) do
      local ok, delete_err = note.delete_file(path)
      if ok == nil then
        return nil, delete_err
      end
    end
  end

  local refreshed_model, scan_err = state.scan()
  if refreshed_model == nil then
    return nil, scan_err
  end

  state.nodes = refreshed_model.tag_tree

  return render(bufnr)
end

function M.write(bufnr)
  vim.validate({
    bufnr = { bufnr, 'number' },
  })

  local state = state_by_bufnr[bufnr]
  if state == nil then
    return nil, 'missing-buffer-state'
  end

  local current_lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local operations, err = collect_operations(state, current_lines)
  if operations == nil then
    return nil, err
  end

  return apply_operations(bufnr, operations)
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
  set_tree_window_options(win)

  return win
end

local function notify_write_error(bufnr, err)
  local state = state_by_bufnr[bufnr]
  local notify = state and state.notify or vim.notify
  local messages = {
    ['delete-cancelled'] = 'Taxon: delete cancelled',
    ['insert-not-supported'] = 'Taxon: inserting lines in the tag tree is not supported',
    ['invalid-extension'] = 'Taxon: note filenames must end with .md',
    ['invalid-file-line'] = 'Taxon: file lines may only change the basename',
    ['invalid-tag'] = 'Taxon: tag rename produced an invalid tag',
    ['invalid-tag-line'] = 'Taxon: tag lines may only change the tag name',
    ['path-exists'] = 'Taxon: target note path already exists',
    ['rename-failed'] = 'Taxon: failed to rename the note file',
    ['tag-delete-not-supported'] = 'Taxon: deleting tags from the tree is not supported',
    ['unsafe-basename'] = 'Taxon: note filename contains path-unsafe characters',
    ['write-failed'] = 'Taxon: failed to update note tags',
  }

  notify(messages[err] or ('Taxon: failed to save tag tree (' .. err .. ')'), vim.log.levels.ERROR)
end

function M.open(nodes, opts)
  vim.validate({
    nodes = { nodes, 'table' },
    opts = { opts, 'table', true },
  })

  opts = opts or {}

  local bufnr = vim.api.nvim_create_buf(false, false)
  local source_win = opts.source_win or vim.api.nvim_get_current_win()
  local open_window = opts.open_window or M.open_window
  local win = open_window(bufnr, opts)
  set_tree_window_options(win)

  vim.api.nvim_buf_set_name(bufnr, string.format('taxon-tag-tree-%d', bufnr))

  vim.bo[bufnr].bufhidden = 'wipe'
  vim.bo[bufnr].buftype = 'acwrite'
  vim.bo[bufnr].filetype = 'taxon-tag-tree'
  vim.bo[bufnr].modifiable = true
  vim.bo[bufnr].readonly = false
  vim.bo[bufnr].swapfile = false
  vim.bo[bufnr].buflisted = false

  state_by_bufnr[bufnr] = {
    confirm_deletes = opts.confirm_deletes,
    empty_message = opts.empty_message,
    entries = {},
    expanded_tags = vim.deepcopy(opts.expanded_tags or {}),
    indent = opts.indent,
    keep_focus = opts.keep_focus,
    nodes = nodes,
    notify = opts.notify,
    open = opts.open,
    original_lines = {},
    scan = opts.scan or function()
      return {
        tag_tree = nodes,
      }
    end,
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

  vim.api.nvim_create_autocmd('BufWriteCmd', {
    buffer = bufnr,
    callback = function()
      local ok, err = M.write(bufnr)
      if ok == nil then
        notify_write_error(bufnr, err)
      end
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
    M.close(bufnr)
  end, {
    buffer = bufnr,
    nowait = true,
    silent = true,
  })

  vim.keymap.set('n', '<Esc>', function()
    M.close(bufnr)
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
