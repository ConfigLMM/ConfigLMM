require 'fog/core'
require 'fog/xml'
require 'fog/json'
require 'libvirt'

require File.expand_path('../libvirt/version', __FILE__)

module Fog
  module Libvirt
    extend Fog::Provider

    autoload :Compute, File.expand_path('../libvirt/compute', __FILE__)

    service(:compute, 'Compute')
  end
end
