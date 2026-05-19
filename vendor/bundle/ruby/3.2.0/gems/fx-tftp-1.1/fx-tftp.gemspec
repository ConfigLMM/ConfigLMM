# coding: utf-8
#

require File.expand_path('../lib/tftp/version', __FILE__)

Gem::Specification.new do |s|
  s.name          = 'fx-tftp'
  s.version       = TFTP::VERSION
  s.date          = Time.now

  s.summary       = %q{Hackable and ACTUALLY WORKING pure-Ruby TFTP server}
  s.description   = %q{Got carried away a bit with the OOness of the whole thing, so while it won't be the fastest TFTP server it might be the most flexible, at least for pure-Ruby ones. With all the infastructure already in place adding a client should be a breeze, should anyone need it.}
  s.license       = 'BSD-2-Clause'
  s.authors       = ['Piotr S. Staszewski']
  s.email         = 'p.staszewski@gmail.com'
  s.homepage      = 'https://github.com/drbig/fx-tftp'

  s.files         = `git ls-files`.split("\n")
  s.executables   = ['tftpd']
  s.test_files    = s.files.grep(%r{^test/})
  s.require_paths = ['lib']

  s.required_ruby_version = '>= 1.9.3'

  s.add_development_dependency 'rubygems-tasks', '~> 0.2'
  s.add_development_dependency 'minitest', '~> 5.4'
  s.add_development_dependency 'rake', '~> 10.0'
end
