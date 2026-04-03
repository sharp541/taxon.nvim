local M = {}
local tag = require('taxon.tag')

local function is_blank(line)
  return line:match('^%s*$') ~= nil
end

local function normalize_title(title)
  local trimmed_title = vim.trim(title)
  if trimmed_title == '' or trimmed_title:find('%c') ~= nil then
    return nil, 'invalid-title'
  end

  return trimmed_title
end

local function validate_filename_title(title)
  local trimmed_title, err = normalize_title(title)
  if trimmed_title == nil then
    return nil, err
  end

  if trimmed_title:find('[/\\:*?"<>|]') ~= nil then
    return nil, 'unsafe-title'
  end

  return trimmed_title
end

local function format_timestamp(now)
  return string.format(
    '%04d%02d%02d-%02d%02d%02d',
    now.year,
    now.month,
    now.day,
    now.hour,
    now.min,
    now.sec
  )
end

local function parse_scalar(raw)
  local value = vim.trim(raw)

  if value == '' then
    return nil
  end

  local quote = value:sub(1, 1)
  if quote ~= "'" and quote ~= '"' then
    return value
  end

  if value:sub(-1) ~= quote or #value < 2 then
    return nil
  end

  value = value:sub(2, -2)

  if quote == "'" then
    return value:gsub("''", "'")
  end

  value = value:gsub('\\"', '"')
  value = value:gsub('\\\\', '\\')
  value = value:gsub('\\n', '\n')
  value = value:gsub('\\r', '\r')
  value = value:gsub('\\t', '\t')

  return value
end

local function split_flow_items(raw)
  local items = {}
  local current = {}
  local quote
  local index = 1

  while index <= #raw do
    local char = raw:sub(index, index)

    if quote == "'" then
      table.insert(current, char)
      if char == "'" then
        local next_char = raw:sub(index + 1, index + 1)
        if next_char == "'" then
          table.insert(current, next_char)
          index = index + 1
        else
          quote = nil
        end
      end
    elseif quote == '"' then
      table.insert(current, char)
      if char == '\\' then
        local next_char = raw:sub(index + 1, index + 1)
        if next_char ~= '' then
          table.insert(current, next_char)
          index = index + 1
        end
      elseif char == '"' then
        quote = nil
      end
    elseif char == ',' then
      table.insert(items, table.concat(current))
      current = {}
    else
      table.insert(current, char)
      if char == "'" or char == '"' then
        quote = char
      end
    end

    index = index + 1
  end

  if quote ~= nil then
    return nil
  end

  table.insert(items, table.concat(current))

  return items
end

local function parse_flow_tags(raw)
  local value = vim.trim(raw)
  if value == '[]' then
    return {}
  end

  if not value:match('^%[.*%]$') then
    return nil
  end

  local inner = vim.trim(value:sub(2, -2))
  if inner == '' then
    return {}
  end

  local items = split_flow_items(inner)
  if items == nil then
    return nil
  end

  local tags = {}

  for _, item in ipairs(items) do
    local tag = parse_scalar(item)
    if tag == nil then
      return nil
    end

    table.insert(tags, tag)
  end

  return tags
end

local function parse_frontmatter(lines)
  local tags
  local index = 1

  while index <= #lines do
    local line = lines[index]

    if is_blank(line) then
      index = index + 1
    else
      local rest = line:match('^tags:%s*(.*)$')
      if rest == nil then
        return nil, 'unsupported-frontmatter'
      end

      if tags ~= nil then
        return nil, 'duplicate-tags'
      end

      if vim.trim(rest) == '' then
        tags = {}
        index = index + 1

        while index <= #lines do
          local item_line = lines[index]
          if is_blank(item_line) then
            index = index + 1
          else
            local item = item_line:match('^%s*%-%s*(.*)$')
            if item == nil then
              break
            end

            local tag = parse_scalar(item)
            if tag == nil then
              return nil, 'invalid-tags'
            end

            table.insert(tags, tag)
            index = index + 1
          end
        end
      else
        tags = parse_flow_tags(rest)
        if tags == nil then
          return nil, 'invalid-tags'
        end

        index = index + 1
      end
    end
  end

  if tags == nil then
    return nil, 'missing-tags'
  end

  local normalized_tags, err = tag.normalize_all(tags)
  if normalized_tags == nil then
    return nil, 'invalid-tags'
  end

  return {
    tags = normalized_tags,
  }
end

local function extract_title(lines)
  local index = 1

  while index <= #lines do
    local line = lines[index]
    local atx_title = line:match('^#%s+(.+)$')

    if atx_title ~= nil then
      atx_title = atx_title:gsub('%s*#+%s*$', '')
      atx_title = vim.trim(atx_title)
      if atx_title ~= '' then
        return atx_title
      end
    end

    local next_line = lines[index + 1]
    if next_line ~= nil and line:match('%S') and next_line:match('^=+%s*$') then
      return vim.trim(line)
    end

    index = index + 1
  end

  return nil
end

local function parse_lines(lines)
  if #lines == 0 or not lines[1]:match('^%-%-%-%s*$') then
    return nil, 'missing-frontmatter'
  end

  local closing_index
  for index = 2, #lines do
    if lines[index]:match('^%-%-%-%s*$') then
      closing_index = index
      break
    end
  end

  if closing_index == nil then
    return nil, 'unterminated-frontmatter'
  end

  local frontmatter_lines = {}
  for index = 2, closing_index - 1 do
    table.insert(frontmatter_lines, lines[index])
  end

  local body_lines = {}
  for index = closing_index + 1, #lines do
    table.insert(body_lines, lines[index])
  end

  local frontmatter, err = parse_frontmatter(frontmatter_lines)
  if frontmatter == nil then
    return nil, err
  end

  local title = extract_title(body_lines)
  if title == nil then
    return nil, 'missing-title'
  end

  return {
    tags = frontmatter.tags,
    title = title,
  }
