module Fog
  module Libvirt
    class Compute
      module Shared
        def list_networks(filter = { })
          data=[]
          if filter.keys.empty?
            (client.list_networks + client.list_defined_networks).each do |network_name|
              data << network_to_attributes(client.lookup_network_by_name(network_name))
            end
          else
            data = [network_to_attributes(get_network_by_filter(filter))]
          end
          data
        end

        private
        # Retrieve the network by uuid or name
        def get_network_by_filter(filter)
          case filter.keys.first
            when :uuid
              client.lookup_network_by_uuid(filter[:uuid])
            when :name
              client.lookup_network_by_name(filter[:name])
          end
        end

        # bridge name may not be defined in some networks, we should skip that in such case
        def network_to_attributes(net)
          return if net.nil?

          begin
            bridge_name = net.bridge_name
          rescue ::Libvirt::Error
            bridge_name = ''
          end

          {
            :uuid        => net.uuid,
            :name        => net.name,
            :bridge_name => bridge_name
          }
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
