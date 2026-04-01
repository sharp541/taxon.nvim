local M = {}

local default_config = {
  notes_dir = vim.fn.stdpath('data') .. '/taxon-notes',
}

M.config = vim.deepcopy(default_config)
M.note = require('taxon.note')
M.query = require('taxon.query')
M.title_search = require('taxon.title_search')

local function ensure_notes_dir(path)
  local stat = vim.uv.fs_stat(path)
  if stat then
    return
  end

  vim.fn.mkdir(path, 'p')
end

local function edit_path(path)
  vim.api.nvim_cmd({
    cmd = 'edit',
    args = { path },
  }, {})
end

local function write_note(path, content)
  local ok = pcall(
    vim.fn.writefile,
    vim.split(content, '\n', {
      plain = true,
      trimempty = true,
    }),
    path
  )

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

local function notify_search_error(err)
  local messages = {
    ['missing-telescope'] = 'Taxon: title search requires Telescope (nvim-telescope/telescope.nvim)',
  }

  vim.notify(
    messages[err] or ('Taxon: failed to search titles (' .. err .. ')'),
    vim.log.levels.ERROR
  )
end

function M.setup(opts)
  M.config = vim.tbl_deep_extend('force', vim.deepcopy(default_config), opts or {})
  ensure_notes_dir(M.config.notes_dir)
end

function M.open()
  ensure_notes_dir(M.config.notes_dir)
  edit_path(M.config.notes_dir)
end

function M.create_note(title, opts)
  vim.validate({
    title = { title, 'string' },
    opts = { opts, 'table', true },
  })

  opts = opts or {}

  ensure_notes_dir(M.config.notes_dir)

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
    edit_path(path)
  end

  return path
end

function M.scan_notes()
  ensure_notes_dir(M.config.notes_dir)
  return M.query.scan_dir(M.config.notes_dir)
end

function M.new_note()
  vim.ui.input({
    prompt = 'Taxon title: ',
  }, function(input)
    if input == nil then
      return
    end

    local _, err = M.create_note(input)
    if err ~= nil then
      notify_create_error(err)
    end
  end)
end

function M.search_titles(opts)
  vim.validate({
    opts = { opts, 'table', true },
  })

  opts = opts or {}

  local model, err = M.scan_notes()
  if model == nil then
    notify_search_error(err)
    return nil, err
  end

  local entries = M.title_search.build_entries(model.notes)
  local pick = opts.pick or M.title_search.pick
  local ok

  ok, err = pick(entries, {
    open = opts.open or edit_path,
    prompt_title = opts.prompt_title,
    telescope = opts.telescope,
  })

  if ok == nil then
    notify_search_error(err)
    return nil, err
  end

  return true
end

return M