end

local function parse_document_lines(lines)
  if #lines == 0 or not lines[1]:match('^%-%-%-%s*$') then
    return nil, 'missing-frontmatter'
  end

  local closing_index
  for index = 2, #lines do
    if lines[index]:match('^%-%-%-%s*$') then
      closing_index = index
      break
    end
  end

  if closing_index == nil then
    return nil, 'unterminated-frontmatter'
  end

  local frontmatter_lines = {}
  for index = 2, closing_index - 1 do
    table.insert(frontmatter_lines, lines[index])
  end

  local frontmatter, err = parse_frontmatter(frontmatter_lines)
  if frontmatter == nil then
    return nil, err
  end

  local body_lines = {}
  for index = closing_index + 1, #lines do
    table.insert(body_lines, lines[index])
  end

  local title = extract_title(body_lines)
  if title == nil then
    return nil, 'missing-title'
  end

  return {
    body_lines = body_lines,
    tags = frontmatter.tags,
    title = title,
  }
end

local function render_tags_frontmatter(tags)
  if #tags == 0 then
    return {
      '---',
      'tags: []',
      '---',
    }
  end

  local lines = {
    '---',
    'tags:',
  }

  for _, current_tag in ipairs(tags) do
    table.insert(lines, '  - ' .. current_tag)
  end

  table.insert(lines, '---')

  return lines
end

local function read_lines(path)
  local ok, lines = pcall(vim.fn.readfile, path)
  if not ok then
    return nil, 'read-failed'
  end

  return lines
end

local function write_lines(path, lines)
  local ok = pcall(vim.fn.writefile, lines, path)
  if not ok then
    return nil, 'write-failed'
  end

  return true
end

local function contains_filename_unsafe_characters(value)
  return value:find('[/\\:*?"<>|]') ~= nil
end

local function validate_basename(basename)
  if type(basename) ~= 'string' then
    return nil, 'invalid-basename'
  end

  local trimmed = vim.trim(basename)
  if trimmed == '' or trimmed:find('%c') ~= nil then
    return nil, 'invalid-basename'
  end

  if contains_filename_unsafe_characters(trimmed) then
    return nil, 'unsafe-basename'
  end

  if not trimmed:lower():match('%.md$') then
    return nil, 'invalid-extension'
  end

  return trimmed
end

function M.parse(content)
  vim.validate({
    content = { content, 'string' },
  })

  local lines = vim.split(content, '\n', {
    plain = true,
    trimempty = false,
  })

  return parse_lines(lines)
end

function M.read(path)
  vim.validate({
    path = { path, 'string' },
  })

  local lines, read_err = read_lines(path)
  if lines == nil then
    return nil, read_err
  end

  local note, err = parse_lines(lines)
  if note == nil then
    return nil, err
  end

  note.path = path
  return note
end

function M.read_document(path)
  vim.validate({
    path = { path, 'string' },
  })

  local lines, read_err = read_lines(path)
  if lines == nil then
    return nil, read_err
  end

  local document, err = parse_document_lines(lines)
  if document == nil then
    return nil, err
  end

  document.path = path

  return document
end

function M.render(title)
  vim.validate({
    title = { title, 'string' },
  })

  local trimmed_title, err = normalize_title(title)
  if trimmed_title == nil then
    return nil, err
  end

  return table.concat({
    '---',
    'tags: []',
    '---',
    '',
    '# ' .. trimmed_title,
    '',
  }, '\n')
end

function M.filename(title, now)
  vim.validate({
    title = { title, 'string' },
    now = { now, 'table', true },
  })

  local trimmed_title, err = validate_filename_title(title)
  if trimmed_title == nil then
    return nil, err
  end

  local timestamp = format_timestamp(now or os.date('*t'))
  return string.format('%s-%s.md', timestamp, trimmed_title)
end

function M.write_tags(path, tags)
  vim.validate({
    path = { path, 'string' },
    tags = { tags, 'table' },
  })

  local normalized_tags, err = tag.normalize_all(tags)
  if normalized_tags == nil then
    return nil, err
  end

  local document
  document, err = M.read_document(path)
  if document == nil then
    return nil, err
  end

  local lines = render_tags_frontmatter(normalized_tags)
  for _, line in ipairs(document.body_lines) do
    table.insert(lines, line)
  end

  local ok, write_err = write_lines(path, lines)
  if ok == nil then
    return nil, write_err
  end

  return true
end

function M.rename_file(path, basename)
  vim.validate({
    path = { path, 'string' },
    basename = { basename, 'string' },
  })

  local normalized_basename, err = validate_basename(basename)
  if normalized_basename == nil then
    return nil, err
  end

  local target_path = vim.fs.joinpath(vim.fs.dirname(path), normalized_basename)
  if target_path == path then
    return path
  end

  if vim.uv.fs_stat(target_path) ~= nil then
    return nil, 'path-exists'
  end

  local ok, rename_err = pcall(vim.uv.fs_rename, path, target_path)
  if not ok or not rename_err then
    return nil, 'rename-failed'
  end

  return target_path
end

function M.delete_file(path)
  vim.validate({
    path = { path, 'string' },
  })

  local ok, result = pcall(vim.uv.fs_unlink, path)
  if not ok or not result then
    return nil, 'delete-failed'
  end

  return true
end

return M
