# -*- encoding: utf-8 -*-
# stub: fx-tftp 1.1 ruby lib

Gem::Specification.new do |s|
  s.name = "fx-tftp".freeze
  s.version = "1.1"

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib".freeze]
  s.authors = ["Piotr S. Staszewski".freeze]
  s.date = "2016-10-13"
  s.description = "Got carried away a bit with the OOness of the whole thing, so while it won't be the fastest TFTP server it might be the most flexible, at least for pure-Ruby ones. With all the infastructure already in place adding a client should be a breeze, should anyone need it.".freeze
  s.email = "p.staszewski@gmail.com".freeze
  s.executables = ["tftpd".freeze]
  s.files = ["bin/tftpd".freeze]
  s.homepage = "https://github.com/drbig/fx-tftp".freeze
  s.licenses = ["BSD-2-Clause".freeze]
  s.required_ruby_version = Gem::Requirement.new(">= 1.9.3".freeze)
  s.rubygems_version = "3.4.20".freeze
  s.summary = "Hackable and ACTUALLY WORKING pure-Ruby TFTP server".freeze

  s.installed_by_version = "3.4.20" if s.respond_to? :installed_by_version

  s.specification_version = 4

  s.add_development_dependency(%q<rubygems-tasks>.freeze, ["~> 0.2"])
  s.add_development_dependency(%q<minitest>.freeze, ["~> 5.4"])
  s.add_development_dependency(%q<rake>.freeze, ["~> 10.0"])
end
