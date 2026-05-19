# Current functionality

This page summarizes functionality that is present in the current codebase.

## CLI commands (implemented)

The CLI (`bin/configlmm` via `ConfigLMM::CLI`) currently exposes these command families:

- `list`
- `validate`
- `refresh`
- `diff`
- `build`
- `deploy`
- `test`
- `backup`
- `update`
- `cleanup`
- `types`
- `version`

Run `configlmm help` for command options.

## Plugin architecture (implemented)

ConfigLMM loads plugin files from `Plugins/**/**.lmm.rb`.

Type capabilities are discovered from plugin action methods matching:

`action<Type>(Validate|Build|Refresh|Diff|Deploy|Backup|Update)`

This is what powers `configlmm types`.

## Implemented type coverage (repository)

Implemented and in-repo type coverage includes multiple categories, such as:

- **Apps** (for example Nginx, Gollum, Nextcloud, Matrix, PostgreSQL-related apps, and others)
- **Platforms** (for example Porkbun, GoDaddy, GitHub, Proxmox, libvirt)
- **OS** (Linux and related helpers)
- **Services** (for example DNS providers)

See:

- `Examples/Implemented.mm.yaml` for concrete modeled examples
- `Plugins/` for plugin source files

## Scope note

Some ideas described historically in project messaging are aspirational and not fully implemented yet.

Use this page, `configlmm types`, and `Examples/Implemented.mm.yaml` as the source of truth for current capabilities.
