# -*- encoding: utf-8 -*-
# stub: porkbun 1.0.0 ruby lib

Gem::Specification.new do |s|
  s.name = "porkbun".freeze
  s.version = "1.0.0"

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.metadata = { "homepage_uri" => "https://github.com/danielb2/porkbun-ruby", "source_code_uri" => "https://github.com/danielb2/porkbun-ruby" } if s.respond_to? :metadata=
  s.require_paths = ["lib".freeze]
  s.authors = ["Daniel Bretoi".freeze]
  s.date = "2025-02-05"
  s.description = "Porkbun API wrapper for Ruby.".freeze
  s.email = ["daniel@otherware.org".freeze]
  s.executables = ["porkbun".freeze]
  s.files = ["bin/porkbun".freeze]
  s.homepage = "https://github.com/danielb2/porkbun-ruby".freeze
  s.required_ruby_version = Gem::Requirement.new(">= 2.6.0".freeze)
  s.rubygems_version = "3.4.20".freeze
  s.summary = "Porkbun API wrapper for Ruby.".freeze

  s.installed_by_version = "3.4.20" if s.respond_to? :installed_by_version

  s.specification_version = 4

  s.add_runtime_dependency(%q<http>.freeze, ["~> 5.2.0"])
  s.add_runtime_dependency(%q<thor>.freeze, ["~> 1.2"])
end
