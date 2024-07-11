# frozen_string_literal: true

require 'bundler/gem_tasks'
require 'rspec/core/rake_task'
require 'yard'

RSpec::Core::RakeTask.new(:spec) do |t|
    t.pattern = 'spec/**/*_spec.rb,Plugins/**/*_spec.rb'
end

YARD::Rake::YardocTask.new(:doc) do |t|
    t.files = ['**/*.rb', '*.rb', '-', '*.md']
end

task default: :spec
