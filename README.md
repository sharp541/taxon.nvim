# taxon.nvim

`taxon.nvim` is a Neovim plugin for managing notes through hierarchical tags.
The name comes from taxonomy: notes are organized by classification rather than
only by folders.

## Status

The repository now includes note parsing, tag normalization, and timestamped
new-note creation. The remaining MVP definition lives in
[`docs/spec.md`](docs/spec.md).

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
```

`:TaxonNew` prompts for a title, creates
`YYYYMMDD-HHMMSS-タイトル.md` in `notes_dir`, writes the canonical note template,
and opens the new buffer. Titles are preserved in the filename, but path-unsafe
characters such as `/` and `\\` are rejected explicitly.

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
