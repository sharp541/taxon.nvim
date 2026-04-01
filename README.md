# taxon.nvim

`taxon.nvim` is a Neovim plugin for managing notes through hierarchical tags.
The name comes from taxonomy: notes are organized by classification rather than
only by folders.

## Status

The repository now includes note parsing, tag normalization, timestamped
new-note creation, on-demand note scanning with inherited parent-tag expansion,
a hierarchical in-memory tag-tree model, and Telescope search by title and tag.
The remaining MVP definition lives in [`docs/spec.md`](docs/spec.md).

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
  opts = {},
}
```

## Usage

```lua
require("taxon").setup({
  notes_dir = vim.fn.stdpath("data") .. "/taxon-notes",
})
```

Current commands:

```vim
:TaxonOpen
:TaxonNew
:TaxonTitleSearch
:TaxonTagSearch
```

`:TaxonNew` prompts for a title, creates
`YYYYMMDD-HHMMSS-タイトル.md` in `notes_dir`, writes the canonical note template,
and opens the new buffer. Titles are preserved in the filename, but path-unsafe
characters such as `/` and `\\` are rejected explicitly.

`:TaxonTitleSearch` rescans `notes_dir`, feeds note titles into Telescope, and
opens the selected note. If Telescope is not installed, Taxon reports a clear
error instead of raising a raw Lua stack trace.

`:TaxonTagSearch` rescans `notes_dir`, lets you pick from normalized explicit
and inherited tags in Telescope, then shows the notes that match the selected
tag and opens the chosen note. If Telescope is not installed, Taxon reports a
clear error instead of raising a raw Lua stack trace.

Lua API:

```lua
local model = require("taxon").scan_notes()
require("taxon").search_titles()
require("taxon").search_tags()
```

`scan_notes()` rescans `notes_dir` on each call and returns a query model with
`notes`, `tags`, `tag_tree`, `notes_by_title`, `notes_by_tag`, and
`invalid_notes`. `tag_tree` is a deterministic list of root nodes; each node
contains `name`, `tag`, `notes`, and `children`. Per-note `tags` include both
explicit frontmatter tags and inherited parent tags. Invalid Markdown notes are
skipped deterministically and reported through `invalid_notes`.

`search_titles()` uses the same scan model to populate a Telescope picker from
note titles and opens the selected note path.

`search_tags()` uses the scan model's inherited tag index to populate a
Telescope tag picker, then opens a second picker with the matching notes for
the selected tag.

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
