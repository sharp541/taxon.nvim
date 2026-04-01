local helpers = dofile('tests/helpers.lua')
local tag = require('taxon.tag')

return {
  {
    name = 'normalize applies the spec examples and preserves Japanese text',
    run = function()
      helpers.eq('foo/bar', tag.normalize('Foo / Bar'))
      helpers.eq('project/client a', tag.normalize('Project/Client A'))
      helpers.eq('分類/猫 ノート', tag.normalize('分類 / 猫 ノート'))
    end,
  },
  {
    name = 'normalize_all deduplicates case-insensitively and sorts output',
    run = function()
      local normalized = tag.normalize_all({
        'Zoo/Birds',
        'foo / Bar',
        'FOO/bar',
        '分類 / 猫',
      })

      helpers.eq({
        'foo/bar',
        'zoo/birds',
        '分類/猫',
      }, normalized)
    end,
  },
  {
    name = 'normalize rejects representative invalid tag inputs',
    run = function()
      for _, raw in ipairs({
        '',
        ' / animal',
        'animal / ',
        'animal//cat',
        'animal/\ncat',
        'animal/\tcat',
      }) do
        local normalized, err = tag.normalize(raw)

        helpers.eq(nil, normalized, 'expected invalid tag for ' .. vim.inspect(raw))
        helpers.eq('invalid-tag', err, 'wrong error for ' .. vim.inspect(raw))
      end
    end,
  },
}
