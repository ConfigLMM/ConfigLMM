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
        class UserToken
          include Fog::Proxmox::Auth::Token

          NAME = 'user_token'

          attr_reader :token_id

          class URIError < RuntimeError; end

          def auth_method
            'GET'
          end

          def auth_path(params = {})
            raise URIError, 'URI params are required' if params.nil? || params.empty?

            if params[:proxmox_userid].nil? || params[:proxmox_userid].empty?
              raise URIError,
                    'proxmox_userid is required'
            end
            if params[:proxmox_tokenid].nil? || params[:proxmox_tokenid].empty?
              raise URIError,
                    'proxmox_tokenid is required'
            end

            "/access/users/#{URI.encode_www_form_component(params[:proxmox_userid])}/token/#{params[:proxmox_tokenid]}"
          end

          def auth_body(_params = {})
            ''
          end

          def no_token?(params)
            (params.respond_to?(:proxmox_token) || params[:proxmox_token].nil? || params[:proxmox_token].empty?) && (@token.nil? || @token.empty?)
          end

          def set_credentials(params)
            token = @token
            token = params[:proxmox_token] if token.empty?
            token_id = @token_id
            token_id = params[:proxmox_tokenid] if token_id.empty?
            userid = @userid
            userid = params[:proxmox_userid] if userid.empty?
            { userid: userid, token_id: token_id, token: token }
          end

          def headers(_method = 'GET', params = {}, additional_headers = {})
            raise URIError, 'User token is required' if no_token?(params)

            credentials = set_credentials(params)
            headers_hash = {}
            headers_hash.store('Authorization',
                               "PVEAPIToken=#{credentials[:userid]}!#{credentials[:token_id]}=#{credentials[:token]}")
            headers_hash.merge! additional_headers
            headers_hash
          end

          def build_credentials(proxmox_options, data)
            @expires = data['expire']
            @token = proxmox_options[:proxmox_token]
            @token_id = proxmox_options[:proxmox_tokenid]
            @userid = proxmox_options[:proxmox_userid]
          end

          def missing_credentials(options)
            missing_credentials = []
            missing_credentials << :proxmox_userid unless options[:proxmox_userid]
            missing_credentials << :proxmox_tokenid unless options[:proxmox_tokenid]
            missing_credentials << :proxmox_token unless options[:proxmox_token]
            return if missing_credentials.empty?

            raise ArgumentError,
                  "Missing required arguments: #{missing_credentials.join(', ')}"
          end
        end
      end
    end
  end
end
