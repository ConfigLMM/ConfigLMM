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
    # module Cpu mixins
    module CpuHelper
      CPU_REGEXP = /(\bcputype=)?(?<cputype>[\w-]+),?(\bflags=)?(?<flags>[[+-][\w-]+;?]*)/
      FLAGS = { spectre: 'spec-ctrl', pcid: 'pcid', ssbd: 'ssbd', ibpb: 'ibpb', virt_ssbd: 'virt-ssbd',
                amd_ssbd: 'amd-ssbd', amd_no_ssb: 'amd-no-ssb', md_clear: 'md-clear', pdpe1gb: 'pdpe1gb', hv_tlbflush: 'hv-tlbflush', aes: 'aes', hv_evmcs: 'hv-evmcs' }
      def self.flags
        FLAGS
      end

      def self.extract(cpu, name)
        captures_h = cpu ? CPU_REGEXP.match(cpu.to_s) : { cputype: '', flags: '' }
        captures_h[name]
      end

      def self.extract_cputype(cpu)
        extract(cpu, :cputype)
      end

      def self.extract_flags(cpu)
        extract(cpu, :flags)
      end

      def self.flag_value(cpu, flag_key)
        flag_value = '0'
        raw_values = extract_flags(cpu).split(';').select { |flag| ['+' + flag_key, '-' + flag_key].include?(flag) }
        unless raw_values.empty?
          flag_value = if raw_values[0].start_with?('+')
                         '+1'
                       else
                         raw_values[0].start_with?('-') ? '-1' : '0'
                       end
        end
        flag_value
      end

      def self.hash_has_no_default_flag?(cpu_h, flag_name)
        cpu_h.key?(flag_name) && ['-1', '+1'].include?(cpu_h[flag_name])
      end

      def self.hash_flag(cpu_h, flag_name)
        flag = ''
        if cpu_h.key?(flag_name)
          flag = '+' if cpu_h[flag_name] == '+1'
          flag = '-' if cpu_h[flag_name] == '-1'
        end
        flag
      end

      def self.flatten(cpu_h)
        return '' unless cpu_h['cpu_type']

        cpu_type = "cputype=#{cpu_h['cpu_type']}"
        num_flags = 0
        FLAGS.each_key { |flag_key| num_flags += 1 if hash_has_no_default_flag?(cpu_h, flag_key.to_s) }
        cpu_type += ',flags=' if num_flags > 0
        flags_with_no_default_value = FLAGS.select do |flag_key, _flag_value|
          hash_has_no_default_flag?(cpu_h, flag_key.to_s)
        end
        flags_with_no_default_value.each_with_index do |(flag_key, flag_value), index|
          cpu_type += hash_flag(cpu_h, flag_key.to_s) + flag_value if hash_has_no_default_flag?(cpu_h, flag_key.to_s)
          cpu_type += ';' if num_flags > index + 1
        end
        cpu_type
      end
    end
  end
end
