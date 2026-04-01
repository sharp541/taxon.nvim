# MVP Task Board

This file is the source of truth for MVP execution. It is optimized for one
focused coding session per task.

## Ground Rules

- Use only these status values: `todo`, `doing`, `blocked`, `done`
- `1 session = 1 task`
- Move exactly one task to `doing` at the start of a session.
- End each session by marking the task `done` or `blocked`.
- If a task grows beyond one session, split the remaining scope into a new task
  instead of carrying unfinished hidden work.
- Every task should leave `./scripts/test` passing.
- User-visible behavior changes must update `README.md` and `doc/taxon.txt` in
  the same session.
- If a task is blocked, record the blocker in the session log before stopping.

## Out Of Scope

These stay out of the MVP unless `docs/spec.md` changes:

- Automatic tag rename detection from manual edits
- Backlinks or graph features
- Full-text body search
- Preview pane beside the tag tree
- Persistent cache or index files

## Status Board

Recommended next task: `TAXON-MVP-08`

| ID | Status | Depends On | Session Goal |
| --- | --- | --- | --- |
| TAXON-MVP-00 | done | - | Baseline scaffold: `setup()`, notes directory creation, `TaxonOpen` |
| TAXON-MVP-01 | done | TAXON-MVP-00 | Implement note format primitives: frontmatter `tags`, first-H1 title extraction, canonical note template |
| TAXON-MVP-02 | done | TAXON-MVP-01 | Implement tag normalization and validation rules from the spec |
| TAXON-MVP-03 | done | TAXON-MVP-01, TAXON-MVP-02 | Implement new-note creation flow with timestamped filenames and a user command |
| TAXON-MVP-04 | done | TAXON-MVP-01, TAXON-MVP-02 | Implement on-demand note scanning and derived parent-tag expansion |
| TAXON-MVP-05 | done | TAXON-MVP-04 | Implement Telescope title search and note opening |
| TAXON-MVP-06 | done | TAXON-MVP-04 | Implement Telescope tag search using inherited tags |
| TAXON-MVP-07 | done | TAXON-MVP-04 | Build the in-memory hierarchical tag tree model |
| TAXON-MVP-08 | todo | TAXON-MVP-07 | Implement the tag tree view and opening notes from that view |
| TAXON-MVP-09 | todo | TAXON-MVP-03, TAXON-MVP-05, TAXON-MVP-06, TAXON-MVP-08 | Final MVP polish: command docs, help text, tests, acceptance pass |

## Task Details

### TAXON-MVP-00 Baseline Scaffold

Status: `done`

Already present in the repository:

- `setup()` persists config and creates `notes_dir`
- `TaxonOpen` is registered
- baseline tests cover the current scaffold

### TAXON-MVP-01 Note Format Primitives

Status: `done`

Goal: implement the narrow note parser/renderer required by the MVP format.

Scope:

- Parse Markdown notes with YAML frontmatter
- Support only the frontmatter shape required by the spec: `tags`
- Extract the title from the first Markdown H1 in the body
- Render the canonical new-note template

Done when:

- A core module can read a note file into structured note data
- A core module can render a new note with:

```markdown
---
tags: []
---

# Title
```

- Tests cover valid notes and invalid note shapes that the plugin must reject or
  skip deterministically

### TAXON-MVP-02 Tag Normalization And Validation

Status: `done`

Goal: encode the tag rules from `docs/spec.md` into a single reusable utility.

Scope:

- Lowercase persisted tags
- Compare tags case-insensitively
- Trim whitespace around each segment
- Allow spaces inside a segment
- Allow Japanese text
- Reject empty tags, leading `/`, trailing `/`, `//`, control characters, and
  newlines

Done when:

- One normalization function is used everywhere tags enter the system
- Tests cover the examples from the spec and representative invalid inputs
- Output order is deterministic so later UI work stays testable

### TAXON-MVP-03 New Note Creation Flow

Status: `done`

Goal: let the user create a note from a command with the required filename and
body shape.

Scope:

- Prompt for a title
- Generate filenames as `YYYYMMDD-HHMMSS-タイトル.md`
- Write the canonical note template with empty `tags`
- Open the created note in Neovim

Done when:

- A user command creates a note in `notes_dir`
- Filename generation is testable without relying on wall-clock time
- Invalid titles that cannot produce a safe note path are handled explicitly
- Tests cover filename format and file contents

### TAXON-MVP-04 Note Scanning And Query Model

Status: `done`

Goal: build the in-memory note collection used by every search and tree feature.

