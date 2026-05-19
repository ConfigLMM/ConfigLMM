module Fog
  module Libvirt
    class Compute
      module Shared
        def pool_action(uuid, action)
          pool = client.lookup_storage_pool_by_uuid uuid
          pool.send(action)
          true
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
