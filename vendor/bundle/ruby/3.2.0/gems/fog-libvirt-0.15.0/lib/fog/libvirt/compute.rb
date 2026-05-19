require 'fog/libvirt/models/compute/util/util'
require 'fog/libvirt/models/compute/util/uri'

module Fog
  module Libvirt
    class Compute < Fog::Service
      requires   :libvirt_uri
      recognizes :libvirt_username, :libvirt_password

      model_path 'fog/libvirt/models/compute'
      model       :server
      collection  :servers
      model       :network
      collection  :networks
      model       :interface
      collection  :interfaces
      model       :volume
      collection  :volumes
      model       :pool
      collection  :pools
      model       :node
      collection  :nodes
      model       :nic
      collection  :nics

      request_path 'fog/libvirt/requests/compute'
      request :list_domains
      request :create_domain
      request :define_domain
      request :vm_action
      request :list_pools
      request :list_pool_volumes
      request :define_pool
      request :pool_action
      request :list_volumes
      request :volume_action
      request :create_volume
      request :upload_volume
      request :clone_volume
      request :list_networks
      request :destroy_network
      request :dhcp_leases
      request :list_interfaces
      request :destroy_interface
      request :get_node_info
      request :update_autostart
      request :update_display
      request :libversion

      module Shared
        include Fog::Libvirt::Util

        attr_reader :client
        attr_reader :uri

        def initialize(options={})
          super()
          @uri = ::Fog::Libvirt::Util::URI.new(enhance_uri(options[:libvirt_uri]))

          # libvirt is part of the gem => ruby-libvirt
          begin
            require 'libvirt'
          rescue LoadError => e
            retry if require('rubygems')
            raise e.message
          end

          begin
            if options[:libvirt_username] and options[:libvirt_password]
              @client = ::Libvirt::open_auth(uri.uri, [::Libvirt::CRED_AUTHNAME, ::Libvirt::CRED_PASSPHRASE]) do |cred|
                case cred['type']
                  when ::Libvirt::CRED_AUTHNAME
                    options[:libvirt_username]
                  when ::Libvirt::CRED_PASSPHRASE
                    options[:libvirt_password]
                end
              end
            else
              @client = ::Libvirt::open(uri.uri)
            end

          rescue ::Libvirt::ConnectionError
            raise Fog::Errors::Error.new("Error making a connection to libvirt URI #{uri.uri}:\n#{$!}")
          end
        end

        def terminate
          @client.close if @client and !@client.closed?
        end

        def enhance_uri(uri)
          require 'cgi'
          append=""

          # on macosx, chances are we are using libvirt through homebrew
          # the client will default to a socket location based on it's own location (/opt)
          # we conveniently point it to /var/run/libvirt/libvirt-sock
          # if no socket option has been specified explicitly and
          # if the socket exists

          socketpath="/var/run/libvirt/libvirt-sock"
          if RUBY_PLATFORM =~ /darwin/ && File.exist?(socketpath)
            querystring=::URI.parse(uri).query
            if querystring.nil?
              append="?socket=#{socketpath}"
            elsif !::CGI.parse(querystring).key?("socket")
              append="&socket=#{socketpath}"
            end
          end
          uri+append
        end
      end

      class Real
        include Shared
      end

      class Mock
        include Shared

        def enhance_uri(uri)
          uri = 'test:///default' unless ::URI.parse(uri).scheme == 'test'

          super(uri)
        end
      end
    end
  end
end
