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
    module Core
      attr_accessor :token
      attr_reader :auth_method, :expires, :current_user

      def user_token?
        @auth_token == 'user_token'
      end

      # fallback
      def self.not_found_class
        Fog::Proxmox::Core::NotFound
      end

      def initialize(options = {})
        setup(options)
        authenticate
        @auth_token.missing_credentials(options)
        @connection = Fog::Core::Connection.new(@proxmox_url, @persistent, @connection_options)
      end

      def setup(options)
        if options.respond_to?(:config_service?) && options.config_service?
          configure(options)
          return
        end
        Fog::Proxmox::Variables.to_variables(self, options, 'proxmox')
        @connection_options = options[:connection_options] || {}
        @connection_options[:disable_proxy] = true if ENV['DISABLE_PROXY'] == 'true'
        @connection_options[:ssl_verify_peer] = false if ENV['SSL_VERIFY_PEER'] == 'false'
        @connection_options[:ignore_unexpected_eof] = true
        @proxmox_must_reauthenticate = true
        @persistent = options[:persistent] || false
        @token ||= options[:proxmox_token]
        @auth_method ||= options[:proxmox_auth_method]
        @proxmox_can_reauthenticate = if @token
                                        false
                                      else
                                        true
                                      end
      end

      def credentials
        options = {
          provider: 'proxmox',
          proxmox_auth_method: @auth_method,
          proxmox_url: @proxmox_uri.to_s,
          current_user: @current_user
        }
        proxmox_options.merge options
      end

      def reload
        @connection.reset
      end

      private

      def expired?
        return false if @expires.nil?
        return false if @expires == 0

        @expires - Time.now.utc.to_i < 60
      end

      def request(params)
        retried = false
        begin
          authenticate! if expired?
          request_options = params.merge(path: "#{@path}/#{params[:path]}",
                                         headers: @auth_token.headers(
                                           params[:method], {}, params.key?(:headers) ? params[:headers] : {}
                                         ))
          response = @connection.request(request_options)
        rescue Excon::Errors::Unauthorized => e
          # token expiration and token renewal possible
          if !%w[Bad username or password, invalid token
                 value!].include?(e.response.body) && @proxmox_can_reauthenticate && !retried
            authenticate!
            retried = true
            retry
          # bad credentials or token renewal not possible
          else
            raise e
          end
        rescue Excon::Errors::HTTPStatusError => e
          raise case e
                when Excon::Errors::NotFound
                  self.class.not_found_class.slurp(e)
                else
                  e
                end
        end
        Fog::Proxmox::Json.get_data(response)
      end

      def proxmox_options
        Fog::Proxmox::Variables.to_hash(self, 'proxmox')
      end

      def authenticate
        if @proxmox_must_reauthenticate
          @token = nil if @proxmox_must_reauthenticate
          @auth_token = Fog::Proxmox::Auth::Token.build(proxmox_options, @connection_options)
          @current_user = proxmox_options[:proxmox_userid] || proxmox_options[:proxmox_username]
          @token = @auth_token.token
          @expires = @auth_token.expires
          @proxmox_must_reauthenticate = false
        else
          @token = @proxmox_token
        end
        uri = URI.parse(@proxmox_url)
        @path = uri.path
        true
      end

      def authenticate!
        @proxmox_must_reauthenticate = true
        authenticate
      end
    end
  end
end
