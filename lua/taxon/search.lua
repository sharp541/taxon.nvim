local M = {}

local function default_open(path)
  vim.api.nvim_cmd({
    cmd = 'edit',
    args = { path },
  }, {})
end

local function resolve_telescope(telescope)
  if telescope ~= nil then
    return telescope
  end

  local ok_pickers, pickers = pcall(require, 'telescope.pickers')
  local ok_finders, finders = pcall(require, 'telescope.finders')
  local ok_config, config = pcall(require, 'telescope.config')
  local ok_actions, actions = pcall(require, 'telescope.actions')
  local ok_action_state, action_state = pcall(require, 'telescope.actions.state')

  if not (ok_pickers and ok_finders and ok_config and ok_actions and ok_action_state) then
    return nil, 'missing-telescope'
  end

  return {
    action_state = action_state,
    actions = actions,
    config = config,
    finders = finders,
    pickers = pickers,
  }
end

function M.build_note_entries(notes, opts)
  vim.validate({
    notes = { notes, 'table' },
    opts = { opts, 'table', true },
  })

  opts = opts or {}

  local entries = {}
  local prefix_kind = opts.prefix_kind == true

  for _, note in ipairs(notes) do
    local filename = vim.fs.basename(note.path)
    local display = string.format('%s [%s]', note.title, filename)
    local ordinal = string.format('%s %s %s', note.title, filename, note.path)

    if prefix_kind then
      display = '[Title] ' .. display
      ordinal = 'title ' .. ordinal
    end

    table.insert(entries, {
      display = display,
      kind = 'note',
      ordinal = ordinal,
      path = note.path,
      title = note.title,
    })
  end

  return entries
end

function M.build_tag_entries(tags, opts)
  vim.validate({
    tags = { tags, 'table' },
    opts = { opts, 'table', true },
  })

  opts = opts or {}

  local entries = {}
  local prefix_kind = opts.prefix_kind == true

  for _, current_tag in ipairs(tags) do
    local spaced_tag = current_tag:gsub('/', ' / ')
    local display = current_tag
    local ordinal = string.format('%s %s', current_tag, spaced_tag)

    if prefix_kind then
      display = '[Tag] ' .. display
      ordinal = 'tag ' .. ordinal
    end

    table.insert(entries, {
      display = display,
      kind = 'tag',
      ordinal = ordinal,
      tag = current_tag,
    })
  end

  return entries
end

function M.build_entries(model)
  vim.validate({
    model = { model, 'table' },
    ['model.notes'] = { model.notes, 'table' },
    ['model.tags'] = { model.tags, 'table' },
  })

  local entries = M.build_note_entries(model.notes, {
    prefix_kind = true,
  })

  vim.list_extend(
    entries,
    M.build_tag_entries(model.tags, {
      prefix_kind = true,
    })
  )

  return entries
end

function M.open_entry(entry, opts)
  vim.validate({
    entry = { entry, 'table' },
    opts = { opts, 'table', true },
  })

  opts = opts or {}

  local open = opts.open or default_open
  return open(entry.path)
end

function M.pick(entries, opts)
  vim.validate({
    entries = { entries, 'table' },
    opts = { opts, 'table', true },
  })

  opts = opts or {}

  local telescope, err = resolve_telescope(opts.telescope)
  if telescope == nil then
    return nil, err
  end

  local finder = telescope.finders.new_table({
    results = entries,
    entry_maker = function(entry)
      return {
        display = entry.display,
        ordinal = entry.ordinal,
        value = entry,
      }
    end,
  })

  local picker = telescope.pickers.new({}, {
    prompt_title = opts.prompt_title or 'Taxon Search',
    finder = finder,
    sorter = telescope.config.values.generic_sorter({}),
    attach_mappings = function(prompt_bufnr)
      telescope.actions.select_default:replace(function()
        local selection = telescope.action_state.get_selected_entry()

        telescope.actions.close(prompt_bufnr)

        if selection == nil or selection.value == nil then
          return
        end

        if opts.on_select ~= nil then
          opts.on_select(selection.value)
          return
        end

        if selection.value.path ~= nil then
          M.open_entry(selection.value, {
            open = opts.open,
          })
        end
      end)

      return true
    end,
  })

  picker:find()
  return true
end

return M
