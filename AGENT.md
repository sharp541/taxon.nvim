# AGENT.md

Use this file as a router only. Prefer code and tests over prose.

## Routes

- Runtime entrypoint: `plugin/taxon.lua`
- Core implementation: `lua/taxon/`
- User-facing changes must update: `README.md`, `doc/taxon.txt`
- Architecture decisions belong in: `docs/adr/`

## Commands

- Format: `stylua lua plugin tests`
- Install hooks: `./scripts/install-hooks`
- Test: `./scripts/test`
- Build: no command is defined yet
- Deploy: no command is defined yet

## Do Not

- Do not land unformatted Lua. Ref: `stylua.toml`
- Do not make architecture-level changes without an ADR. Ref: `docs/adr/`
