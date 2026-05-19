# FX-TFTP [![Build Status](https://travis-ci.org/drbig/fx-tftp.svg?branch=master)](https://travis-ci.org/drbig/fx-tftp) [![Gem](http://img.shields.io/gem/v/fx-tftp.svg)](https://rubygems.org/gems/fx-tftp) [![Yard Docs](http://img.shields.io/badge/yard-docs-blue.svg)](http://www.rubydoc.info/github/drbig/fx-tftp/master)

* [Homepage](https://github.com/drbig/fx-tftp)
* [Documentation](http://rubydoc.info/gems/fx-tftp/frames)


## Description

FX-TFTP is a slightly over-OO-ed pure-Ruby implementation of plain [RFC1350](https://www.ietf.org/rfc/rfc1350.txt) TFTP *server*. It is very flexible and intended for hacking. Also, and more importantly, it **works**, contrary to other gems that are occupying space at RubyGems.

That flexibility may be useful if you're planning on massive custom TFTP-based boots, or if you're into ~~hacking~~ researching cheap router security. The request packets parsing has been relaxed so that it should work with TFTP clients that use some fancy extensions. I have tested the server on Linux x86_64 with Ruby 2.2.0 and on FreeBSD amd64 with Ruby 1.9.3p194, and it successfully exchanged data both ways with clients running on numerous platforms.

The included `tftpd` executable gives you a fully-fledged read-write TFTP server that also does logging, daemon mode and does not crap out on `SIGTERM`.


## Quickstart

Just in case you need an easy to use tftp server...
Install via Rubygems:

    $ gem install fx-tftp

Then start the beast with any directory you want to serve (works for uploads and downloads as well):

    $ sudo tftpd ~/router_firmwares_and_config_files/

Further options:
    
    $ tftpd
    Usage: tftpd [OPTIONS] DIR
        -V, --version                    Show version and exit
        -a, --address ADDRESS            Address to listen on (default: 0.0.0.0)
        -p, --port PORT                  Port to listen on (default: 69)
        -v, --verbose                    Enable verbose output


## Hacking

Suppose we want to have a TFTP server that only supports reading, but the files served should depend on the IP block the client is connecting from:

    class CustomHandler < TFTP::Handler::RWSimple
        ip = src.remote_address.ip_address.split('.')
        block = ip.slice(0, 3).join('-')
        req.filename = File.join(block, req.filename)
        log :info, "#{tag} Mapped filename to #{req.filename}"
        super(tag, req, sock, src)
      end
    end
    
    srv = TFTP::Server::Base.new(CustomHandler.new(path, :no_write => true), opts)

When you combine filename inspection and `#send` and `#recv` methods working on plain `IO` objects you can easily whip up things like serving dynamically built scripts/binaries/archives based on parameters passed as the requested 'filename'.


## Contributing

Fell free to contributed patches using the common GitHub model (descried below). I'm also interested in cases where something doesn't work (weird platforms etc.). If you feel like it please write the client side.

 - Fork the repo
 - Checkout a new branch for your changes
 - Write code and tests, check, commit
 - Make a Pull Request


## Licensing

Standard two-clause BSD license, see LICENSE.txt for details.

Copyright © 2015 - 2016 Piotr S. Staszewski
