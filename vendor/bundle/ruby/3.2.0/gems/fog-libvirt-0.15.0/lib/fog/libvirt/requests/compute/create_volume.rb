module Fog
  module Libvirt
    class Compute
      module Shared
        def create_volume(pool_name, xml)
          client.lookup_storage_pool_by_name(pool_name).create_vol_xml(xml)
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
