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

# frozen_string_literal: true

# There are basically two modes of operation for these specs.
#
# 1. ENV[PROXMOX_URL] exists: talk to an actual Proxmox server and record HTTP
#    traffic in VCRs at "spec/debug" (credentials are read from the conventional
#    environment variables: PROXMOX_URL, PROXMOX_USERNAME, PROXMOX_PASSWORD)
# 2. otherwise (Travis etc.): use VCRs at "spec/fixtures/proxmox/#{service}"

require 'vcr'
require 'fog/proxmox/auth/token'

class ProxmoxVCR
  attr_reader :username,
              :password,
              :tokenid,
              :token,
              :service,
              :url

  def initialize(options)
    @vcr_directory = options[:vcr_directory]
    @service_class = options[:service_class]
    @connection_options = options[:connection_options] || {}

    use_recorded = !ENV.key?('PROXMOX_URL') || ENV['USE_VCR'] == 'true'

    if use_recorded
      Fog.interval = 0
      @url  = 'https://192.168.56.101:8006/api2/json'
    else
      @url  = ENV['PROXMOX_URL']
    end

    VCR.configure do |config|
      config.allow_http_connections_when_no_cassette = true
      if use_recorded
        config.cassette_library_dir = ENV['SPEC_PATH'] || @vcr_directory
        config.default_cassette_options = { record: :none }
        config.default_cassette_options[:match_requests_on] = %i[method path body]
      else
        config.cassette_library_dir = 'spec/debug'
        config.default_cassette_options = { record: :all }
      end
      config.hook_into :webmock
      config.debug_logger = nil # use $stderr to debug
    end

    VCR.use_cassette('common_auth') do
      Fog::Proxmox.clear_token_cache

      @auth_method = Fog::Proxmox::Auth::Token::AccessTicket::NAME
      @username  = 'root@pam'
      @password  = 'proxmox01'
      @tokenid = 'root1'
      @token = 'ed6402b4-641d-46b1-b20a-33ba9ba12f54'

      unless use_recorded
        @auth_method = ENV['PROXMOX_AUTH_METHOD'] || options[:auth_method] || @auth_method
        @username = ENV['PROXMOX_USERNAME'] || options[:username] || @username
        @password = ENV['PROXMOX_PASSWORD'] || options[:password] || @password
        @tokenid = ENV['PROXMOX_TOKENID'] || options[:tokenid] || @tokenid
        @token = ENV['PROXMOX_TOKEN'] || options[:token] || @token
      end

      connection_params = {
        proxmox_url: @url,
        proxmox_auth_method: @auth_method,
        proxmox_username: @username,
        proxmox_password: @password,
        proxmox_tokenid: @tokenid,
        proxmox_token: @token,
        connection_options: @connection_options
      }

      @service = @service_class.new(connection_params)
    end
  end
end
