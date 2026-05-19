module Fog
  module Libvirt
    class Compute
      module Shared
        def list_pools(filter = { })
          data=[]
          if filter.key?(:name)
            data << find_pool_by_name(filter[:name], filter[:include_inactive])
          elsif filter.key?(:uuid)
            data << find_pool_by_uuid(filter[:uuid], filter[:include_inactive])
          else
            (client.list_storage_pools + client.list_defined_storage_pools).each do |name|
              data << find_pool_by_name(name, filter[:include_inactive])
            end
          end
          data.compact
        end

        private

        def find_pool_by_name name, include_inactive
          pool_to_attributes(client.lookup_storage_pool_by_name(name), include_inactive)
        rescue ::Libvirt::RetrieveError
          nil
        end

        def find_pool_by_uuid uuid, include_inactive
          pool_to_attributes(client.lookup_storage_pool_by_uuid(uuid), include_inactive)
        rescue ::Libvirt::RetrieveError
          nil
        end

        def pool_to_attributes(pool, include_inactive = nil)
          return nil unless pool.active? || include_inactive

          states=[:inactive, :building, :running, :degrated, :inaccessible]
          {
            :uuid           => pool.uuid,
            :persistent     => pool.persistent?,
            :autostart      => pool.autostart?,
            :active         => pool.active?,
            :name           => pool.name,
            :allocation     => pool.info.allocation,
            :capacity       => pool.info.capacity,
            :num_of_volumes => pool.active? ? pool.num_of_volumes : nil,
            :state          => states[pool.info.state]
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
