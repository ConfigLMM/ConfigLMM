# frozen_string_literal: true

module Fog
  module Proxmox
    class Storage
      # class Real download_appliance
      class Real
        def download_appliance(path_params, body_params)
          node = path_params[:node]
          request(
            expects: [200],
            method: 'POST',
            path: "nodes/#{node}/aplinfo",
            body: URI.encode_www_form(body_params)
          )
        end
      end

      # class Mock download_appliance
      class Mock
      end
    end
  end
end
