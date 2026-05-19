# -*- encoding: utf-8 -*-
# stub: argon2 2.3.3 ruby lib
# stub: ext/argon2_wrap/extconf.rb

Gem::Specification.new do |s|
  s.name = "argon2".freeze
  s.version = "2.3.3"

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.metadata = { "rubygems_mfa_required" => "true" } if s.respond_to? :metadata=
  s.require_paths = ["lib".freeze]
  s.authors = ["Technion".freeze]
  s.bindir = "exe".freeze
  s.date = "2026-01-10"
  s.description = "Argon2 FFI binding".freeze
  s.email = ["technion@lolware.net".freeze]
  s.extensions = ["ext/argon2_wrap/extconf.rb".freeze]
  s.files = ["ext/argon2_wrap/extconf.rb".freeze]
  s.homepage = "https://github.com/technion/ruby-argon2".freeze
  s.licenses = ["MIT".freeze]
  s.required_ruby_version = Gem::Requirement.new(">= 2.6.0".freeze)
  s.rubygems_version = "3.4.20".freeze
  s.summary = "Argon2 Password hashing binding".freeze

  s.installed_by_version = "3.4.20" if s.respond_to? :installed_by_version

  s.specification_version = 4

  s.add_runtime_dependency(%q<ffi>.freeze, ["~> 1.15"])
  s.add_runtime_dependency(%q<ffi-compiler>.freeze, ["~> 1.0"])
  s.add_development_dependency(%q<bundler>.freeze, [">= 2.0"])
  s.add_development_dependency(%q<minitest>.freeze, ["~> 5.8"])
  s.add_development_dependency(%q<rake>.freeze, ["~> 13.0"])
  s.add_development_dependency(%q<rubocop>.freeze, ["~> 1.7"])
  s.add_development_dependency(%q<simplecov>.freeze, ["~> 0.20"])
  s.add_development_dependency(%q<simplecov-lcov>.freeze, ["~> 0.8"])
  s.add_development_dependency(%q<steep>.freeze, ["~> 1.9.3"])
end
