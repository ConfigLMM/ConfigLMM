# ConfigLMM

ConfigLMM is a Ruby CLI and plugin framework for high-level infrastructure/app configuration.

It aims to let you describe *what* you want, then use plugins to build/deploy/operate those resources.

## Current status

This project is in early development.  
The long-term vision is larger than what is fully implemented today.

To see what exists now, use:

- `configlmm types` (available plugin types)
- `Examples/Implemented.mm.yaml` (examples of currently modeled/implemented types)

## Quick start

Install:

```sh
gem install ConfigLMM
```

Then:

```sh
configlmm help
```

Core command groups currently available in CLI include:
`list`, `validate`, `refresh`, `diff`, `build`, `deploy`, `test`, `backup`, `update`, `cleanup`, `types`, `version`.

## Documentation map

- [Why ConfigLMM exists and where it is heading](docs/vision.md)
- [What is implemented right now](docs/current-functionality.md)
- [History and release notes](docs/history.md)
- [Changelog](CHANGELOG.md)

## Contributing

Issues and pull requests are welcome: https://github.com/ConfigLMM/ConfigLMM
