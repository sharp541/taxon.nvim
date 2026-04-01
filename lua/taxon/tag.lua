local M = {}

local CONTROL_CHAR_PATTERN = '[%z\1-\31\127]'

local function contains_control_characters(value)
  return value:find(CONTROL_CHAR_PATTERN) ~= nil
end

function M.normalize(tag)
  vim.validate({
    tag = { tag, 'string' },
  })

  if contains_control_characters(tag) then
    return nil, 'invalid-tag'
  end

  local segments = vim.split(tag, '/', {
    plain = true,
    trimempty = false,
  })
  local normalized_segments = {}

  for _, segment in ipairs(segments) do
    segment = vim.trim(segment)

    if segment == '' or contains_control_characters(segment) then
      return nil, 'invalid-tag'
    end

    table.insert(normalized_segments, vim.fn.tolower(segment))
  end

  return table.concat(normalized_segments, '/')
end

function M.normalize_all(tags)
  vim.validate({
    tags = { tags, 'table' },
  })

  local normalized_tags = {}
  local seen = {}

  for _, tag in ipairs(tags) do
    if type(tag) ~= 'string' then
      return nil, 'invalid-tag'
    end

    local normalized_tag, err = M.normalize(tag)
    if normalized_tag == nil then
      return nil, err
    end

    if not seen[normalized_tag] then
      seen[normalized_tag] = true
      table.insert(normalized_tags, normalized_tag)
    end
  end

  -- Canonicalize ordering so scans and UI output stay stable.
  table.sort(normalized_tags)

  return normalized_tags
end

return M
