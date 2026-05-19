require 'fog/core/collection'
require 'fog/libvirt/models/compute/interface'

module Fog
  module Libvirt
    class Compute
      class Interfaces < Fog::Collection
        model Fog::Libvirt::Compute::Interface

        def all(filter={})
          load(service.list_interfaces(filter))
        end

        def get(name)
          self.all(:name => name).first
        end
      end
    end
  end
end
