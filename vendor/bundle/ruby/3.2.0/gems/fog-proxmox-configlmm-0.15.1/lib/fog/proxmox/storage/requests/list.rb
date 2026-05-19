# frozen_string_literal: true

module Fog
  module Proxmox
    class Storage
      # class Real list
      class Real
        def list(options = {})
          request(
            expects: [200],
            method: 'GET',
            path: "storage"
          )
        end
      end

      # class Mock list
      class Mock
      end
    end
  end
end
