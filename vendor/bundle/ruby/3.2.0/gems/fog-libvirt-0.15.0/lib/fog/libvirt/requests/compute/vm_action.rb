module Fog
  module Libvirt
    class Compute
      module Shared
        def vm_action(uuid, action, *params)
          domain = client.lookup_domain_by_uuid(uuid)
          domain.send(action, *params)
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
