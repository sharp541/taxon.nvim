local M = {}

local default_config = {
  notes_dir = vim.fn.stdpath('data') .. '/taxon-notes',
}

M.config = vim.deepcopy(default_config)

local function ensure_notes_dir(path)
  local stat = vim.uv.fs_stat(path)
  if stat then
    return
  end

  vim.fn.mkdir(path, 'p')
end

function M.setup(opts)
  M.config = vim.tbl_deep_extend('force', vim.deepcopy(default_config), opts or {})
  ensure_notes_dir(M.config.notes_dir)
end

function M.open()
  ensure_notes_dir(M.config.notes_dir)
  vim.cmd.edit(M.config.notes_dir)
end

return M
