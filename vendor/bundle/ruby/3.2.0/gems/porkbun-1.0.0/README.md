# Porkbun

Reference: https://porkbun.com/api/json/v3/documentation

This is currently only a partial implementation to suit my own needs. If you
need a specific call to be implemented, let me know, or submit a PR

## Installation

`gem install porkbun`

## Usage

```ruby
ENV['PORKBUN_API_KEY'] = 'YOUR_API_KEY'
ENV['PORKBUN_SECRET_API_KEY'] = 'YOUR_SECRET_API_KEY'
record = Porkbun::DNS.create(name: 'test',
  type: 'A',
  content: '1.1.1.1',
  ttl: 300
)
```

## API

### `Porkbun.ping`

Make sure your keys are good.

### `Porkbun::DNS.retrieve(domain, id)`

Retrive all or specific record for a domain

### `Porkbun::DNS.create(options)`

Create record for a domain

options:
- `name` - name of record. example `www`
- `type` - record type. example: CNAME
- `content` - content of record. example '1.1.1.1',
- `ttl` - time to live. example: 600. porkbun seems to have this as a minimum
- `prio` - record priority. mainly for MX records. example 10.

returns instance of DNS which can be used to delete

## CLI

The gem also comes with a CLI

    $ porkbun
    Commands:
      porkbun delete_all <domain>              # deletes all records for a domain. this is destructive. use with caution
      porkbun dyndns <hostname.domain> [<ip>]  # Update a dynamic dns record. example: porkbun dyndns home.example.com
      porkbun help [COMMAND]                   # Describe available commands or one specific command
      porkbun import <file>                    # Import BIND zone file
      porkbun list                             # List all domains
      porkbun retrieve <domain> [<id>]         # List all records for a domain


be sure to set the environmental variables for it to work

export PORKBUN_API_KEY = YOUR_API_KEY
export PORKBUN_SECRET_API_KEY = YOUR_SECRET_API_KEY

## Development

After checking out the repo, run `bin/setup` to install dependencies. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/danielb2/porkbun-ruby.
