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
    module Errors
      # class ServiceError
      class ServiceError < Fog::Errors::Error
        attr_reader :response_data

        def self.slurp(error)
          if error.response.body.empty?
            data = nil
            message = nil
          else
            data = Fog::JSON.decode(error.response.body)
            message = data['message']
            data1 = data.values.first
            message = data1['message'] if message.nil? && !data1.nil?
          end

          new_error = super(error, message)
          new_error.instance_variable_set(:@response_data, data)
          new_error
        end
      end

      # class ServiceUnavailable error
      class ServiceUnavailable < ServiceError; end

      # class BadRequest error
      class BadRequest < ServiceError
        attr_reader :validation_errors

        def self.slurp(error)
          new_error = super(error)
          unless new_error.response_data.nil? || new_error.response_data['badRequest'].nil?
            new_error.instance_variable_set(:@validation_errors,
                                            new_error.response_data['badRequest']['validationErrors'])
          end
          new_error
        end
      end

      # class InterfaceNotImplemented error
      class InterfaceNotImplemented < Fog::Errors::Error; end
    end
  end
end
