# frozen_string_literal: true

module Fog
  module Proxmox
    class Storage
      # class Real create
      class Real
        def create(body_params)
          request(
            expects: [200],
            method: 'POST',
            path: "storage",
            body: URI.encode_www_form(body_params)
          )
        end
      end

      # class Mock create
      class Mock
      end
    end
  end
end
