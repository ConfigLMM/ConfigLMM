# -*- encoding: utf-8 -*-
# stub: net-dhcp 1.3.3 ruby lib

Gem::Specification.new do |s|
  s.name = "net-dhcp".freeze
  s.version = "1.3.3"

  s.required_rubygems_version = Gem::Requirement.new(">= 1.3.7".freeze) if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib".freeze]
  s.authors = ["daniel martin gomez (etd)".freeze, "syonbori".freeze, "Mark J. Titorenko".freeze]
  s.date = "2016-06-21"
  s.description = "The aim of Net::DHCP is to provide a set of classes to low level handle the DHCP protocol (rfc2131, rfc2132, etc.). With Net::DHCP you will be able to craft custom DHCP packages and have access to all the fields defined for the protocol.".freeze
  s.email = "mark.titorenko@alces-software.com".freeze
  s.executables = ["net-dhcp".freeze]
  s.extra_rdoc_files = ["LICENSE".freeze, "README".freeze, "CHANGELOG".freeze]
  s.files = ["CHANGELOG".freeze, "LICENSE".freeze, "README".freeze, "bin/net-dhcp".freeze]
  s.homepage = "http://github.com/mjtko/net-dhcp-ruby".freeze
  s.rubygems_version = "3.4.20".freeze
  s.summary = "set of classes to low level handle the DHCP protocol".freeze

  s.installed_by_version = "3.4.20" if s.respond_to? :installed_by_version

  s.specification_version = 3

  s.add_development_dependency(%q<rspec>.freeze, [">= 0"])
  s.add_development_dependency(%q<bundler>.freeze, [">= 0"])
  s.add_development_dependency(%q<bueller>.freeze, [">= 0"])
  s.add_development_dependency(%q<rake>.freeze, [">= 0"])
  s.add_development_dependency(%q<simplecov>.freeze, [">= 0"])
  s.add_development_dependency(%q<rdoc>.freeze, [">= 0"])
end
