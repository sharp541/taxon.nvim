local helpers = dofile('tests/helpers.lua')
local query = require('taxon.query')

local function write_file(path, lines)
  vim.fn.writefile(lines, path)
end

return {
  {
    name = 'derive_tags expands parent tags once and sorts the result',
    run = function()
      local derived_tags = query.derive_tags({
        'animal/mammal/cat',
        'project/client a',
        'animal/bird',
      })

      helpers.eq({
        'animal',
        'animal/bird',
        'animal/mammal',
        'animal/mammal/cat',
        'project',
        'project/client a',
      }, derived_tags)
    end,
  },
  {
    name = 'build_tag_tree nests slash-delimited tags with deterministic note membership',
    run = function()
      local bird_note = {
        path = '/tmp/20260402-010203-bird.md',
        title = 'Bird Note',
      }
      local cat_note = {
        path = '/tmp/20260402-020304-cat.md',
        title = 'Cat Note',
      }

      local tree = query.build_tag_tree({
        tags = {
          'project/client a',
          'animal/mammal/cat',
          'animal/bird',
        },
        notes_by_tag = {
          animal = {
            cat_note,
            bird_note,
          },
          ['animal/bird'] = {
            bird_note,
          },
          ['animal/mammal'] = {
            cat_note,
          },
          ['animal/mammal/cat'] = {
            cat_note,
          },
          project = {
            cat_note,
          },
          ['project/client a'] = {
            cat_note,
          },
        },
      })

      helpers.eq({
        {
          children = {
            {
              children = {},
              name = 'bird',
              notes = {
                bird_note,
              },
              tag = 'animal/bird',
            },
            {
              children = {
                {
                  children = {},
                  name = 'cat',
                  notes = {
                    cat_note,
                  },
                  tag = 'animal/mammal/cat',
                },
              },
              name = 'mammal',
              notes = {
                cat_note,
              },
              tag = 'animal/mammal',
            },
          },
          name = 'animal',
          notes = {
            bird_note,
            cat_note,
          },
          tag = 'animal',
        },
        {
          children = {
            {
              children = {},
              name = 'client a',
              notes = {
                cat_note,
              },
              tag = 'project/client a',
            },
          },
          name = 'project',
          notes = {
            cat_note,
          },
          tag = 'project',
        },
      }, tree)
    end,
  },
  {
    name = 'scan_dir builds note, title, and tag indexes from markdown notes',
    run = function()
      helpers.with_temp_dir(function(temp_dir)
        local bird_path = vim.fs.joinpath(temp_dir, '20260402-010203-bird.md')
        local cat_path = vim.fs.joinpath(temp_dir, '20260402-020304-cat.md')

        write_file(bird_path, {
          '---',
          'tags: [animal/bird]',
          '---',
          '',
          '# Bird Note',
        })
        write_file(cat_path, {
          '---',
          'tags:',
          '  - animal/mammal/cat',
          '  - Project/Client A',
          '---',
          '',
          '# Cat Note',
        })
        write_file(vim.fs.joinpath(temp_dir, 'ignore.txt'), {
          'not a note',
        })

        local model = query.scan_dir(temp_dir)
        local bird_note = {
          explicit_tags = { 'animal/bird' },
          path = bird_path,
          tags = { 'animal', 'animal/bird' },
          title = 'Bird Note',
        }
        local cat_note = {
          explicit_tags = { 'animal/mammal/cat', 'project/client a' },
          path = cat_path,
          tags = {
            'animal',
            'animal/mammal',
            'animal/mammal/cat',
            'project',
            'project/client a',
          },
          title = 'Cat Note',
        }

        helpers.eq({
          bird_note,
          cat_note,
        }, model.notes)
        helpers.eq({
          'animal',
          'animal/bird',
          'animal/mammal',
          'animal/mammal/cat',
          'project',
          'project/client a',
        }, model.tags)
        helpers.eq({
          {
            children = {
              {
                children = {},
                name = 'bird',
                notes = {
                  bird_note,
                },
                tag = 'animal/bird',
              },
              {
                children = {
                  {
                    children = {},
                    name = 'cat',
                    notes = {
                      cat_note,
                    },
                    tag = 'animal/mammal/cat',
                  },
                },
                name = 'mammal',
                notes = {
                  cat_note,
                },
                tag = 'animal/mammal',
              },
            },
            name = 'animal',
            notes = {
              bird_note,
              cat_note,
            },
            tag = 'animal',
          },
          {
            children = {
              {
                children = {},
                name = 'client a',
                notes = {
                  cat_note,
                },
                tag = 'project/client a',
              },
            },
            name = 'project',
            notes = {
              cat_note,
            },
            tag = 'project',
          },
        }, model.tag_tree)
        helpers.eq({}, model.invalid_notes)
        helpers.eq({
          cat_note,
        }, query.find_by_title(model, 'Cat Note'))
        helpers.eq({}, query.find_by_title(model, 'Missing Note'))
        helpers.eq({
          cat_note,
        }, query.find_by_tag(model, 'Animal / Mammal'))
        helpers.eq({
          cat_note,
        }, query.find_by_tag(model, 'project'))
        helpers.eq({}, query.find_by_tag(model, 'unknown'))
      end)
    end,
  },
  {
    name = 'scan_dir skips invalid notes and reports deterministic parse errors',
    run = function()
      helpers.with_temp_dir(function(temp_dir)
        local invalid_tags_path = vim.fs.joinpath(temp_dir, '20260402-010203-invalid-tags.md')
        local valid_path = vim.fs.joinpath(temp_dir, '20260402-020304-valid.md')
        local missing_title_path = vim.fs.joinpath(temp_dir, '20260402-030405-missing-title.md')

        write_file(invalid_tags_path, {
          '---',
          'tags: [animal//bird]',
          '---',
          '',
          '# Invalid Tags',
        })
        write_file(valid_path, {
          '---',
          'tags: [project/client a]',
          '---',
          '',
          '# Valid Note',
        })
        write_file(missing_title_path, {
          '---',
          'tags: []',
          '---',
          '',
          'Body only',
        })

        local model = query.scan_dir(temp_dir)

        helpers.eq({
          {
            explicit_tags = { 'project/client a' },
            path = valid_path,
            tags = { 'project', 'project/client a' },
            title = 'Valid Note',
          },
        }, model.notes)
        helpers.eq({
          {
            children = {
              {
                children = {},
                name = 'client a',
                notes = {
                  {
                    explicit_tags = { 'project/client a' },
                    path = valid_path,
                    tags = { 'project', 'project/client a' },
                    title = 'Valid Note',
                  },
                },
                tag = 'project/client a',
              },
            },
            name = 'project',
            notes = {
              {
                explicit_tags = { 'project/client a' },
                path = valid_path,
                tags = { 'project', 'project/client a' },
                title = 'Valid Note',
              },
            },
            tag = 'project',
          },
        }, model.tag_tree)
        helpers.eq({
          {
            error = 'invalid-tags',
            path = invalid_tags_path,
          },
          {
            error = 'missing-title',
            path = missing_title_path,
          },
        }, model.invalid_notes)
      end)
    end,
  },
  {
    name = 'find_by_tag rejects invalid lookup tags',
    run = function()
      local notes, err = query.find_by_tag({
        notes_by_tag = {},
      }, 'animal/\ncat')

      helpers.eq(nil, notes)
      helpers.eq('invalid-tag', err)
    end,
  },
}
