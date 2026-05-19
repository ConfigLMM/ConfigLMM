require 'fog/core/collection'
require 'fog/libvirt/models/compute/network'

module Fog
  module Libvirt
    class Compute
      class Networks < Fog::Collection
        model Fog::Libvirt::Compute::Network

        def all(filter={})
          load(service.list_networks(filter))
        end

        def get(uuid)
          self.all(:uuid => uuid).first
        end
      end
    end
  end
end
