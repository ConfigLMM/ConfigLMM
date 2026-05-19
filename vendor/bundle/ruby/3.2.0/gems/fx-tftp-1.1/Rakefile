require 'rake/testtask'

begin
  require 'rubygems/tasks'
  Gem::Tasks.new
rescue LoadError => e
  warn e.message
end

begin
  require 'yard'
  YARD::Rake::YardocTask.new
  task :doc => :yard
rescue LoadError => e
  warn e.message
end

task :default => :test

Rake::TestTask.new do |t|
  t.libs = ['lib', 'test']
  t.name = 'test'
  t.warning = true
  t.test_files = FileList['test/*.rb']
end

FileList['test/*.rb'].each do |p|
  name = p.split('/').last.split('.').first
  Rake::TestTask.new do |t|
    t.libs = ['lib', 'test']
    t.name = "test:#{name}"
    t.warning = true
    t.test_files = [p]
  end
end
