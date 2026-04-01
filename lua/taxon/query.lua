local M = {}

local note = require('taxon.note')
local tag = require('taxon.tag')

local function new_model()
  return {
    notes = {},
    tags = {},
    tag_tree = {},
    notes_by_title = {},
    notes_by_tag = {},
    invalid_notes = {},
  }
end

local function copy_list(values)
  local copy = {}

  for index, value in ipairs(values) do
    copy[index] = value
  end

  return copy
end

local function sort_notes(notes)
  table.sort(notes, function(left, right)
    if left.title == right.title then
      return left.path < right.path
    end

    return left.title < right.title
  end)
end

local function add_index_entry(index, key, value)
  local entries = index[key]

  if entries == nil then
    entries = {}
    index[key] = entries
  end

  table.insert(entries, value)
end

local function copy_and_sort_notes(notes)
  local copy = copy_list(notes or {})
  sort_notes(copy)
  return copy
end

local function sort_tag_tree(nodes)
  table.sort(nodes, function(left, right)
    return left.tag < right.tag
  end)

  for _, node in ipairs(nodes) do
    sort_tag_tree(node.children)
  end
end

local function list_note_paths(notes_dir)
  local stat = vim.uv.fs_stat(notes_dir)
  if stat == nil then
    return {}
  end

  if stat.type ~= 'directory' then
    return nil, 'invalid-notes-dir'
  end

  local handle = vim.uv.fs_scandir(notes_dir)
  if handle == nil then
    return nil, 'scan-failed'
  end

  local paths = {}

  while true do
    local name, entry_type = vim.uv.fs_scandir_next(handle)
    if name == nil then
      break
    end

    if entry_type == 'file' and name:lower():sub(-3) == '.md' then
      table.insert(paths, vim.fs.joinpath(notes_dir, name))
    end
  end

  table.sort(paths)

  return paths
end

function M.derive_tags(explicit_tags)
  vim.validate({
    explicit_tags = { explicit_tags, 'table' },
  })

  local derived_tags = {}
  local seen = {}

  for _, explicit_tag in ipairs(explicit_tags) do
    local segments = vim.split(explicit_tag, '/', {
      plain = true,
      trimempty = false,
    })
    local current = nil

    for _, segment in ipairs(segments) do
      if current == nil then
        current = segment
      else
        current = current .. '/' .. segment
      end

      if not seen[current] then
        seen[current] = true
        table.insert(derived_tags, current)
      end
    end
  end

  table.sort(derived_tags)

  return derived_tags
end

function M.build_tag_tree(model)
  vim.validate({
    model = { model, 'table' },
  })

  local tags = model.tags or {}
  local notes_by_tag = model.notes_by_tag or {}
  local roots = {}
  local nodes_by_tag = {}

  for _, current_tag in ipairs(tags) do
    local segments = vim.split(current_tag, '/', {
      plain = true,
      trimempty = false,
    })
    local parent_children = roots
    local path = nil

    for _, segment in ipairs(segments) do
      if path == nil then
        path = segment
      else
        path = path .. '/' .. segment
      end

      local node = nodes_by_tag[path]
      if node == nil then
        node = {
          children = {},
          name = segment,
          notes = copy_and_sort_notes(notes_by_tag[path]),
          tag = path,
        }
        nodes_by_tag[path] = node
        table.insert(parent_children, node)
      end

      parent_children = node.children
    end
  end

  sort_tag_tree(roots)

  return roots
end

function M.scan_dir(notes_dir)
  vim.validate({
    notes_dir = { notes_dir, 'string' },
  })

  local paths, err = list_note_paths(notes_dir)
  if paths == nil then
    return nil, err
  end

  local model = new_model()
  local seen_tags = {}

  for _, path in ipairs(paths) do
    local parsed, parse_err = note.read(path)
    if parsed == nil then
      table.insert(model.invalid_notes, {
        error = parse_err,
        path = path,
      })
    else
      local explicit_tags = copy_list(parsed.tags)
      local all_tags = M.derive_tags(explicit_tags)
      local scanned_note = {
        explicit_tags = explicit_tags,
        path = path,
        tags = all_tags,
        title = parsed.title,
      }

      table.insert(model.notes, scanned_note)
      add_index_entry(model.notes_by_title, scanned_note.title, scanned_note)

      for _, current_tag in ipairs(all_tags) do
        add_index_entry(model.notes_by_tag, current_tag, scanned_note)

        if not seen_tags[current_tag] then
          seen_tags[current_tag] = true
          table.insert(model.tags, current_tag)
        end
      end
    end
  end

  sort_notes(model.notes)
  table.sort(model.tags)

  for _, notes in pairs(model.notes_by_title) do
    sort_notes(notes)
  end

  for _, notes in pairs(model.notes_by_tag) do
    sort_notes(notes)
  end

  model.tag_tree = M.build_tag_tree(model)

  return model
end

function M.find_by_title(model, title)
  vim.validate({
    model = { model, 'table' },
    title = { title, 'string' },
  })

  return copy_list(model.notes_by_title[title] or {})
end

function M.find_by_tag(model, raw_tag)
  vim.validate({
    model = { model, 'table' },
    raw_tag = { raw_tag, 'string' },
  })

  local normalized_tag, err = tag.normalize(raw_tag)
  if normalized_tag == nil then
    return nil, err
  end

  return copy_list(model.notes_by_tag[normalized_tag] or {})
end

return M
