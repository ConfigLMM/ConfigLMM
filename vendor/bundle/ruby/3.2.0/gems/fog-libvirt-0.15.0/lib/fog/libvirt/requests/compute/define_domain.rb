module Fog
  module Libvirt
    class Compute
      module Shared
        def define_domain(xml)
          client.define_domain_xml(xml)
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
