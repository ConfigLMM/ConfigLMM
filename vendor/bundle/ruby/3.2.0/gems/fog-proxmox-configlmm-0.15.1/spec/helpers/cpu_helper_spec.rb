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
require 'fog/proxmox/helpers/cpu_helper'

describe Fog::Proxmox::CpuHelper do
  let(:cpu) do
    'cputype=Skylake-Client,flags=+spec-ctrl;+pcid;+ssbd;-aes'
  end
  let(:cpu_nocputype) do
    'kvm64,flags=+spec-ctrl;+pcid;+ssbd'
  end
  let(:cpu_nospectre) do
    'cputype=kvm64,flags=+pcid'
  end
  let(:cpu_nopcid) do
    'cputype=kvm64,flags=+spec-ctrl'
  end
  let(:cpu_nossbd) do
    'cputype=kvm64,flags=+pcid'
  end

  describe '#extract_cputype' do
    it 'returns string' do
      result = Fog::Proxmox::CpuHelper.extract_cputype(cpu)
      assert_equal('Skylake-Client', result)
    end

    it 'returns string' do
      result = Fog::Proxmox::CpuHelper.extract_cputype(cpu_nocputype)
      assert_equal('kvm64', result)
    end
  end

  describe '#flag_value' do
    it 'returns +1' do
      result = Fog::Proxmox::CpuHelper.flag_value(cpu, 'spec-ctrl')
      assert_equal('+1', result)
    end

    it 'returns -1' do
      result = Fog::Proxmox::CpuHelper.flag_value(cpu, 'aes')
      assert_equal('-1', result)
    end

    it 'returns 0' do
      result = Fog::Proxmox::CpuHelper.flag_value(cpu, 'amd-ssbd')
      assert_equal('0', result)
    end
  end

  describe '#flatten ' do
    it 'returns cputype=kvm64,flags=+pcid;+ibpb;-hv-tlbflush' do
      result = Fog::Proxmox::CpuHelper.flatten('cpu_type' => 'kvm64', 'spectre' => '0', 'pcid' => '+1',
                                               'ssbd' => '0', 'ibpb' => '+1', 'virt_ssbd' => '0', 'amd_ssbd' => '0', 'amd_no_ssb' => '0', 'md_clear' => '0', 'pdpe1gb' => '0', 'hv_tlbflush' => '-1', 'aes' => '0', 'hv_evmcs' => '0')
      assert_equal('cputype=kvm64,flags=+pcid;+ibpb;-hv-tlbflush', result)
    end

    it "returns cputype=Skylake-Client,flags=+spec-ctrl;+pcid;+amd-no-ssbd'" do
      result = Fog::Proxmox::CpuHelper.flatten('cpu_type' => 'Skylake-Client', 'pcid' => '+1',
                                               'spectre' => '+1', 'amd_no_ssb' => '-1')
      assert_equal('cputype=Skylake-Client,flags=+spec-ctrl;+pcid;-amd-no-ssb', result)
    end
  end
end
