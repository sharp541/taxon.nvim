local source = debug.getinfo(1, 'S').source:sub(2)
local root = vim.fn.fnamemodify(source, ':p:h:h')
local user_init = vim.fs.joinpath(vim.fn.stdpath('config'), 'init.lua')
local notes_dir = vim.fn.expand(vim.env.TAXON_DEV_NOTES_DIR or '~/notes')

local function prefer_repo_on_runtimepath()
  vim.opt.runtimepath:remove(root)
  vim.opt.runtimepath:prepend(root)
  vim.opt.packpath = vim.o.runtimepath
end

local function unload_taxon_modules()
  for name, _ in pairs(package.loaded) do
    if name == 'taxon' or vim.startswith(name, 'taxon.') then
      package.loaded[name] = nil
    end
  end

  vim.g.loaded_taxon = nil
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
source_user_init(user_init)
prefer_repo_on_runtimepath()
unload_taxon_modules()

dofile(vim.fs.joinpath(root, 'plugin', 'taxon.lua'))

require('taxon').setup({
  notes_dir = notes_dir,
})

vim.schedule(function()
  vim.notify('Taxon dev: notes_dir=' .. notes_dir, vim.log.levels.INFO)
end)
