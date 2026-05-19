require 'fog/core/collection'
require 'fog/libvirt/models/compute/nic'

module Fog
  module Libvirt
    class Compute
      class Nics < Fog::Collection
        model Fog::Libvirt::Compute::Nic
      end
    end
  end
end
