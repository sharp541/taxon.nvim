local M = {}

local default_config = {
  notes_dir = vim.fn.stdpath('data') .. '/taxon-notes',
}

M.config = vim.deepcopy(default_config)
M.note = require('taxon.note')
M.query = require('taxon.query')
M.search_picker = require('taxon.search')
M.tag_tree_view = require('taxon.tag_tree_view')

local function normalize_notes_dir(path)
  if vim.startswith(path, '~') then
    return vim.fn.expand(path)
  end

  return path
end

local function ensure_notes_dir(path)
  path = normalize_notes_dir(path)

  local stat = vim.uv.fs_stat(path)
  if stat then
    return path
  end

  vim.fn.mkdir(path, 'p')
  return path
end

local function edit_path(path)
  vim.api.nvim_cmd({
    cmd = 'edit',
    args = { path },
  }, {})
end

local function write_note(path, content)
  local fd = vim.uv.fs_open(path, 'w', 420)
  if fd == nil then
    return nil, 'write-failed'
  end

  local write_ok, write_result = pcall(vim.uv.fs_write, fd, content, 0)
  local close_ok = pcall(vim.uv.fs_close, fd)

  if not write_ok or write_result == nil or not close_ok then
    return nil, 'write-failed'
  end

  return true
end

local function note_lines(content)
  return vim.split(content, '\n', {
    plain = true,
    trimempty = false,
  })
end

local function sync_opened_note(path, content)
  edit_path(path)
  vim.api.nvim_buf_set_lines(0, 0, -1, false, note_lines(content))

  local ok = pcall(vim.cmd, 'silent write')
  if not ok then
    return nil, 'write-failed'
  end

  return true
end

local function notify_create_error(err)
  local messages = {
    ['invalid-title'] = 'Taxon: title must not be blank or contain control characters',
    ['unsafe-title'] = 'Taxon: title contains filename-unsafe characters',
    ['note-exists'] = 'Taxon: note already exists for that timestamp and title',
    ['write-failed'] = 'Taxon: failed to write the new note',
  }

  vim.notify(
    messages[err] or ('Taxon: failed to create note (' .. err .. ')'),
    vim.log.levels.ERROR
  )
end

local function notify_search_error(kind, err)
  local messages = {
    search = {
      ['missing-telescope'] = 'Taxon: search requires Telescope (nvim-telescope/telescope.nvim)',
    },
    tree = {},
  }
  local action = ({
    search = 'search notes and tags',
    tree = 'open the tag tree',
  })[kind] or 'complete the search'

  vim.notify(
    (messages[kind] or {})[err] or ('Taxon: failed to ' .. action .. ' (' .. err .. ')'),
    vim.log.levels.ERROR
  )
end

function M.setup(opts)
  M.config = vim.tbl_deep_extend('force', vim.deepcopy(default_config), opts or {})
  M.config.notes_dir = ensure_notes_dir(M.config.notes_dir)
end

function M.create_note(title, opts)
  vim.validate({
    title = { title, 'string' },
    opts = { opts, 'table', true },
  })

  opts = opts or {}

  M.config.notes_dir = ensure_notes_dir(M.config.notes_dir)

  local filename, err = M.note.filename(title, opts.now)
  if filename == nil then
    return nil, err
  end

  local content
  content, err = M.note.render(title)
  if content == nil then
    return nil, err
  end

  local path = vim.fs.joinpath(M.config.notes_dir, filename)
  if vim.uv.fs_stat(path) ~= nil then
    return nil, 'note-exists'
  end

  local _, write_err = write_note(path, content)
  if write_err ~= nil then
    return nil, write_err
  end

  if opts.open ~= false then
    local _, sync_err = sync_opened_note(path, content)
    if sync_err ~= nil then
      return nil, sync_err
    end
  end

  return path
end

function M.scan_notes()
  M.config.notes_dir = ensure_notes_dir(M.config.notes_dir)
  return M.query.scan_dir(M.config.notes_dir)
end

function M.new_note()
  vim.ui.input({
    prompt = 'Taxon title: ',
  }, function(input)
    if input == nil then
      return
    end

    vim.schedule(function()
      local _, err = M.create_note(input)
      if err ~= nil then
        notify_create_error(err)
      end
    end)
  end)
end

function M.search(opts)
  vim.validate({
    opts = { opts, 'table', true },
  })

  opts = opts or {}

  local model, err = M.scan_notes()
  if model == nil then
    notify_search_error('search', err)
    return nil, err
  end

  local open = opts.open or edit_path
  local entries = M.search_picker.build_entries(model)
  local pick = opts.pick or M.search_picker.pick
  local pick_notes = opts.pick_notes or M.search_picker.pick
  local ok

  ok, err = pick(entries, {
    on_select = function(selection)
      if selection.kind == 'note' then
        M.search_picker.open_entry(selection, {
          open = open,
        })
        return
      end

      if selection.kind ~= 'tag' then
        return
      end

      local notes, find_err = M.query.find_by_tag(model, selection.tag)
      if notes == nil then
        notify_search_error('search', find_err)
        return
      end

      local note_entries = M.search_picker.build_note_entries(notes)
      local note_ok, note_err = pick_notes(note_entries, {
        open = open,
        prompt_title = opts.results_prompt_title or ('Taxon Search: ' .. selection.tag),
        telescope = opts.telescope,
      })

      if note_ok == nil then
        notify_search_error('search', note_err)
      end
    end,
    prompt_title = opts.prompt_title,
    telescope = opts.telescope,
  })

  if ok == nil then
    notify_search_error('search', err)
    return nil, err
  end

  return true
end

function M.show_tag_tree(opts)
  vim.validate({
    opts = { opts, 'table', true },
  })

  opts = opts or {}

  local model, err = M.scan_notes()
  if model == nil then
    notify_search_error('tree', err)
    return nil, err
  end

  local show = opts.show or M.tag_tree_view.open
  local ok

  ok, err = show(model.tag_tree, {
    empty_message = opts.empty_message,
    expanded_tags = opts.expanded_tags,
    indent = opts.indent,
    keep_focus = opts.keep_focus,
    open = opts.open,
    open_window = opts.open_window,
    source_win = opts.source_win,
    width = opts.width,
    window_command = opts.window_command,
  })

  if ok == nil then
    notify_search_error('tree', err)
    return nil, err
  end

  return ok
end

return M
