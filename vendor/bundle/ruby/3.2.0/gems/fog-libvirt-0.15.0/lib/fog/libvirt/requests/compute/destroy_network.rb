module Fog
  module Libvirt
    class Compute
      module Shared
        def destroy_network(uuid)
          client.lookup_network_by_uuid(uuid).destroy
        end
      end

      class Real
        include Shared
      end

      class Mock
        include Shared
      end
    end
  end
end
