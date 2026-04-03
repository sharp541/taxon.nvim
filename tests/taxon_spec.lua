local helpers = dofile('tests/helpers.lua')
local taxon = require('taxon')

return {
  {
    name = 'setup creates the configured notes directory',
    run = function()
      helpers.with_temp_dir(function(temp_dir)
        local notes_dir = vim.fs.joinpath(temp_dir, 'notes')

        taxon.setup({
          notes_dir = notes_dir,
        })

        local stat = vim.uv.fs_stat(notes_dir)

        helpers.truthy(stat ~= nil, 'notes directory was not created')
        helpers.eq('directory', stat.type, 'notes path is not a directory')
        helpers.eq(notes_dir, taxon.config.notes_dir, 'setup did not persist config')
      end)
    end,
  },
  {
    name = 'create_note writes the canonical file and opens it',
    run = function()
      helpers.with_temp_dir(function(temp_dir)
        local notes_dir = vim.fs.joinpath(temp_dir, 'notes')

        taxon.setup({
          notes_dir = notes_dir,
        })

        local path = taxon.create_note('Title', {
          now = {
            year = 2026,
            month = 4,
            day = 2,
            hour = 1,
            min = 2,
            sec = 3,
          },
        })

        helpers.eq(vim.fs.joinpath(notes_dir, '20260402-010203-Title.md'), path)
        helpers.eq(path, vim.api.nvim_buf_get_name(0), 'created note was not opened')
        helpers.eq({
          '---',
          'tags: []',
          '---',
          '',
          '# Title',
          '',
        }, vim.api.nvim_buf_get_lines(0, 0, -1, false))
        helpers.eq({
          '---',
          'tags: []',
          '---',
          '',
          '# Title',
          '',
        }, vim.fn.readfile(path))
      end)
    end,
  },
  {
    name = 'TaxonNew command dispatches to the module',
    run = function()
      helpers.eq(2, vim.fn.exists(':TaxonNew'), 'TaxonNew command is not registered')

      local called = false
      local original_new_note = taxon.new_note

      taxon.new_note = function()
        called = true
      end

      local ok, err = pcall(vim.api.nvim_cmd, {
        cmd = 'TaxonNew',
      }, {})

      taxon.new_note = original_new_note

      if not ok then
        error(err)
      end

      helpers.truthy(called, 'TaxonNew did not call require("taxon").new_note()')
    end,
  },
  {
    name = 'TaxonSearch command dispatches to the module',
    run = function()
      helpers.eq(2, vim.fn.exists(':TaxonSearch'), 'TaxonSearch command is not registered')

      local called = false
      local original_search = taxon.search

      taxon.search = function()
        called = true
      end

      local ok, err = pcall(vim.api.nvim_cmd, {
        cmd = 'TaxonSearch',
      }, {})

      taxon.search = original_search

      if not ok then
        error(err)
      end

      helpers.truthy(called, 'TaxonSearch did not call require("taxon").search()')
    end,
  },
  {
    name = 'TaxonTagTree command dispatches to the module',
    run = function()
      helpers.eq(2, vim.fn.exists(':TaxonTagTree'), 'TaxonTagTree command is not registered')

      local called = false
      local original_show_tag_tree = taxon.show_tag_tree

      taxon.show_tag_tree = function()
        called = true
      end

      local ok, err = pcall(vim.api.nvim_cmd, {
        cmd = 'TaxonTagTree',
      }, {})

      taxon.show_tag_tree = original_show_tag_tree

      if not ok then
        error(err)
      end

      helpers.truthy(called, 'TaxonTagTree did not call require("taxon").show_tag_tree()')
    end,
  },
  {
    name = 'registered Taxon commands expose the documented descriptions',
    run = function()
      local commands = vim.api.nvim_get_commands({
        builtin = false,
      })

      helpers.eq('Create a new taxon note', commands.TaxonNew.definition)
      helpers.eq(nil, commands.TaxonOpen)
      helpers.eq('Search taxon notes and tags with Telescope', commands.TaxonSearch.definition)
      helpers.eq(nil, commands.TaxonTitleSearch)
      helpers.eq(nil, commands.TaxonTagSearch)
      helpers.eq('Show the taxon tag tree', commands.TaxonTagTree.definition)
    end,
  },
  {
    name = 'scan_notes rescans the configured notes directory on each call',
    run = function()
      helpers.with_temp_dir(function(temp_dir)
        local notes_dir = vim.fs.joinpath(temp_dir, 'notes')

        taxon.setup({
          notes_dir = notes_dir,
        })

        local initial = taxon.scan_notes()

        helpers.eq({}, initial.notes)
        helpers.eq({}, initial.tags)
        helpers.eq({}, initial.tag_tree)
        helpers.eq({}, initial.invalid_notes)

        local path = vim.fs.joinpath(notes_dir, '20260402-010203-note.md')
        vim.fn.writefile({
          '---',
          'tags: [animal/mammal/cat]',
          '---',
          '',
          '# Rescanned Note',
        }, path)

        local rescanned = taxon.scan_notes()

        helpers.eq({
          {
            explicit_tags = { 'animal/mammal/cat' },
            path = path,
            tags = {
              'animal',
              'animal/mammal',
              'animal/mammal/cat',
            },
            title = 'Rescanned Note',
          },
        }, rescanned.notes)
        helpers.eq({
          {
            children = {
              {
                children = {
                  {
                    children = {},
                    name = 'cat',
                    notes = {
                      {
                        explicit_tags = { 'animal/mammal/cat' },
                        path = path,
                        tags = {
                          'animal',
                          'animal/mammal',
                          'animal/mammal/cat',
                        },
                        title = 'Rescanned Note',
                      },
                    },
                    tag = 'animal/mammal/cat',
                  },
                },
                name = 'mammal',
                notes = {
                  {
                    explicit_tags = { 'animal/mammal/cat' },
                    path = path,
                    tags = {
                      'animal',
                      'animal/mammal',
                      'animal/mammal/cat',
                    },
                    title = 'Rescanned Note',
                  },
                },
                tag = 'animal/mammal',
              },
            },
            name = 'animal',
            notes = {
              {
                explicit_tags = { 'animal/mammal/cat' },
                path = path,
                tags = {
                  'animal',
                  'animal/mammal',
                  'animal/mammal/cat',
                },
                title = 'Rescanned Note',
              },
            },
            tag = 'animal',
          },
        }, rescanned.tag_tree)
      end)
    end,
  },
  {
    name = 'new_note prompts for a title and delegates note creation',
    run = function()
      local captured_prompt
      local captured_title
      local original_create_note = taxon.create_note
      local original_input = vim.ui.input

      vim.ui.input = function(opts, on_confirm)
        captured_prompt = opts.prompt
        on_confirm('Polished Note')
      end

      taxon.create_note = function(title)
        captured_title = title
        return '/tmp/polished-note.md'
      end

      local ok, err = pcall(taxon.new_note)
      local waited = vim.wait(1000, function()
        return captured_title ~= nil
      end)

      vim.ui.input = original_input
      taxon.create_note = original_create_note

      if not ok then
        error(err)
      end

      helpers.truthy(waited, 'new_note did not invoke create_note')
      helpers.eq('Taxon title: ', captured_prompt)
      helpers.eq('Polished Note', captured_title)
    end,
  },
  {
    name = 'new_note reports clear create errors',
    run = function()
      local notifications = {}
      local original_create_note = taxon.create_note
      local original_input = vim.ui.input
      local original_notify = vim.notify

      vim.ui.input = function(_, on_confirm)
        on_confirm('bad/name')
      end

      taxon.create_note = function()
        return nil, 'unsafe-title'
      end

      vim.notify = function(message, level)
        table.insert(notifications, {
          level = level,
          message = message,
        })
      end

      local ok, err = pcall(taxon.new_note)
      local waited = vim.wait(1000, function()
        return #notifications > 0
      end)

      vim.notify = original_notify
      vim.ui.input = original_input
      taxon.create_note = original_create_note

      if not ok then
        error(err)
      end

      helpers.truthy(waited, 'new_note did not report the create error')
      helpers.eq({
        {
          level = vim.log.levels.ERROR,
          message = 'Taxon: title contains filename-unsafe characters',
        },
      }, notifications)
    end,
  },
  {
    name = 'search scans notes, builds mixed picker entries, and opens the selected note',
    run = function()
      helpers.with_temp_dir(function(temp_dir)
        local notes_dir = vim.fs.joinpath(temp_dir, 'notes')
        local path = vim.fs.joinpath(notes_dir, '20260402-010203-cat.md')

        taxon.setup({
          notes_dir = notes_dir,
        })

        vim.fn.writefile({
          '---',
          'tags: [animal/mammal/cat]',
          '---',
          '',
          '# Cat Note',
        }, path)

        local captured_entries
        local opened_path
        local result = taxon.search({
          pick = function(entries, opts)
            captured_entries = entries
            opts.on_select(entries[1])
            return true
          end,
          open = function(path)
            opened_path = path
          end,
        })

        helpers.eq(true, result)
        helpers.eq(path, opened_path)
        helpers.eq({
          {
            display = '[Title] Cat Note [20260402-010203-cat.md]',
            kind = 'note',
            ordinal = 'title Cat Note 20260402-010203-cat.md ' .. path,
            path = path,
            title = 'Cat Note',
          },
          {
            display = '[Tag] animal',
            kind = 'tag',
            ordinal = 'tag animal animal',
            tag = 'animal',
          },
          {
            display = '[Tag] animal/mammal',
            kind = 'tag',
            ordinal = 'tag animal/mammal animal / mammal',
            tag = 'animal/mammal',
          },
          {
            display = '[Tag] animal/mammal/cat',
            kind = 'tag',
            ordinal = 'tag animal/mammal/cat animal / mammal / cat',
            tag = 'animal/mammal/cat',
          },
        }, captured_entries)
      end)
    end,
  },
  {
    name = 'search reports a clear error when Telescope is unavailable',
    run = function()
      local notifications = {}
      local original_notify = vim.notify

      vim.notify = function(message, level)
        table.insert(notifications, {
          level = level,
          message = message,
        })
      end

      local ok, err = taxon.search({
        pick = function()
          return nil, 'missing-telescope'
        end,
      })

      vim.notify = original_notify

      helpers.eq(nil, ok)
      helpers.eq('missing-telescope', err)
      helpers.eq({
        {
          level = vim.log.levels.ERROR,
          message = 'Taxon: search requires Telescope (nvim-telescope/telescope.nvim)',
        },
      }, notifications)
    end,
  },
  {
    name = 'search opens notes that match an inherited parent tag after selecting a tag entry',
    run = function()
      helpers.with_temp_dir(function(temp_dir)
        local notes_dir = vim.fs.joinpath(temp_dir, 'notes')
        local path = vim.fs.joinpath(notes_dir, '20260402-010203-cat.md')

        taxon.setup({
          notes_dir = notes_dir,
        })

        vim.fn.writefile({
          '---',
          'tags: [animal/mammal/cat]',
          '---',
          '',
          '# Cat Note',
        }, path)

        local captured_entries
        local captured_note_entries
        local result = taxon.search({
          pick = function(entries, opts)
            captured_entries = entries
            opts.on_select(entries[2])
            return true
          end,
          pick_notes = function(entries, _)
            captured_note_entries = entries
            return true
          end,
        })

        helpers.eq(true, result)
        helpers.eq({
          {
            display = '[Title] Cat Note [20260402-010203-cat.md]',
            kind = 'note',
            ordinal = 'title Cat Note 20260402-010203-cat.md ' .. path,
            path = path,
            title = 'Cat Note',
          },
          {
            display = '[Tag] animal',
            kind = 'tag',
            ordinal = 'tag animal animal',
            tag = 'animal',
          },
          {
            display = '[Tag] animal/mammal',
            kind = 'tag',
            ordinal = 'tag animal/mammal animal / mammal',
            tag = 'animal/mammal',
          },
          {
            display = '[Tag] animal/mammal/cat',
            kind = 'tag',
            ordinal = 'tag animal/mammal/cat animal / mammal / cat',
            tag = 'animal/mammal/cat',
          },
        }, captured_entries)
        helpers.eq({
          {
            display = 'Cat Note [20260402-010203-cat.md]',
            kind = 'note',
            ordinal = 'Cat Note 20260402-010203-cat.md ' .. path,
            path = path,
            title = 'Cat Note',
          },
        }, captured_note_entries)
      end)
    end,
  },
  {
    name = 'search propagates Telescope errors from the tag results picker',
    run = function()
      helpers.with_temp_dir(function(temp_dir)
        local notes_dir = vim.fs.joinpath(temp_dir, 'notes')
        local path = vim.fs.joinpath(notes_dir, '20260402-010203-cat.md')
        local notifications = {}
        local original_notify = vim.notify

        taxon.setup({
          notes_dir = notes_dir,
        })

        vim.fn.writefile({
          '---',
          'tags: [animal/mammal/cat]',
          '---',
          '',
          '# Cat Note',
        }, path)

        vim.notify = function(message, level)
          table.insert(notifications, {
            level = level,
            message = message,
          })
        end

        local ok = taxon.search({
          pick = function(_, opts)
            opts.on_select({
              kind = 'tag',
              tag = 'animal',
            })
            return true
          end,
          pick_notes = function()
            return nil, 'missing-telescope'
          end,
        })

        vim.notify = original_notify

        helpers.eq(true, ok)
        helpers.eq({
          {
            level = vim.log.levels.ERROR,
            message = 'Taxon: search requires Telescope (nvim-telescope/telescope.nvim)',
          },
        }, notifications)
      end)
    end,
  },
  {
    name = 'search uses the selected tag in the note picker prompt',
    run = function()
      helpers.with_temp_dir(function(temp_dir)
        local notes_dir = vim.fs.joinpath(temp_dir, 'notes')
        local path = vim.fs.joinpath(notes_dir, '20260402-010203-cat.md')

        taxon.setup({
          notes_dir = notes_dir,
        })

        vim.fn.writefile({
          '---',
          'tags: [animal/mammal/cat]',
          '---',
          '',
          '# Cat Note',
        }, path)

        local captured_prompt_title
        local result = taxon.search({
          pick = function(entries, opts)
            opts.on_select(entries[2])
            return true
          end,
          pick_notes = function(_, opts)
            captured_prompt_title = opts.prompt_title
            return true
          end,
        })

        helpers.eq(true, result)
        helpers.eq('Taxon Search: animal', captured_prompt_title)
      end)
    end,
  },
  {
    name = 'show_tag_tree scans notes and opens the view with the deterministic tree model',
    run = function()
      helpers.with_temp_dir(function(temp_dir)
        local notes_dir = vim.fs.joinpath(temp_dir, 'notes')
        local path = vim.fs.joinpath(notes_dir, '20260402-010203-cat.md')

        taxon.setup({
          notes_dir = notes_dir,
        })

        vim.fn.writefile({
          '---',
          'tags: [animal/mammal/cat]',
          '---',
          '',
          '# Cat Note',
        }, path)

        local captured_tree
        local captured_open
        local result = taxon.show_tag_tree({
          show = function(tree, opts)
            captured_tree = tree
            captured_open = opts.open
            return true
          end,
        })

        helpers.eq(true, result)
        helpers.eq(nil, captured_open)
        helpers.eq({
          {
            children = {
              {
                children = {
                  {
                    children = {},
                    name = 'cat',
                    notes = {
                      {
                        explicit_tags = { 'animal/mammal/cat' },
                        path = path,
                        tags = {
                          'animal',
                          'animal/mammal',
                          'animal/mammal/cat',
                        },
                        title = 'Cat Note',
                      },
                    },
                    tag = 'animal/mammal/cat',
                  },
                },
                name = 'mammal',
                notes = {
                  {
                    explicit_tags = { 'animal/mammal/cat' },
                    path = path,
                    tags = {
                      'animal',
                      'animal/mammal',
                      'animal/mammal/cat',
                    },
                    title = 'Cat Note',
                  },
                },
                tag = 'animal/mammal',
              },
            },
            name = 'animal',
            notes = {
              {
                explicit_tags = { 'animal/mammal/cat' },
                path = path,
                tags = {
                  'animal',
                  'animal/mammal',
                  'animal/mammal/cat',
                },
                title = 'Cat Note',
              },
            },
            tag = 'animal',
          },
        }, captured_tree)
      end)
    end,
  },
}