Scope:

- Scan note files on each query
- Parse title and explicit tags from each note
- Derive parent tags in memory at scan time
- Expose a query model for title and tag lookups

Done when:

- No cache or index file is introduced
- A scan returns enough structured data for title search, tag search, and tree
  view features
- Tests cover multiple explicit tags and inherited parent tags
- Invalid note handling is deterministic and documented

### TAXON-MVP-05 Telescope Title Search

Status: `done`

Goal: search notes by title through Telescope and open the selected note.

Scope:

- Add a user command or public entrypoint for title search
- Feed scanned note titles into Telescope
- Open the selected note from the picker

Done when:

- A user can search notes by title from Telescope
- Selection opens the correct note
- Missing Telescope produces a clear user-facing error instead of a raw stack
  trace
- Tests cover the adapter seam around the picker data and open action

### TAXON-MVP-06 Telescope Tag Search

Status: `done`

Goal: search notes by tag through Telescope, including inherited parent tags.

Scope:

- Add a user command or public entrypoint for tag search
- Use normalized derived tags from the scan model
- Return matching notes for the chosen tag and open the selected note

Done when:

- A user can find notes by typing either an explicit tag or an inherited parent
  tag
- Selection opens the correct note
- Missing Telescope produces a clear user-facing error instead of a raw stack
  trace
- Tests cover inherited-tag matching

### TAXON-MVP-07 Tag Tree Model

Status: `done`

Goal: build the hierarchical tag structure that backs the tree view.

Scope:

- Build slash-delimited parent/child tag nodes
- Track which notes belong to each tag node
- Keep the structure deterministic for stable rendering and tests

Done when:

- The model can represent `animal`, `animal/mammal`, and
  `animal/mammal/cat` as a hierarchy
- Each node exposes the matching notes needed by the tree UI
- Tests cover hierarchy shape and note membership

### TAXON-MVP-08 Tag Tree View

Status: `todo`

Goal: expose the tag tree in Neovim and let the user open matching notes from
the view.

Scope:

- Render the tag hierarchy in a dedicated buffer or window
- Support cursor-based selection on tag nodes
- Open matching notes from the selected tag

Done when:

- A user can open the tag tree from a command
- The tree shows tags as a single hierarchy
- The user can open notes matching the selected tag from the tree view
- Tests cover rendering shape or interaction seams that can run headless

### TAXON-MVP-09 Final MVP Polish

Status: `todo`

Goal: finish the MVP as a coherent, documented plugin rather than a loose set of
features.

Scope:

- Close gaps in command naming and help text
- Review README examples and installation notes
- Fill missing tests discovered during implementation
- Run a final pass against `docs/spec.md`

Done when:

- `README.md` and `doc/taxon.txt` describe the MVP command surface
- `./scripts/test` passes
- The implemented feature set matches the MVP scope and does not pull in
  deferred items
- The task board is updated with final status and any follow-up tasks

## Session Log

Append one line at the end of each working session.

| Date | Task | Result | Commit | Handoff Note |
| --- | --- | --- | --- | --- |
| 2026-04-01 | TAXON-MVP-00 | done | working tree baseline | `setup()`, notes directory creation, and `TaxonOpen` already exist with tests |
| 2026-04-01 | TAXON-MVP-01 | done | working tree | Added `taxon.note` parsing/rendering primitives with deterministic rejection paths and test coverage |
| 2026-04-02 | TAXON-MVP-02 | done | working tree | Added shared tag normalization with lowercase canonicalization, validation, deterministic ordering, and note-parser integration |
| 2026-04-02 | TAXON-MVP-03 | done | working tree | Added `:TaxonNew`, deterministic timestamped filename creation, safe-title validation, docs, and tests for file creation flow |
| 2026-04-02 | TAXON-MVP-04 | done | working tree | Added on-demand scan/query modeling with inherited parent tags, deterministic invalid-note reporting, docs, and tests |
| 2026-04-02 | TAXON-MVP-05 | done | working tree | Added `:TaxonTitleSearch` and `search_titles()` with a testable Telescope adapter, clear missing-Telescope errors, docs, and note-opening tests |
| 2026-04-02 | TAXON-MVP-06 | done | working tree | Added `:TaxonTagSearch` and `search_tags()` using inherited tags, clear missing-Telescope errors, docs, and tests |
| 2026-04-02 | TAXON-MVP-07 | done | working tree | Added deterministic `tag_tree` nodes with per-tag note membership to the scan model, plus docs and tests for hierarchy shape |
