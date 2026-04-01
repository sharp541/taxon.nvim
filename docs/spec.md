# taxon.nvim Specification

## MVP Scope

`taxon.nvim` is a Neovim note plugin built around hierarchical tags.

- One file equals one note
- Notes are Markdown files stored in a single directory
- Metadata is stored in YAML frontmatter
- Only `tags` are stored in frontmatter
- The note title is the first Markdown heading in the body

## Note Format

New notes are created with this shape:

```markdown
---
tags: []
---

# Title
```

- Users edit `tags` manually in frontmatter
- The title is provided at creation time and written as `# Title`
- The plugin reads the title from the first H1 heading

## File Naming

New notes use this filename format:

```text
YYYYMMDD-HHMMSS-タイトル.md
```

- The timestamp prefix is generated automatically
- The title segment is provided by the user
- Japanese filenames are allowed

## Tag Model

Tags use slash-delimited paths such as `animal/mammal/cat`.

- A note may have multiple explicit tags
- Parent tags are inherited at query time
- Only explicit tags are stored in frontmatter
- Parent tags are derived in memory during each scan
- Tags are free-form user input after normalization

Example:

- Stored tag: `animal/mammal/cat`
- Derived tags: `animal`, `animal/mammal`

## Tag Normalization

Tags are normalized automatically before use or save.

- Compare tags case-insensitively
- Persist tags in lowercase
- Trim whitespace around each segment
- Allow spaces inside a segment
- Allow Japanese text
- Reject empty tags
- Reject leading `/`
- Reject trailing `/`
- Reject `//`
- Reject control characters and newlines

Examples:

- `Foo / Bar` -> `foo/bar`
- `Project/Client A` -> `project/client a`

## Indexing and Queries

- The plugin scans note files on each query
- No cache or index file is used in the MVP
- Search results include inherited parent tags
- Title search is based on the first H1 heading

## MVP UI

- Create a new note from a command
- Search by title with Telescope
- Search by tag with Telescope
- Show tags in a single tree view
- Open matching notes from the tree view

## Deferred

- Automatic tag rename detection from manual edits
- Backlinks or graph features
- Full-text body search
- Preview pane beside the tag tree
- Persistent cache or index files
