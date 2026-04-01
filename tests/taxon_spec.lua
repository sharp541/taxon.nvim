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
    name = 'TaxonOpen command dispatches to the module',
    run = function()
      helpers.eq(2, vim.fn.exists(':TaxonOpen'), 'TaxonOpen command is not registered')

      local called = false
      local original_open = taxon.open

      taxon.open = function()
        called = true
      end

      local ok, err = pcall(vim.api.nvim_cmd, {
        cmd = 'TaxonOpen',
      }, {})

      taxon.open = original_open

      if not ok then
        error(err)
      end

      helpers.truthy(called, 'TaxonOpen did not call require("taxon").open()')
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
    name = 'TaxonTitleSearch command dispatches to the module',
    run = function()
      helpers.eq(
        2,
        vim.fn.exists(':TaxonTitleSearch'),
        'TaxonTitleSearch command is not registered'
      )

      local called = false
      local original_search_titles = taxon.search_titles

      taxon.search_titles = function()
        called = true
      end

      local ok, err = pcall(vim.api.nvim_cmd, {
        cmd = 'TaxonTitleSearch',
      }, {})

      taxon.search_titles = original_search_titles

      if not ok then
        error(err)
      end

      helpers.truthy(called, 'TaxonTitleSearch did not call require("taxon").search_titles()')
    end,
  },
  {
    name = 'TaxonTagSearch command dispatches to the module',
    run = function()
      helpers.eq(2, vim.fn.exists(':TaxonTagSearch'), 'TaxonTagSearch command is not registered')

      local called = false
      local original_search_tags = taxon.search_tags

      taxon.search_tags = function()
        called = true
      end

      local ok, err = pcall(vim.api.nvim_cmd, {
        cmd = 'TaxonTagSearch',
      }, {})

      taxon.search_tags = original_search_tags

      if not ok then
        error(err)
      end

      helpers.truthy(called, 'TaxonTagSearch did not call require("taxon").search_tags()')
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
    name = 'search_titles scans notes, builds picker entries, and starts the picker',
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
        local result = taxon.search_titles({
          pick = function(entries, _)
            captured_entries = entries
            return true
          end,
        })

        helpers.eq(true, result)
        helpers.eq({
          {
            display = 'Cat Note [20260402-010203-cat.md]',
            ordinal = 'Cat Note 20260402-010203-cat.md ' .. path,
            path = path,
            title = 'Cat Note',
          },
        }, captured_entries)
      end)
    end,
  },
  {
    name = 'search_titles reports a clear error when Telescope is unavailable',
    run = function()
      local notifications = {}
      local original_notify = vim.notify

      vim.notify = function(message, level)
        table.insert(notifications, {
          level = level,
          message = message,
        })
      end

      local ok, err = taxon.search_titles({
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
          message = 'Taxon: title search requires Telescope (nvim-telescope/telescope.nvim)',
        },
      }, notifications)
    end,
  },
  {
    name = 'search_tags scans tags and opens notes that match an inherited parent tag',
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

        local captured_tag_entries
        local captured_note_entries
        local result = taxon.search_tags({
          pick_tag = function(entries, opts)
            captured_tag_entries = entries
            opts.on_select({
              tag = 'animal',
            })
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
            display = 'animal',
            ordinal = 'animal animal',
            tag = 'animal',
          },
          {
            display = 'animal/mammal',
            ordinal = 'animal/mammal animal / mammal',
            tag = 'animal/mammal',
          },
          {
            display = 'animal/mammal/cat',
            ordinal = 'animal/mammal/cat animal / mammal / cat',
            tag = 'animal/mammal/cat',
          },
        }, captured_tag_entries)
        helpers.eq({
          {
            display = 'Cat Note [20260402-010203-cat.md]',
            ordinal = 'Cat Note 20260402-010203-cat.md ' .. path,
            path = path,
            title = 'Cat Note',
          },
        }, captured_note_entries)
      end)
    end,
  },
  {
    name = 'search_tags reports a clear error when Telescope is unavailable',
    run = function()
      local notifications = {}
      local original_notify = vim.notify

      vim.notify = function(message, level)
        table.insert(notifications, {
          level = level,
          message = message,
        })
      end

      local ok, err = taxon.search_tags({
        pick_tag = function()
          return nil, 'missing-telescope'
        end,
      })

      vim.notify = original_notify

      helpers.eq(nil, ok)
      helpers.eq('missing-telescope', err)
      helpers.eq({
        {
          level = vim.log.levels.ERROR,
          message = 'Taxon: tag search requires Telescope (nvim-telescope/telescope.nvim)',
        },
      }, notifications)
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
        local result = taxon.show_tag_tree({
          show = function(tree, _)
            captured_tree = tree
            return true
          end,
        })

        helpers.eq(true, result)
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
