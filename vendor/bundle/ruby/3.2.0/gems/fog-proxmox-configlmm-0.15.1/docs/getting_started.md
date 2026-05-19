# Getting started with Fog proxmox

## Requirements

### Ruby

2.3, 2.4 and 2.5 ruby versions are tested and required.
Fog requires 2.0+ for new projects.

## Installation

With rubygems:

```ruby
gem install fog-proxmox
```

With bundler:

Create a Gemfile with:

```ruby
source 'https://rubygems.org'

gem 'fog-proxmox'
```

then:

```ruby
bundler install
```

## Exploring capabilities

```ruby
irb
```

```ruby
require 'fog/proxmox'
```

```ruby
Fog::Proxmox.services
```

This command show you a summary of the available services.

### Available services in details

* [Identity](identity.md)
* [Compute](compute.md)