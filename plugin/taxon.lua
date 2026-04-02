if vim.g.loaded_taxon then
  return
end

vim.g.loaded_taxon = 1

vim.api.nvim_create_user_command('TaxonNew', function()
  require('taxon').new_note()
end, {
  desc = 'Create a new taxon note',
})

vim.api.nvim_create_user_command('TaxonSearch', function()
  require('taxon').search()
end, {
  desc = 'Search taxon notes and tags with Telescope',
})

vim.api.nvim_create_user_command('TaxonTagTree', function()
  require('taxon').show_tag_tree()
end, {
  desc = 'Show the taxon tag tree',
})
