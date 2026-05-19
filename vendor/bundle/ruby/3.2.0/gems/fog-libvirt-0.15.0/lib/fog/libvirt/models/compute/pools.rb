require 'fog/core/collection'
require 'fog/libvirt/models/compute/pool'

module Fog
  module Libvirt
    class Compute
      class Pools < Fog::Collection
        model Fog::Libvirt::Compute::Pool

        def all(filter = {})
          load(service.list_pools(filter))
        end

        def get(uuid)
          self.all(:uuid => uuid).first
        end
      end
    end
  end
end
