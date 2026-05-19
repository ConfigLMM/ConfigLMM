# -*- encoding: utf-8 -*-
# stub: tty-option 0.3.0 ruby lib

Gem::Specification.new do |s|
  s.name = "tty-option".freeze
  s.version = "0.3.0"

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.metadata = { "allowed_push_host" => "https://rubygems.org", "bug_tracker_uri" => "https://github.com/piotrmurach/tty-option/issues", "changelog_uri" => "https://github.com/piotrmurach/tty-option/blob/master/CHANGELOG.md", "documentation_uri" => "https://www.rubydoc.info/gems/tty-option", "homepage_uri" => "https://ttytoolkit.org", "rubygems_mfa_required" => "true", "source_code_uri" => "https://github.com/piotrmurach/tty-option" } if s.respond_to? :metadata=
  s.require_paths = ["lib".freeze]
  s.authors = ["Piotr Murach".freeze]
  s.date = "2023-05-29"
  s.description = "Parser for command line arguments, keywords, flags, options and environment variables.".freeze
  s.email = ["piotr@piotrmurach.com".freeze]
  s.extra_rdoc_files = ["README.md".freeze, "CHANGELOG.md".freeze, "LICENSE.txt".freeze]
  s.files = ["CHANGELOG.md".freeze, "LICENSE.txt".freeze, "README.md".freeze]
  s.homepage = "https://ttytoolkit.org".freeze
  s.licenses = ["MIT".freeze]
  s.required_ruby_version = Gem::Requirement.new(">= 2.0.0".freeze)
  s.rubygems_version = "3.4.20".freeze
  s.summary = "An intuitive and flexible command line parser.".freeze

  s.installed_by_version = "3.4.20" if s.respond_to? :installed_by_version

  s.specification_version = 4

  s.add_development_dependency(%q<rake>.freeze, [">= 0"])
  s.add_development_dependency(%q<rspec>.freeze, [">= 3.0"])
end
