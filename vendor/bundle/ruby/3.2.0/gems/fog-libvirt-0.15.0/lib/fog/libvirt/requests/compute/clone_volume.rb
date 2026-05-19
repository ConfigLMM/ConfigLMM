module Fog
  module Libvirt
    class Compute
      module Shared
        def clone_volume(pool_name, xml, name)
          vol = client.lookup_storage_pool_by_name(pool_name).lookup_volume_by_name(name)
          client.lookup_storage_pool_by_name(pool_name).create_vol_xml_from(xml, vol)
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
