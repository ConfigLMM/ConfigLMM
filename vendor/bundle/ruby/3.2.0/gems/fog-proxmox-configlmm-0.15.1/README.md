![Foreman](.github/fogproxmox.png)

# Fog::Proxmox

![CI](https://github.com/fog/fog-proxmox/workflows/CI/badge.svg)
[![Maintainability](https://api.codeclimate.com/v1/badges/dfcdcc32f096abf1b2b4/maintainability)](https://codeclimate.com/github/fog/fog-proxmox/maintainability)
[![Test Coverage](https://api.codeclimate.com/v1/badges/dfcdcc32f096abf1b2b4/test_coverage)](https://codeclimate.com/github/fog/fog-proxmox/test_coverage)
[![Gem Version](https://badge.fury.io/rb/fog-proxmox.svg)](https://badge.fury.io/rb/fog-proxmox)

This is a [FOG](http://fog.io/) (>= 2.1) module gem to support [Proxmox VE](https://www.proxmox.com/en/proxmox-ve)

It is intended to satisfy this [feature](https://github.com/fog/fog/issues/3644), but Proxmox provider only, and above all this [Foreman](http://www.theforeman.org) [feature](https://projects.theforeman.org/issues/2186).

It is inspired by the great [fog-openstack](https://github.com/fog/fog-openstack) module.

## Compatibility versions

|Fog-Proxmox|Proxmox VE|Fog-core|ruby|
|--|--|--|--|
|<0.6|<5.3|>=1.45|>=2.3|
|>=0.6|>=5.3|>=1.45|>=2.3|
|>=0.8|>=5.4|>=1.45|>=2.3|
|>=0.9|>=6.0|>=2.1|>=2.3|
|>=0.10|>=6.0|>=2.1|>=2.5|
|>=0.14|>=6.2|>=2.1|>=2.5|

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'fog-proxmox'
```

And then execute:

```ruby
bundle install
```

Or install it yourself as:

```ruby
gem install fog-proxmox
```

## Usage

See [documentation](docs/getting_started.md).

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `bundle exec rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Testing

To record your VCR cassettes:

```shell
PROXMOX_URL=https://192.168.56.101:8006/api2/json DISABLE_PROXY=true SSL_VERIFY_PEER=false bundle exec rake spec
```

To replay all your recorded tests:

```shell
USE_VCR=true bundle exec rake spec
```

To replay one group (compute, identity or network) of your recorded tests:

```shell
USE_VCR=true bundle exec rake spec:compute
```

Code formatting:

```shell
bundle exec rake rubocop
```

Auto correcting (safe):

```shell
bundle exec rake rubocop:autocorrect
```

Exclude cops in todo file:

```shell
bundle exec rubocop --auto-gen-config
```

See all available rake tasks:

```shell
bundle exec rake --tasks
```

## Contributing

You can reach the [contributors](.github/CONTRIBUTORS.md).
Bug reports and pull requests are welcome on GitHub at [Fog-Proxmox](https://github.com/fog/fog-proxmox/issues). This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](http://contributor-covenant.org) code of conduct.

Please read [how to contribute](.github/CONTRIBUTING.md).

## License

The gem is available as open source under the terms of the [GPL v3 License](LICENSE).
