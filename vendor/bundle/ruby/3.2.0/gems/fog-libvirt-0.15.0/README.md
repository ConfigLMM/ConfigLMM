# Fog::Libvirt

fog-libvirt is a libvirt provider for [fog](https://github.com/fog/fog).

[![Build Status](https://github.com/fog/fog-libvirt/actions/workflows/ruby.yml/badge.svg)](https://github.com/fog/fog-libvirt/actions/workflows/ruby.yml)
[![Dependency Status](https://gemnasium.com/fog/fog.png)](https://gemnasium.com/fog/fog-libvirt)
[![Code Climate](https://codeclimate.com/github/fog/fog.png)](https://codeclimate.com/github/fog/fog-libvirt)
[![Gem Version](https://fury-badge.herokuapp.com/rb/fog.png)](http://badge.fury.io/rb/fog-libvirt)
[![Gittip](http://img.shields.io/gittip/geemus.png)](https://www.gittip.com/geemus/)

## Installation

fog-libvirt can be used as a module for fog or installed separately as:

```
$ sudo gem install fog-libvirt
```

## Usage

Example REPL session:

```
>> require "fog/libvirt"
=> true
>> compute = Fog::Compute.new(provider: :libvirt, libvirt_uri: "qemu:///session")
=> #<Fog::Libvirt::Compute::Real:46980 @uri=#<Fog::Libvirt::Util::URI:0x0000000002def920 @parsed_uri=#<URI::Generic qemu:/session>, @uri="qemu:///session"...
>> server = compute.servers.create(name: "test")
=>
  <Fog::Libvirt::Compute::Server
    id="bbb663e4-723b-4165-bc29-c77b54b12bca",
    cpus=1,
    cputime=0,
    os_type="hvm",
    memory_size=262144,
    max_memory_size=262144,
    name="test",
    arch="x86_64",
    persistent=true,
    domain_type="kvm",
    uuid="bbb663e4-723b-4165-bc29-c77b54b12bca",
    autostart=false,
    nics=[    <Fog::Libvirt::Compute::Nic
      mac="52:54:00:d1:18:23",
      id=nil,
      type="network",
      network="default",
      bridge=nil,
      model="virtio"
    >],
    volumes=[    <Fog::Libvirt::Compute::Volume
      id=nil,
      pool_name="1Download",
      key=nil,
      name="test.img",
      path="/home/lzap/1Download/test.img",
      capacity="10G",
      allocation="1G",
      owner=nil,
      group=nil,
      format_type="raw",
      backing_volume=nil
    >],
    active=false,
    boot_order=["hd", "cdrom", "network"],
    display={:type=>"vnc", :port=>"-1", :listen=>"127.0.0.1"},
    cpu={},
    hugepages=false,
    guest_agent=true,
    virtio_rng={},
    state="shutoff"
  >
```

See [README.md](https://github.com/fog/fog-libvirt/blob/master/lib/fog/libvirt/models/compute/README.md).

## Contributing

Please refer to [CONTRIBUTING.md](https://github.com/fog/fog/blob/master/CONTRIBUTING.md).

## License

Please refer to [LICENSE.md](https://github.com/fog/fog-libvirt/blob/master/LICENSE.md).
