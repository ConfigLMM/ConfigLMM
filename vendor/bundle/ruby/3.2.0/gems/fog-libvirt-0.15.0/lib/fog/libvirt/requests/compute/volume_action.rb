module Fog
  module Libvirt
    class Compute
      module Shared
        def volume_action(key, action, options={})
          get_volume({:key => key}, true).send(action)
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
