# -*- encoding: utf-8 -*-
# stub: fog-proxmox-configlmm 0.15.1 ruby lib

Gem::Specification.new do |s|
  s.name = "fog-proxmox-configlmm".freeze
  s.version = "0.15.1"

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.metadata = { "rubygems_mfa_required" => "true" } if s.respond_to? :metadata=
  s.require_paths = ["lib".freeze]
  s.authors = ["ConfigLMM".freeze]
  s.date = "2025-04-26"
  s.description = "This library can be used as a module for `fog`.".freeze
  s.homepage = "https://github.com/fog/fog-proxmox".freeze
  s.licenses = ["GPL-3.0".freeze]
  s.required_ruby_version = Gem::Requirement.new(">= 2.5".freeze)
  s.rubygems_version = "3.4.20".freeze
  s.summary = "Fork of fog-proxmox with few improvements".freeze

  s.installed_by_version = "3.4.20" if s.respond_to? :installed_by_version

  s.specification_version = 4

  s.add_development_dependency(%q<bundler>.freeze, ["~> 2.1"])
  s.add_development_dependency(%q<bundler-audit>.freeze, ["~> 0.6"])
  s.add_development_dependency(%q<debase>.freeze, ["~> 0.2.2"])
  s.add_development_dependency(%q<debride>.freeze, ["~> 1.8"])
  s.add_development_dependency(%q<fasterer>.freeze, ["~> 0.3"])
  s.add_development_dependency(%q<fastri>.freeze, ["~> 0.3"])
  s.add_development_dependency(%q<minitest>.freeze, ["~> 5.11"])
  s.add_development_dependency(%q<pry>.freeze, ["~> 0.11"])
  s.add_development_dependency(%q<rake>.freeze, ["~> 12.3"])
  s.add_development_dependency(%q<rcodetools>.freeze, ["~> 0.3"])
  s.add_development_dependency(%q<reek>.freeze, ["~> 6.1"])
  s.add_development_dependency(%q<rspec>.freeze, ["~> 3.7"])
  s.add_development_dependency(%q<rubocop>.freeze, ["~> 1.39"])
  s.add_development_dependency(%q<rubocop-factory_bot>.freeze, ["< 2.26.0"])
  s.add_development_dependency(%q<rubocop-minitest>.freeze, ["~> 0.24"])
  s.add_development_dependency(%q<rubocop-rake>.freeze, ["~> 0.6"])
  s.add_development_dependency(%q<rubocop-rspec>.freeze, ["~> 2.15"])
  s.add_development_dependency(%q<rubocop-rspec_rails>.freeze, ["< 2.29.0"])
  s.add_development_dependency(%q<ruby-debug-ide>.freeze, ["~> 0.6"])
  s.add_development_dependency(%q<simplecov>.freeze, ["~> 0.21"])
  s.add_development_dependency(%q<vcr>.freeze, ["~> 4.0"])
  s.add_development_dependency(%q<webmock>.freeze, ["~> 3.5"])
  s.add_runtime_dependency(%q<fog-core>.freeze, ["~> 2.1"])
  s.add_runtime_dependency(%q<fog-json>.freeze, ["~> 1.2"])
end
