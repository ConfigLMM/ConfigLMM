# frozen_string_literal: true

# Copyright 2018 Tristan Robert

# This file is part of Fog::Proxmox.

# Fog::Proxmox is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.

# Fog::Proxmox is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

# You should have received a copy of the GNU General Public License
# along with Fog::Proxmox. If not, see <http://www.gnu.org/licenses/>.

require 'fog/json'
require 'fog/proxmox/variables'
require 'fog/proxmox/json'

module Fog
  module Proxmox
    # Core module
    module Auth
      module Token
        class AccessTicket
          include Fog::Proxmox::Auth::Token

          NAME = 'access_ticket'

          attr_reader :csrf_token

          class URIError < RuntimeError; end

          EXPIRATION_DELAY = 2 * 60 * 60

          def auth_method
            'POST'
          end

          def auth_path(_params = {})
            '/access/ticket'
          end

          def auth_body(params = {})
            raise URIError, 'URI params is required' if params.nil? || params.empty?

            if params[:proxmox_username].nil? || params[:proxmox_username].empty?
              raise URIError,
                    'proxmox_username is required'
            end
            if params[:proxmox_password].nil? || params[:proxmox_password].empty?
              raise URIError,
                    'proxmox_password is required'
            end

            URI.encode_www_form(username: params[:proxmox_username], password: params[:proxmox_password])
          end

          def headers(method = 'GET', _params = {}, additional_headers = {})
            headers_hash = {}
            @data ||= {}
            unless @data.empty?
              headers_hash.store('Cookie', "PVEAuthCookie=#{@data['ticket']}")
              if %w[PUT POST DELETE].include? method
                headers_hash.store('CSRFPreventionToken', @data['CSRFPreventionToken'])
              end
            end
            headers_hash.merge! additional_headers
            headers_hash
          end

          def build_credentials(_proxmox_options, data)
            @token = data['ticket']
            @expires = Time.now.utc.to_i + EXPIRATION_DELAY
            @userid = data['username']
            @csrf_token = data['CSRFPreventionToken']
          end

          def missing_credentials(options)
            missing_credentials = []
            missing_credentials << :proxmox_username unless options[:proxmox_username]
            missing_credentials << :proxmox_password unless options[:proxmox_password]
            return if missing_credentials.empty?

            raise ArgumentError,
                  "Missing required arguments: #{missing_credentials.join(', ')}"
          end
        end
      end
    end
  end
end
