require 'fog/core/collection'
require 'fog/libvirt/models/compute/volume'

module Fog
  module Libvirt
    class Compute
      class Volumes < Fog::Collection
        model Fog::Libvirt::Compute::Volume

        def all(filter = {})
          load(service.list_volumes(filter))
        end

        def get(key)
          self.all(:key => key).first
        end
      end
    end
  end
end
