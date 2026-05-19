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
      # class Real delete_snapshot request
      class Real
        def delete_snapshot(path_params, query_params)
          node = path_params[:node]
          type = path_params[:type]
          vmid = path_params[:vmid]
          snapname = path_params[:snapname]
          request(
            expects: [200],
            method: 'DELETE',
            path: "nodes/#{node}/#{type}/#{vmid}/snapshot/#{snapname}",
            query: URI.encode_www_form(query_params)
          )
        end
      end

      # class Mock delete_snapshot request
      class Mock
        def delete_snapshot(_path_params, _query_params)
          'UPID:proxmox:00002CC5:646E24B1:5E1C7E26:qmdelsnapshot:100:root@pam:'
        end
      end
    end
  end
end
