# frozen_string_literal: true

require 'fog/core/model'

module Fog
  module DNS
    class PowerDNS
      class Zone < Fog::Model
        identity :zone_id

        attribute :zone, aliases: 'name'
        attribute :server_id

        def destroy
          service.delete_zone(identity)
          true
        end

        def records
          # TODO: Should rewrite this
          @records ||= begin
            Fog::DNS::PowerDNS::Records.new(
              zone: self,
              service: service
            )
          end
        end

        def save
          requires :zone
          data = service.create_zone(zone).body['zone']
          merge_attributes(data)
          true
        end
      end
    end
  end
end
