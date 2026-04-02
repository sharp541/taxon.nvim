# taxon.nvim

`taxon.nvim` is a Neovim plugin for managing notes through hierarchical tags.
The name comes from taxonomy: notes are organized by classification rather than
only by folders.

## Status

The MVP command surface is implemented: create timestamped notes, search note
titles and tags from a unified Telescope picker, and browse tags in a dedicated
tree view. Taxon rescans `notes_dir` on each search or tree command and does
not write a cache or index file in the MVP.

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
    "nvim-telescope/telescope.nvim", -- required for :TaxonSearch
  },
  opts = {},
}
```

If you do not install Telescope, `:TaxonSearch` reports a clear error and the
rest of the MVP still works.

## Local Development

To try this repository in your local Neovim without editing your main config:

```sh
chmod +x ./scripts/dev
./scripts/dev
```

This starts Neovim with [`scripts/dev_init.lua`](scripts/dev_init.lua), which:

- loads your regular `~/.config/nvim/init.lua` if it exists,
- prepends this repository to `runtimepath`,
- registers Taxon commands from `plugin/taxon.lua`,
- configures `notes_dir` to `./.tmp/taxon-notes` by default.

You can override the note directory for a session:

```sh
TAXON_DEV_NOTES_DIR=/tmp/taxon-notes ./scripts/dev
```

## Usage

```lua
require("taxon").setup({
  notes_dir = vim.fn.stdpath("data") .. "/taxon-notes",
})
```

If you do not call `setup()`, Taxon defaults `notes_dir` to
`vim.fn.stdpath("data") .. "/taxon-notes"`.

Commands:

- `:TaxonNew` prompts for a title, creates
  `YYYYMMDD-HHMMSS-タイトル.md` in `notes_dir`, writes the canonical note
  template, and opens the new buffer. Titles are preserved in the filename, but
  path-unsafe characters such as `/` and `\\` are rejected explicitly.
- `:TaxonSearch` rescans `notes_dir`, shows one Telescope picker with note
  titles and normalized explicit and inherited tags, opens the selected note
  directly for title matches, and opens a second picker with matching notes for
  tag matches.
- `:TaxonTagTree` rescans `notes_dir` and opens a dedicated vertical tree
  buffer on the left that treats tags like folders and notes like files.
  Press `<CR>` or `l` to expand a tag or open a note, `h` to collapse or move
  to the parent tag, and `q` to close the tree.

The search command requires Telescope. The new-note, scan, and tag-tree
commands do not.

Lua API:

```lua
require("taxon").setup({
  notes_dir = vim.fn.stdpath("data") .. "/taxon-notes",
})
require("taxon").create_note("Title")
require("taxon").new_note()
local model = require("taxon").scan_notes()
require("taxon").search()
require("taxon").show_tag_tree()
```

`setup()` stores the plugin configuration and ensures that `notes_dir` exists.
`create_note(title)` is the non-interactive note creation helper behind
`:TaxonNew`, and `new_note()` prompts for the title interactively.

`scan_notes()` rescans `notes_dir` on each call and returns a query model with
`notes`, `tags`, `tag_tree`, `notes_by_title`, `notes_by_tag`, and
`invalid_notes`. `tag_tree` is a deterministic list of root nodes; each node
contains `name`, `tag`, `notes`, and `children`. Per-note `tags` include both
explicit frontmatter tags and inherited parent tags. Invalid Markdown notes are
skipped deterministically and reported through `invalid_notes`.

`search()` uses the same scan model to populate a mixed Telescope picker from
note titles and inherited tags. Selecting a title opens the note path
immediately. Selecting a tag opens a second picker with the matching notes.

`show_tag_tree()` uses the same scan model to render a dedicated tag tree view.
Tags behave like expandable folders, and notes are shown as file entries under
their explicit tags only; inherited parent tags stay visible as folders but do
not list inherited notes directly.

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
