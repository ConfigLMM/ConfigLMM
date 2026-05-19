require 'fog/core/collection'
require 'fog/libvirt/models/compute/server'

module Fog
  module Libvirt
    class Compute
      class Servers < Fog::Collection
        model Fog::Libvirt::Compute::Server

        def all(filter={})
          load(service.list_domains(filter))
        end

        def get(uuid)
          data = service.list_domains(:uuid => uuid)
          new data.first if data
        end
      end
    end
  end
end
