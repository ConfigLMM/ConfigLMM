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

module Fog
  module Proxmox
    class Compute
      # class Real rollback_snapshot request
      class Real
        def rollback_snapshot(path_params)
          node = path_params[:node]
          type = path_params[:type]
          vmid = path_params[:vmid]
          snapname = path_params[:snapname]
          request(
            expects: [200],
            method: 'POST',
            path: "nodes/#{node}/#{type}/#{vmid}/snapshot/#{snapname}/rollback"
          )
        end
      end

      # class Mock rollback_snapshot request
      class Mock
        def rollback_snapshot(_path_params)
          'UPID:proxmox:00002EBF:646E2BF3:5E1C7E39:qmrollback:100:root@pam:'
        end
      end
    end
  end
end
