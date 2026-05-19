
module Fog
  module Libvirt
    class Compute
      module Shared
        def libversion()
          client.libversion
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
