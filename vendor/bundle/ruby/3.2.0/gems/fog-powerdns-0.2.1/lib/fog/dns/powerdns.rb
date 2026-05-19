# frozen_string_literal: true

module Fog
  module DNS
    class PowerDNS < Fog::Service
      requires :pdns_api_key
      recognizes :host, :port, :persistent, :scheme, :timeout

      model_path 'fog/dns/powerdns/models'
      model :zone
      collection :zones
      # collection  :rrsets

      request_path 'fog/dns/powerdns/requests'
      request :list_servers
      request :get_server
      request :list_server_configs
      request :get_server_config
      request :update_server_config
      request :list_zones
      request :create_zone
      request :get_zone
      request :delete_zone
      request :update_rrsets
      request :update_zone
      request :notify_zone
      request :retrieve_zone
      request :list_cryptokeys
      request :get_cryptokey
      request :search_log
      request :get_server_stats

      class Mock
      end

      class Real
        def initialize(options = {})
          @pdns_api_key = options[:pdns_api_key]
          @connection_options = options[:connection_options] || {}
          @host = options[:host] || '127.0.0.1'
          @persistent = options[:persistent] || false
          @port = options[:port] || 8081
          @scheme = options[:scheme] || 'http'
          @api_version = options[:api_version] || 'v1'

          @connection = Fog::XML::Connection.new("#{@scheme}://#{@host}:#{@port}", @persistent, @connection_options)
        end

        def reload
          @connection.reset
        end

        def request(params)
          params[:headers] ||= {}
          params[:headers]['X-API-key'] = @pdns_api_key.to_s
          params[:headers].merge!(
            'Accept' => 'application/json',
            'Content-Type' => 'application/json'
          )

          response = @connection.request(params)

          response.body = Fog::JSON.decode(response.body) unless response.body.empty?
          response
        end
      end
    end
  end
end
