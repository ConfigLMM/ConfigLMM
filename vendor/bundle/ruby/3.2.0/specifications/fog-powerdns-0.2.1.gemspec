# -*- encoding: utf-8 -*-
# stub: fog-powerdns 0.2.1 ruby lib

Gem::Specification.new do |s|
  s.name = "fog-powerdns".freeze
  s.version = "0.2.1"

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib".freeze]
  s.authors = ["Chris Luo".freeze]
  s.bindir = "exe".freeze
  s.date = "2024-03-24"
  s.description = "This library can be used as a module for 'fog' or as a standalone provider to use PowerDNS DNS services in applications.".freeze
  s.email = ["luo_christopher@bah.com".freeze]
  s.homepage = "http://github.com/cluobah/fog-powerdns".freeze
  s.licenses = ["MIT".freeze]
  s.rubygems_version = "3.4.20".freeze
  s.summary = "Module for the 'fog' gem to support PowerDNS DNS services.".freeze

  s.installed_by_version = "3.4.20" if s.respond_to? :installed_by_version

  s.specification_version = 4

  s.add_development_dependency(%q<bundler>.freeze, [">= 0"])
  s.add_development_dependency(%q<rake>.freeze, [">= 0"])
  s.add_development_dependency(%q<rubocop>.freeze, [">= 0"])
  s.add_runtime_dependency(%q<fog-core>.freeze, [">= 0"])
  s.add_runtime_dependency(%q<fog-json>.freeze, [">= 0"])
  s.add_runtime_dependency(%q<fog-xml>.freeze, [">= 0"])
end
