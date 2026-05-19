# frozen_string_literal: true

require 'fog/powerdns/version'
require 'fog/core'
require 'fog/xml'
require 'fog/json'

module Fog
  module DNS
    autoload :PowerDNS, File.expand_path('../dns/powerdns', __FILE__)
  end

  module PowerDNS
    extend Fog::Provider

    service(:dns, 'DNS')
  end
end
