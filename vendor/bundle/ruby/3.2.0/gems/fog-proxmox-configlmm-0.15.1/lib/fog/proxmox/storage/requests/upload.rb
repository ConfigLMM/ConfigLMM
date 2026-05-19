# frozen_string_literal: true

require 'securerandom'

module Fog
  module Proxmox
    class Storage
      # class Real upload
      class Real
        def upload(path_params, body_params)
          node = path_params[:node]
          storage = path_params[:storage]
          body, content_type = self.class.build_formdata(body_params)
          request(
            expects: [200],
            method: 'POST',
            path: "nodes/#{node}/storage/#{storage}/upload",
            body: body,
            headers: { 'Content-Type' => content_type }
          )
        end

        def self.build_formdata(body_params)
          boundary = '-' * 30 + SecureRandom.hex(15)

          body = "--#{boundary}" + Excon::CR_NL
          body << 'Content-Disposition: form-data; name="content"' << Excon::CR_NL << Excon::CR_NL
          body << body_params[:content] << Excon::CR_NL
          body << "--#{boundary}" << Excon::CR_NL
          body << %(Content-Disposition: form-data; name="filename"; filename="#{body_params[:filename]}") << Excon::CR_NL
          body << 'Content-Type: ' << (body_params[:content_type] || 'application/octet-stream') << Excon::CR_NL << Excon::CR_NL
          body << body_params[:file].read << Excon::CR_NL
          body << "--#{boundary}--" << Excon::CR_NL

          [body, %(multipart/form-data; boundary=#{boundary})]
        end
      end

      # class Mock upload
      class Mock
      end
    end
  end
end
