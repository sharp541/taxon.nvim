local source = debug.getinfo(1, 'S').source:sub(2)
local root = vim.fn.fnamemodify(source, ':p:h:h')
local root_lua = vim.fs.joinpath(root, 'lua')
local user_init = vim.fs.joinpath(vim.fn.stdpath('config'), 'init.lua')
local notes_dir = vim.fn.expand(vim.env.TAXON_DEV_NOTES_DIR or '~/notes')

local function is_other_taxon_path(path)
  local normalized = vim.fn.fnamemodify(path, ':p')

  if normalized == root then
    return false
  end

  return normalized:match('/taxon%.nvim/?$') ~= nil
end

local function split_path_list(value)
  local parts = {}

  for part in string.gmatch(value, '([^;]+)') do
    table.insert(parts, part)
  end

  return parts
end

local function join_path_list(parts)
  return table.concat(parts, ';')
end

local function normalize_lua_path(path)
  local normalized = path:gsub('/%?%.lua$', '')
  normalized = normalized:gsub('/%?/init%.lua$', '')
  return vim.fn.fnamemodify(normalized, ':p')
end

local function prefer_repo_on_runtimepath()
  local runtimepath = vim.opt.runtimepath:get()
  local filtered = {}

  for _, path in ipairs(runtimepath) do
    if not is_other_taxon_path(path) and vim.fn.fnamemodify(path, ':p') ~= root then
      table.insert(filtered, path)
    end
  end

  table.insert(filtered, 1, root)

  vim.opt.runtimepath = filtered
  vim.opt.packpath = filtered
end

local function prefer_repo_on_package_path()
  local repo_paths = {
    vim.fs.joinpath(root_lua, '?.lua'),
    vim.fs.joinpath(root_lua, '?', 'init.lua'),
  }
  local filtered = {}

  for _, path in ipairs(split_path_list(package.path)) do
    local normalized = normalize_lua_path(path)
    if normalized ~= root_lua and not is_other_taxon_path(normalized) then
      table.insert(filtered, path)
    end
  end

  for index = #repo_paths, 1, -1 do
    table.insert(filtered, 1, repo_paths[index])
  end

  package.path = join_path_list(filtered)
end

local function unload_taxon_modules()
  for name, _ in pairs(package.loaded) do
    if name == 'taxon' or vim.startswith(name, 'taxon.') then
      package.loaded[name] = nil
    end
  end

  vim.g.loaded_taxon = nil
end

local function setup_dev_taxon()
  require('taxon').setup({
    notes_dir = notes_dir,
  })
end

local function source_user_init(path)
  if vim.uv.fs_stat(path) == nil then
    return
  end

  local original_loaded = package.loaded.taxon
  local original_preload = package.preload.taxon

  package.loaded.taxon = {
    setup = function()
      return nil
    end,
  }
  package.preload.taxon = function()
    return package.loaded.taxon
  end

  local ok, err = xpcall(function()
    dofile(path)
  end, debug.traceback)

  package.loaded.taxon = original_loaded
  package.preload.taxon = original_preload

  if ok then
    return
  end

  vim.schedule(function()
    vim.notify(
      'Taxon dev init: failed to load ' .. path .. '\n' .. tostring(err),
      vim.log.levels.WARN
    )
  end)
end

prefer_repo_on_runtimepath()
prefer_repo_on_package_path()
source_user_init(user_init)
prefer_repo_on_runtimepath()
prefer_repo_on_package_path()
unload_taxon_modules()

dofile(vim.fs.joinpath(root, 'plugin', 'taxon.lua'))

setup_dev_taxon()

vim.schedule(function()
  vim.notify('Taxon dev: notes_dir=' .. notes_dir, vim.log.levels.INFO)
end)

vim.api.nvim_create_autocmd({ 'User', 'VimEnter' }, {
  pattern = { 'LazyDone', '*' },
  callback = function()
    prefer_repo_on_runtimepath()
    prefer_repo_on_package_path()
    unload_taxon_modules()
    dofile(vim.fs.joinpath(root, 'plugin', 'taxon.lua'))
    setup_dev_taxon()
  end,
})
