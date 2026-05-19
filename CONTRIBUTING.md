# Contributing to ConfigLMM

Bug reports and pull requests are welcome on GitHub at https://github.com/ConfigLMM/ConfigLMM.
Pretty Please! :)

## Development Setup

After checking out the repo, run `bin/setup` to install dependencies. Then run `rake spec` to run the
tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`.

## Implementation

*ConfigLMM* consists of 3 main parts:

1. **High-level configuration file format** — a superset/abstraction that describes your infrastructure intentions
2. **Core Framework** — holds *ConfigLMM* together and provides shared utilities for plugins
3. **Plugins** — implementations for different apps/services/systems; each provides build/deploy logic using the provided configuration

Note that this project is in an early development stage so there won't be API/spec stability for a while.
You may need to update your configuration as new versions are released and the design is iterated and improved.

## Implement a New Plugin

To implement a new plugin:

1. Create a file named `$pluginName.lmm.rb` in the appropriate category under the `Plugins/` folder
2. Inside, create a method named `action#{pluginName}Deploy` and implement your logic there
3. The file is loaded automatically — no other changes needed

Look at existing plugins for reference. A good starting point is [`porkbun.lmm.rb`](/Plugins/Platforms/porkbun.lmm.rb) — copy and rename it as your base.

### Plugin Categories

| Folder | Purpose |
|---|---|
| `Plugins/Apps/` | Application plugins (web apps, databases, etc.) |
| `Plugins/Services/` | Network services (DNS, etc.) |
| `Plugins/OS/` | Operating system support (Linux distros, etc.) |
| `Plugins/Platforms/` | Hosting platforms (cloud providers, hypervisors, etc.) |

## Model Configuration for an App/Service/System

Even without writing code, you can contribute by modeling your existing infrastructure as high-level
YAML and submitting it under the `Examples/` folder.

This helps us design the best configuration file format *before* implementing support for something.
And you never know — maybe someone will love it enough to implement the necessary plugins, benefiting
everyone.

See [`Examples/Implemented.mm.yaml`](/Examples/Implemented.mm.yaml) for examples of currently supported configuration.
