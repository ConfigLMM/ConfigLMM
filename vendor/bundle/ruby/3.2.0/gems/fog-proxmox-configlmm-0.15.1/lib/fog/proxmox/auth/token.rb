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
require 'fog/core'
require 'fog/proxmox/variables'
require 'fog/proxmox/json'

module Fog
  module Proxmox
    # Core module
    module Auth
      module Token
        autoload :AccessTicket, 'fog/proxmox/auth/token/access_ticket'
        autoload :UserToken, 'fog/proxmox/auth/token/user_token'

        attr_reader :userid, :token, :expires, :data

        class ExpiryError < RuntimeError; end
        class URLError < RuntimeError; end

        def initialize(proxmox_options, options = {})
          if proxmox_options[:proxmox_url].nil? || proxmox_options[:proxmox_url].empty?
            raise URLError,
                  'No proxmox_url provided'
          end

          @token ||= ''
          @token_id ||= ''
          @userid ||= ''
          @data = authenticate(proxmox_options, options)
          build_credentials(proxmox_options, data)
        end

        def self.build(proxmox_options, options)
          unless proxmox_options.key? :proxmox_auth_method
            raise ArgumentError,
                  'Missing required proxmox_auth_method in options.'
          end

          auth_method = proxmox_options[:proxmox_auth_method]
          if auth_method == Fog::Proxmox::Auth::Token::AccessTicket::NAME
            Fog::Proxmox::Auth::Token::AccessTicket.new(proxmox_options, options)
          elsif auth_method == Fog::Proxmox::Auth::Token::UserToken::NAME
            Fog::Proxmox::Auth::Token::UserToken.new(proxmox_options, options)
          else
            raise ArgumentError,
                  "Unkown authentication method: #{auth_method}. Only #{Fog::Proxmox::Auth::Token::AccessTicket::NAME} or #{Fog::Proxmox::Auth::Token::UserToken::NAME} are accepted."
          end
        end

        def authenticate(proxmox_options, connection_options = {})
          uri = URI.parse(proxmox_options[:proxmox_url])
          request = {
            expects: [200, 201],
            headers: headers(auth_method, proxmox_options, { Accept: 'application/json' }),
            body: auth_body(proxmox_options),
            method: auth_method,
            path: uri.path + auth_path(proxmox_options)
          }
          connection = Fog::Core::Connection.new(
            uri.to_s,
            false,
            connection_options
          )
          response = connection.request(request)
          Json.get_data(response)
        end

        def expired?
          raise ExpiryError, 'Missing token expiration data' if @expires.nil? || @expires.empty?

          Time.at(@expires) < Time.now.utc
        end
      end
    end
  end
end
