# frozen_string_literal: true

module Fog
  module Proxmox
    class Storage
      # class Real list_appliances
      class Real
        def list_appliances(options)
          node = options[:node]
          request(
            expects: [200],
            method: 'GET',
            path: "nodes/#{node}/aplinfo"
          )
        end
      end

      # class Mock list_appliances
      class Mock
      end
    end
  end
end
