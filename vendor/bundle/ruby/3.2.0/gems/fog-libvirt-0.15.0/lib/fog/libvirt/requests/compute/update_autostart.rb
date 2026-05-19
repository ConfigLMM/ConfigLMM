module Fog
  module Libvirt
    class Compute
      module Shared
        def update_autostart(uuid, value)
          domain = client.lookup_domain_by_uuid(uuid)
          domain.autostart = value
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
