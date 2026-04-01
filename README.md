# taxon.nvim

`taxon.nvim` is a Neovim plugin for managing notes through hierarchical tags.
The name comes from taxonomy: notes are organized by classification rather than
only by folders.

## Status

The MVP command surface is implemented: open the notes directory, create
timestamped notes, search titles and tags with Telescope, and browse tags in a
dedicated tree view. Taxon rescans `notes_dir` on each search or tree command
and does not write a cache or index file in the MVP.

## Docs

- Specification: [`docs/spec.md`](docs/spec.md)
- MVP task board: [`docs/mvp-tasks.md`](docs/mvp-tasks.md)
- Architecture decisions: [`docs/adr/`](docs/adr/)
- Neovim help: [`doc/taxon.txt`](doc/taxon.txt)

## Installation

Using `lazy.nvim`:

```lua
{
  "yourname/taxon.nvim",
  dependencies = {
    "nvim-telescope/telescope.nvim", -- required for :TaxonTitleSearch and :TaxonTagSearch
  },
  opts = {},
}
```

If you do not install Telescope, `:TaxonTitleSearch` and `:TaxonTagSearch`
report a clear error and the rest of the MVP still works.

## Usage

```lua
require("taxon").setup({
  notes_dir = vim.fn.stdpath("data") .. "/taxon-notes",
})
```

If you do not call `setup()`, Taxon defaults `notes_dir` to
`vim.fn.stdpath("data") .. "/taxon-notes"`.

Commands:

- `:TaxonOpen` creates `notes_dir` if needed and opens it.
- `:TaxonNew` prompts for a title, creates
  `YYYYMMDD-HHMMSS-タイトル.md` in `notes_dir`, writes the canonical note
  template, and opens the new buffer. Titles are preserved in the filename, but
  path-unsafe characters such as `/` and `\\` are rejected explicitly.
- `:TaxonTitleSearch` rescans `notes_dir`, feeds note titles into Telescope,
  and opens the selected note.
- `:TaxonTagSearch` rescans `notes_dir`, lets you pick from normalized explicit
  and inherited tags in Telescope, then shows the notes that match the selected
  tag and opens the chosen note.
- `:TaxonTagTree` rescans `notes_dir` and opens a dedicated vertical tree
  buffer that shows the hierarchical tag model with per-tag note counts. Press
  `<CR>` on the current tag to open one of its matching notes, or `q` to close
  the tree.

The search commands require Telescope. The open, new-note, scan, and tag-tree
commands do not.

Lua API:

```lua
require("taxon").setup({
  notes_dir = vim.fn.stdpath("data") .. "/taxon-notes",
})
require("taxon").open()
require("taxon").create_note("Title")
require("taxon").new_note()
local model = require("taxon").scan_notes()
require("taxon").search_titles()
require("taxon").search_tags()
require("taxon").show_tag_tree()
```

`setup()` stores the plugin configuration and ensures that `notes_dir` exists.
`open()` backs `:TaxonOpen`. `create_note(title)` is the non-interactive note
creation helper behind `:TaxonNew`, and `new_note()` prompts for the title
interactively.

`scan_notes()` rescans `notes_dir` on each call and returns a query model with
`notes`, `tags`, `tag_tree`, `notes_by_title`, `notes_by_tag`, and
`invalid_notes`. `tag_tree` is a deterministic list of root nodes; each node
contains `name`, `tag`, `notes`, and `children`. Per-note `tags` include both
explicit frontmatter tags and inherited parent tags. Invalid Markdown notes are
skipped deterministically and reported through `invalid_notes`.

`search_titles()` uses the same scan model to populate a Telescope picker from
note titles and opens the selected note path. `search_tags()` uses the scan
model's inherited tag index to populate a Telescope tag picker, then opens a
second picker with the matching notes for the selected tag.

`show_tag_tree()` uses the same scan model to render a dedicated tag tree view.
Selecting a tag opens the only matching note directly, or prompts you to choose
when the tag contains multiple notes.

## Note Format

Notes use YAML frontmatter with a `tags` list and the first Markdown H1 as the
title. Tags are normalized to lowercase slash paths when Taxon reads them:
whitespace around each segment is trimmed, spaces inside a segment and Japanese
text are allowed, and empty segments, leading or trailing `/`, `//`, control
characters, and newlines are rejected.

New notes use timestamp-prefixed filenames in the form
`YYYYMMDD-HHMMSS-タイトル.md`.

## Development

- Format: `stylua lua plugin tests`
- Install hooks: `./scripts/install-hooks`
- Test: `./scripts/test`
- Runtime entrypoint: `plugin/taxon.lua`
- Core module: `lua/taxon/init.lua`
