# encoding: UTF-8
# frozen_string_literal: true

require_relative 'lib/ConfigLMM/version'

Gem::Specification.new do |spec|
    spec.name = 'ConfigLMM'
    spec.version = ConfigLMM::VERSION
    spec.authors = ['Dāvis Mosāns']
    spec.email = ['davispuh@gmail.com']

    spec.summary = 'Manage configuration for your applications/systems/services/servers'
    spec.description = 'ConfigLMM is Configuration Management Manager that can build and deploy your configuration to different providers like Puppet, Chef, Terraform and others.'
    spec.homepage = 'https://github.com/davispuh/ConfigLMM'
    spec.required_ruby_version = '>= 3.0.0'

    spec.metadata['homepage_uri'] = spec.homepage
    spec.metadata['source_code_uri'] = 'https://github.com/davispuh/ConfigLMM'
    spec.metadata['changelog_uri'] = 'https://github.com/davispuh/ConfigLMM/CHANGELOG.md'

    # Specify which files should be added to the gem when it is released.
    # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
    gemspec = File.basename(__FILE__)
    spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
        ls.readlines("\x0", chomp: true).reject do |f|
          (f == gemspec) || f.start_with?(*%w[test/ spec/ features/ .git appveyor Gemfile])
        end
    end
    spec.bindir = 'bin'
    spec.executables = ['configlmm']
    spec.require_paths = ['lib']

    spec.add_dependency 'addressable'
    spec.add_dependency 'bcrypt_pbkdf' # for net-ssh ed25519 key support
    spec.add_dependency 'ed25519'
    spec.add_dependency 'faraday-retry'
    spec.add_dependency 'faraday-multipart'
    spec.add_dependency 'http', '~> 5.1.1'
    spec.add_dependency 'net-ssh'
    spec.add_dependency 'nokogiri'
    spec.add_dependency 'public_suffix'
    spec.add_dependency 'xdg'
    spec.add_dependency 'webrick'
    spec.add_dependency 'thor', '>= 1.0'
    spec.add_dependency 'tty-command', '>= 0.10'
    spec.add_dependency 'tty-logger', '>= 0.6'
    spec.add_dependency 'tty-option', '>= 0.1'
    spec.add_dependency 'tty-progressbar', '>= 0.18'
    spec.add_dependency 'tty-prompt', '>= 0.23'
    spec.add_dependency 'tty-spinner', '>= 0.9'
    spec.add_dependency 'tty-which', '>= 0.4'

    spec.add_development_dependency 'yard'
    spec.add_development_dependency 'simplecov'

    # For more information and examples about making a new gem, check out our
    # guide at: https://bundler.io/guides/creating_gem.html
end
