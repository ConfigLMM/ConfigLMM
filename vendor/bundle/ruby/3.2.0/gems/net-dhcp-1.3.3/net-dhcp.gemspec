$:.push File.expand_path("../lib", __FILE__)
require 'net-dhcp/version'

Gem::Specification.new do |s|
  s.name = 'net-dhcp'
  s.version = Net::Dhcp::VERSION
  s.platform = Gem::Platform::RUBY
  s.date = "2016-06-21"
  s.authors = ['daniel martin gomez (etd)', 'syonbori', 'Mark J. Titorenko']
  s.email = 'mark.titorenko@alces-software.com'
  s.homepage = 'http://github.com/mjtko/net-dhcp-ruby'
  s.summary = %Q{set of classes to low level handle the DHCP protocol}
  s.description = %Q{The aim of Net::DHCP is to provide a set of classes to low level handle the DHCP protocol (rfc2131, rfc2132, etc.). With Net::DHCP you will be able to craft custom DHCP packages and have access to all the fields defined for the protocol.}
  s.extra_rdoc_files = [
    'LICENSE',
    'README',
    'CHANGELOG'
  ]

  s.required_rubygems_version = Gem::Requirement.new('>= 1.3.7')
  s.rubygems_version = '1.3.7'
  s.specification_version = 3

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ['lib']

  s.add_development_dependency 'rspec'
  s.add_development_dependency 'bundler'
  s.add_development_dependency 'bueller'
  s.add_development_dependency 'rake'
  s.add_development_dependency 'simplecov'
  s.add_development_dependency 'rdoc'
end

