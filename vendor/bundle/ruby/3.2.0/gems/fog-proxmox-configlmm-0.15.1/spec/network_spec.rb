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

require 'spec_helper'
require_relative './proxmox_vcr'

describe Fog::Proxmox::Network do
  before :all do
    @proxmox_vcr = ProxmoxVCR.new(
      vcr_directory: 'spec/fixtures/proxmox/network',
      service_class: Fog::Proxmox::Network
    )
    @service = @proxmox_vcr.service
    @proxmox_url = @proxmox_vcr.url
    @username = @proxmox_vcr.username
    @password = @proxmox_vcr.password
    @tokenid = @proxmox_vcr.tokenid
    @token = @proxmox_vcr.token
  end

  it 'CRUD networks' do
    VCR.use_cassette('networks') do
      net_hash = {
        iface: 'enp0s10',
        type: 'eth'
      }
      node = @service.nodes.all.first
      # Create 1st time
      node.networks.create(net_hash)
      # Find by id
      network = node.networks.get net_hash[:iface]
      _(network).wont_be_nil
      # Create 2nd time
      _(proc do
        node.networks.create(net_hash)
      end).must_raise Excon::Error::BadRequest
      # all networks
      networks_all = node.networks.all
      _(networks_all).wont_be_nil
      _(networks_all).wont_be_empty
      _(networks_all).must_include network
      # Update
      network.update(comments: 'test')
      node.power('reboot')
      sleep 60
      # Delete
      network.destroy
      node.power('reboot')
    end
  end
end
