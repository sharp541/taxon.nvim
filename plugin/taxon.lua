if vim.g.loaded_taxon then
  return
end

vim.g.loaded_taxon = 1

vim.api.nvim_create_user_command('TaxonOpen', function()
  require('taxon').open()
end, {
  desc = 'Open the taxon notes directory',
})

vim.api.nvim_create_user_command('TaxonNew', function()
  require('taxon').new_note()
end, {
  desc = 'Create a new taxon note',
})
