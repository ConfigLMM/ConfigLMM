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

require 'resolv'
require 'fog/proxmox/hash'

module Fog
  module Proxmox
    # module IpHelper mixins
    module IpHelper
      CIDRv4_PREFIX = '([0-9]|[1-2][0-9]|3[0-2])'
      CIDRv4_PREFIX_REGEXP = /^#{CIDRv4_PREFIX}$/
      IPv4_SRC = "#{Resolv::IPv4::Regex.source.delete_suffix('\z').delete_prefix('\A')}"
      CIDRv4_REGEXP = Regexp.new("\\A(#{IPv4_SRC})(\/#{CIDRv4_PREFIX})?\\z")
      CIDRv6_PREFIX = '(\d+)'
      CIDRv6_PREFIX_REGEXP = /^#{CIDRv6_PREFIX}$/xi
      IPv6_SRC = "#{Resolv::IPv6::Regex_8Hex.source.delete_suffix('\z').delete_prefix('\A')}"
      CIDRv6_REGEXP = Regexp.new("\\A(#{IPv6_SRC})(\/#{CIDRv6_PREFIX})?\\z", Regexp::EXTENDED | Regexp::IGNORECASE)

      def self.cidr?(ip)
        CIDRv4_REGEXP.match?(ip)
      end

      def self.cidr6?(ip)
        CIDRv6_REGEXP.match?(ip)
      end

      def self.prefix(ip)
        return unless cidr = CIDRv4_REGEXP.match(ip)

        cidr[7]
      end

      def self.prefix6(ip)
        return unless cidr = CIDRv6_REGEXP.match(ip)

        cidr[3]
      end

      def self.ip?(ip)
        Resolv::IPv4::Regex.match?(ip)
      end

      def self.ip6?(ip)
        Resolv::IPv6::Regex.match?(ip)
      end

      def self.cidr_prefix?(prefix)
        CIDRv4_PREFIX_REGEXP.match?(prefix)
      end

      def self.cidr6_prefix?(prefix)
        CIDRv6_PREFIX_REGEXP.match?(prefix) && prefix.to_i >= 0 && prefix.to_i <= 128
      end

      def self.ip(ip)
        return unless cidr = CIDRv4_REGEXP.match(ip)

        cidr[1]
      end

      def self.ip6(ip)
        return unless cidr = CIDRv6_REGEXP.match(ip)

        cidr[1]
      end

      def self.to_cidr(ip, prefix = nil)
        return nil unless ip?(ip) && (!prefix || cidr_prefix?(prefix))

        cidr = "#{ip}"
        cidr += "/#{prefix}" if cidr_prefix?(prefix)
        cidr
      end

      def self.to_cidr6(ip, prefix = nil)
        return nil unless ip6?(ip) && (!prefix || cidr6_prefix?(prefix))

        cidr = "#{ip}"
        cidr += "/#{prefix}" if cidr6_prefix?(prefix)
        cidr
      end
    end
  end
end
