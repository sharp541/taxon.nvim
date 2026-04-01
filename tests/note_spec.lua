local helpers = dofile('tests/helpers.lua')
local note = require('taxon.note')

return {
  {
    name = 'render returns the canonical new-note template',
    run = function()
      local content = note.render('  Title  ')

      helpers.eq(
        table.concat({
          '---',
          'tags: []',
          '---',
          '',
          '# Title',
          '',
        }, '\n'),
        content
      )
    end,
  },
  {
    name = 'filename builds the timestamped note path from a fixed time',
    run = function()
      local filename = note.filename(' タイトル ', {
        year = 2026,
        month = 4,
        day = 2,
        hour = 1,
        min = 2,
        sec = 3,
      })

      helpers.eq('20260402-010203-タイトル.md', filename)
    end,
  },
  {
    name = 'parse reads tags and the first H1 title from a note',
    run = function()
      local parsed = note.parse(table.concat({
        '---',
        'tags:',
        '  - animal/mammal/cat',
        '  - Project/Client A',
        '---',
        '',
        'paragraph',
        '# Cat Note',
        '## Details',
      }, '\n'))

      helpers.eq({
        tags = { 'animal/mammal/cat', 'project/client a' },
        title = 'Cat Note',
      }, parsed)
    end,
  },
  {
    name = 'parse accepts inline tags and setext H1 titles',
    run = function()
      local parsed = note.parse(table.concat({
        '---',
        'tags: [animal/mammal/cat, "Client A / Draft"]',
        '---',
        '',
        'Setext Title',
        '===========',
      }, '\n'))

      helpers.eq({
        tags = { 'animal/mammal/cat', 'client a/draft' },
        title = 'Setext Title',
      }, parsed)
    end,
  },
  {
    name = 'parse canonicalizes tag order and removes case-insensitive duplicates',
    run = function()
      local parsed = note.parse(table.concat({
        '---',
        'tags:',
        '  - Zoo/Birds',
        '  - foo / Bar',
        '  - FOO/bar',
        '---',
        '',
        '# Canonical Tags',
      }, '\n'))

      helpers.eq({
        tags = { 'foo/bar', 'zoo/birds' },
        title = 'Canonical Tags',
      }, parsed)
    end,
  },
  {
    name = 'read returns structured note data from a file path',
    run = function()
      helpers.with_temp_dir(function(temp_dir)
        local path = vim.fs.joinpath(temp_dir, 'note.md')

        vim.fn.writefile({
          '---',
          'tags: []',
          '---',
          '',
          '# Read Title',
        }, path)

        local parsed = note.read(path)

        helpers.eq({
          path = path,
          tags = {},
          title = 'Read Title',
        }, parsed)
      end)
    end,
  },
  {
    name = 'parse rejects notes without frontmatter',
    run = function()
      local parsed, err = note.parse('# Missing Frontmatter\n')

      helpers.eq(nil, parsed)
      helpers.eq('missing-frontmatter', err)
    end,
  },
  {
    name = 'parse rejects unsupported frontmatter keys',
    run = function()
      local parsed, err = note.parse(table.concat({
        '---',
        'title: Wrong',
        '---',
        '',
        '# Wrong',
      }, '\n'))

      helpers.eq(nil, parsed)
      helpers.eq('unsupported-frontmatter', err)
    end,
  },
  {
    name = 'parse rejects invalid tag shapes',
    run = function()
      local parsed, err = note.parse(table.concat({
        '---',
        'tags: not-a-list',
        '---',
        '',
        '# Wrong',
      }, '\n'))

      helpers.eq(nil, parsed)
      helpers.eq('invalid-tags', err)
    end,
  },
  {
    name = 'parse rejects tags that fail normalization',
    run = function()
      local parsed, err = note.parse(table.concat({
        '---',
        'tags: [animal//cat]',
        '---',
        '',
        '# Wrong',
      }, '\n'))

      helpers.eq(nil, parsed)
      helpers.eq('invalid-tags', err)
    end,
  },
  {
    name = 'parse rejects notes without an H1 title',
    run = function()
      local parsed, err = note.parse(table.concat({
        '---',
        'tags: []',
        '---',
        '',
        'Body only',
      }, '\n'))

      helpers.eq(nil, parsed)
      helpers.eq('missing-title', err)
    end,
  },
  {
    name = 'render rejects invalid titles',
    run = function()
      local content, err = note.render(' \n ')

      helpers.eq(nil, content)
      helpers.eq('invalid-title', err)
    end,
  },
  {
    name = 'filename rejects titles with filename-unsafe characters',
    run = function()
      local filename, err = note.filename('bad/name', {
        year = 2026,
        month = 4,
        day = 2,
        hour = 1,
        min = 2,
        sec = 3,
      })

      helpers.eq(nil, filename)
      helpers.eq('unsafe-title', err)
    end,
  },
}
