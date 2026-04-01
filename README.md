# taxon.nvim

`taxon.nvim` is a Neovim plugin for managing notes through hierarchical tags.
The name comes from taxonomy: notes are organized by classification rather than
only by folders.

## Goals

- Model note relationships through tag hierarchies
- Keep note authoring inside Neovim
- Provide fast navigation and filtering across related notes

## Status

This repository currently contains the initial plugin scaffold.

## Planned features

- Tag declaration and parent/child relationships
- Note creation with structured frontmatter
- Search and browse commands based on taxonomy
- Tree and backlink style navigation

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

Then run:

```vim
:TaxonOpen
```

## Development

- Plugin entrypoint: `plugin/taxon.lua`
- Lua module: `lua/taxon/init.lua`
- Help file: `doc/taxon.txt`
