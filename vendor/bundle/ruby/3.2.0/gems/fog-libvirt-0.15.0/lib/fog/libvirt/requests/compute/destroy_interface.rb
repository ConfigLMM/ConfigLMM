module Fog
  module Libvirt
    class Compute
      module Shared
        #shutdown the interface
        def destroy_interface(uuid)
          client.lookup_interface_by_uuid(uuid).destroy
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
