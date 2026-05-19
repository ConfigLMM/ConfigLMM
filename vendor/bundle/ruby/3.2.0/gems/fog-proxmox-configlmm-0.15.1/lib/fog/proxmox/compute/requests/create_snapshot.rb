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

module Fog
  module Proxmox
    class Compute
      # class Real create_snapshot request
      class Real
        def create_snapshot(path_params, body_params)
          node = path_params[:node]
          type = path_params[:type]
          vmid = path_params[:vmid]
          request(
            expects: [200],
            method: 'POST',
            path: "nodes/#{node}/#{type}/#{vmid}/snapshot",
            body: URI.encode_www_form(body_params)
          )
        end
      end

      # class Mock create_snapshot request
      class Mock
        def create_snapshot(_path_params, _body_params)
          'UPID:proxmox:00003E13:6F21770F:5E37E2D0:qmsnapshot:100:root@pam:'
        end
      end
    end
  end
end
