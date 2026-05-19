module Fog
  module Libvirt
    class Compute
      module Shared
        def define_pool(xml)
          client.define_storage_pool_xml(xml)
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
