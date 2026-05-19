require 'fog/core/model'

module Fog
  module Libvirt
    class Compute
      class Node < Fog::Model
        identity :uuid

        attribute :model
        attribute :memory
        attribute :cpus
        attribute :mhz
        attribute :nodes
        attribute :sockets
        attribute :cores
        attribute :threads
        attribute :type
        attribute :version
        attribute :uri
        attribute :node_free_memory
        attribute :max_vcpus
        attribute :manufacturer
        attribute :product
        attribute :serial
        attribute :hostname
      end
    end
  end
end
