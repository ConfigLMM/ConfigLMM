module Fog
  module Libvirt
    class Compute
      module Shared
        def list_pool_volumes(uuid)
          pool = client.lookup_storage_pool_by_uuid uuid
          pool.list_volumes.map do |volume_name|
            volume_to_attributes(pool.lookup_volume_by_name(volume_name))
          end
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
