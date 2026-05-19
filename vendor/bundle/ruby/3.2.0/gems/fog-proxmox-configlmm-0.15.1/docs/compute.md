# Compute

This document shows you the compute service available with fog-proxmox.

Proxmox supports both virtual machines (QEMU/KVM) and containers (LXC) management.

You can see more details in [Proxmox VM management wiki page](https://pve.proxmox.com/wiki/Qemu/KVM_Virtual_Machines) and [Proxmox containers management wiki page](https://pve.proxmox.com/wiki/Linux_Container).

## Starting irb console

```ruby
irb
```

```ruby
require 'fog/proxmox'
```

## Create compute service

with access ticket:

```ruby
identity = Fog::Proxmox::Identity.new(
	proxmox_url: 'https://localhost:8006/api2/json', 
	proxmox_auth_method: 'access_ticket', 
	proxmox_username: 'your_user@your_realm', 
	proxmox_password: 'his_password',
	connection_options: { ... }
)      
```

with API user token:

```ruby
identity = Fog::Proxmox::Identity.new(
	proxmox_url: 'https://localhost:8006/api2/json', 
	proxmox_auth_method: 'user_token', 
	proxmox_userid: 'your_user', 
	proxmox_tokenid: 'his_tokenid',
	proxmox_token: 'his_token',
	connection_options: { ... }
)      
```

[connection_options](connection_parameters.md) are also available and optional.

## Fog Abstractions

Fog provides both a **model** and **request** abstraction. The request abstraction provides the most efficient interface and the model abstraction wraps the request abstraction to provide a convenient `ActiveModel` like interface.

### Request Layer

The request abstraction maps directly to the [Proxmox VE API](https://pve.proxmox.com/wiki/Proxmox_VE_API). It provides an interface to the Proxmox Compute service.

To see a list of requests supported by the service:

```ruby
compute.requests
```

To learn more about Compute request methods refer to source files.

To learn more about Excon refer to [Excon GitHub repo](https://github.com/geemus/excon).

### Model Layer

Fog models behave in a manner similar to `ActiveModel`. Models will generally respond to `create`, `save`,  `persisted?`, `destroy`, `reload` and `attributes` methods. Additionally, fog will automatically create attribute accessors.

Here is a summary of common model methods:

<table>
	<tr>
		<th>Method</th>
		<th>Description</th>
	</tr>
	<tr>
		<td>create</td>
		<td>
			Accepts hash of attributes and creates object.<br>
			Note: creation is a non-blocking call and you will be required to wait for a valid state before using resulting object.
		</td>
	</tr>
	<tr>
		<td>save</td>
		<td>Saves object.<br>
		Note: not all objects support updating object.</td>
	</tr>
	<tr>
		<td>persisted?</td>
		<td>Returns true if the object has been persisted.</td>
	</tr>
	<tr>
		<td>destroy</td>
		<td>
			Destroys object.<br>
			Note: this is a non-blocking call and object deletion might not be instantaneous.
		</td>
	<tr>
		<td>reload</td>
		<td>Updates object with latest state from service.</td>
	<tr>
		<td>ready?</td>
		<td>Returns true if object is in a ready state and able to perform actions. This method will raise an exception if object is in an error state.</td>
	</tr>
	<tr>
		<td>attributes</td>
		<td>Returns a hash containing the list of model attributes and values.</td>
	</tr>
		<td>identity</td>
		<td>
			Returns the identity of the object.<br>
			Note: This might not always be equal to object.id.
		</td>
	</tr>
	<tr>
		<td>wait_for</td>
		<td>This method periodically reloads model and then yields to specified block until block returns true or a timeout occurs.</td>
	</tr>
</table>

The remainder of this document details the model abstraction.

#### Nodes management

Proxmox supports cluster management. Each hyperviser in the cluster is called a node.
Proxmox installs a default node in the cluster called `pve`.

List all nodes:

```ruby
service.nodes.all
```

This returns a collection of `Fog::Proxmox::Compute::Node` models:

Get a node:

```ruby
node = service.nodes.find_by_id 'pve'
```

Get statistics (default is data):

```ruby
node.statistics
```

Get statistics (image png):

```ruby
node.statistics('rrd', { timeframe: 'hour', ds: 'cpu,memused', cf: 'AVERAGE' })
```

#### Servers management

Proxmox supports servers management. Servers are also called virtual machines (VM).

VM are QEMU/KVM managed. They are attached to a node.

More details in [Proxmox VM management wiki page](https://pve.proxmox.com/wiki/Qemu/KVM_Virtual_Machines)

You need to specify a node before managing VM. Fog-proxmox enables it by managing VM from a node.

List all servers:

```ruby
node.servers.all
```

This returns a collection of `Fog::Proxmox::Identity::Server` models.

Before creating a server you can get the next available server id (integer >= 100) in the cluster:

```ruby
nextid = node.servers.next_id
```

You can also verify that an id is free or valid:

```ruby
node.servers.id_valid? nextid
```

Now that you have a valid id, you can create a server in this node:

```ruby
node.servers.create({ vmid: nextid })
```

Get this server:

```ruby
server = node.servers.get nextid
```

Add options: boot at startup, OS type (linux 4.x), french keyboard, no hardware KVM:

```ruby
server.update({ onboot: 1, keyboard: 'fr', ostype: 'l26', kvm: 0 })
```

Add a cdrom volume:

```ruby
server.update({ ide2: 'none,media=cdrom' })
```

Add a network interface controller (nic):

```ruby
server.update({ net0: 'virtio,bridge=vmbr0' })
```

Get mac adresses generated by Proxmox:

```ruby
server.config.mac_adresses
```

This returns an array of strings.

Get all server configuration:

```ruby
server.config
```

This returns a `Fog::Proxmox::Compute::ServerConfig` model:

```ruby
 <Fog::Proxmox::Compute::ServerConfig
    smbios1: "uuid=ba2da6bd-0c92-4cfe-8f70-d22cc5b5bba2",
	numa:	0,
	digest:	"348fdc21536f23a29dfb9b3120faa124aaeec742",
	ostype:	"l26",
	cores:	1,
	virtio0: "local-lvm:vm-100-disk-1,size=1G",
	bootdisk: "virtio0",
	scsihw:	"virtio-scsi-pci",
	sockets: 1,
	net0: "virtio=8E:BF:3E:E7:17:0D,bridge=vmbr0",
	memory:	512,
	name: "test",
	ide2: "cdrom,media=cdrom",
	server:	<Fog::Proxmox::Compute::Server vmid: 100, ...>
  >
```

Get nics config:

```ruby
nics = server.config.interfaces
```

This returns a hash:

```ruby
nics = {net0: 'virtio=8E:BF:3E:E7:17:0D,bridge=vmbr0'}
```

Get IDE,SATA,SCSI or VirtIO controllers config:

```ruby
disks = server.config.disks
```

This returns a hash:

```ruby
disks = {ide2: 'cdrom,media=cdrom', virtio0: "local-lvm:vm-100-disk-1,size=1G", sata0: "local-lvm:vm-100-disk-2,size=1G"}
```

##### Console

VNC, SPICE and terminal consoles are availables.

Server needs to be running and a VGA display configured.

Default VGA set to `std` implies vnc console:

```ruby
vnc_console = server.start_console(websocket: 1)
server.connect_vnc(vnc_console)
```

returns a vnc session hash,

and set to `qxl` implies spice console:

```ruby
spice_console = server.start_console(proxy: 'localhost')
```

returns a spice session hash,


and set to `serial0` implies terminal console:

```ruby
term_console = server.start_console
```

returns a term session hash.

##### Volumes server management

Before attaching a hdd volume, you can first fetch available storages that could have images in this node:

```ruby
storages = node.storages.list_by_content_type 'images'
storage = storages[0] # local-lvm
```

Four types of storage controllers emulated by Qemu are available:

* **IDE**: ide[n], n in [0..3]
* **SATA**: sata[n], n in [0..5]
* **SCSI**: scsi[n], n in [0..13]
* **VirtIO Block**: virtio[n], n in [0..15]

The hdd id is the type controller appended with an integer (n).

More details on complete configuration options can be find in [Proxmox VE API](https://pve.proxmox.com/wiki/Proxmox_VE_API).

Then attach a hdd from this storage:

```ruby
disk = { id: 'virtio0', storage: storage.storage, size: '1' } # virtualIO block with 1Gb
options = { backup: 0, replicate: 0 } # nor backup, neither replication
server.attach(disk, options)
```

Resize a disk:

```ruby
server.extend('virtio0','+1G')
```

Move a disk

```ruby
server.move('virtio0','local')
```

Detach a disk

```ruby
server.detach 'virtio0'
```

Actions on your server:

```ruby
server.action('start') # start your server
server.wait_for { server.ready? } # wait until it is running
server.ready? # you can check if it is ready (i.e. running)
```

```ruby
server.action('suspend') # pause your server
server.wait_for { server.qmpstatus == 'paused' } # wait until it is paused
```

```ruby
server.action('resume') # resume your server
server.wait_for { server.ready? } # wait until it is running
```

```ruby
server.action('stop') # stop your server
server.wait_for { server.status == 'stopped' } # wait until it is stopped
```

Fetch server disk_images:

```ruby
disk_images = server.disk_images
```

This returns an array of `Fog::Proxmox::Compute::Volume` instances.

Delete server:

```ruby
server.destroy
```

##### Backup and restore server

You can backup all node's guests or just one guest.

You need first to get a node or a server to manage its backups:

```ruby
node = compute.nodes.get 'pve'
server = node.servers.get vmid
```

Then you can backup one server:

```ruby
options = { compress: 'lzo'}
server.backup options
```

or backup all servers on a node:

```ruby
node.backup options
```

You can restore a server from a backup.
Backups are volumes which content type is `backup` and owned by a server.

You first fetch the backup volumes of this server:

```ruby
volumes = server.backups
```

This returns an array of `Fog::Proxmox::Compute::Volume` instances.

Then you choose one:

```ruby
backup = volumes[0] # local:backup/vzdump-qemu-100-2018_05_15-15_18_31.vma.lzo
```

This returns a `Fog::Proxmox::Compute::Volume` instance:

```ruby
 <Fog::Proxmox::Compute::Volume
    volid="local:backup/vzdump-qemu-100-2018_05_15-15_18_31.vma.lzo",
    content="backup",
    size=376,
    format="vma.lzo",
    node=nil,
    storage=nil,
    vmid="100"
  >
```

Then you can restore it:

```ruby
options = { compress: 'lzo'}
server.restore backup
```

You can delete it:

```ruby
backup.delete
```

More details on complete backup `options` configuration hash can be find in [Backup and restore wiki page](https://pve.proxmox.com/wiki/Backup_and_Restore).

##### Snapshots server management

You need first to get a server to manage its snapshots:

```ruby
server = node.servers.get vmid
```

Then you can create a snapshot on it:

```ruby
snapname = 'snapshot1' # you define its id
server.snapshots.create snapname
```

Get a snapshot:

```ruby
snapshot = server.snapshots.get snapname
```

Add description:

```ruby
snapshot.description = 'Snapshot 1'
snapshot.update
```

Rollback server to this snapshot:

```ruby
snapshot.rollback
```

Delete snapshot:

```ruby
snapshot.destroy
```

##### Clones server management

Proxmox supports cloning servers. It creates a new VM as a copy of the server.

You need first to get a server to manage its clones and a valid new VM id:

```ruby
server = node.servers.get vmid
newid = node.servers.next_id
```

Then you can clone it:

```ruby
server.clone(newid)
```

It creates a new server which id is newid. So you can manage it as a server.

Destroy the clone:

```ruby
clone = node.servers.get newid
clone.destroy
```

#### Containers management

Proxmox supports Linux containers management.

Containers are LXC managed. They are attached to a node.

More details in [Proxmox Linux Containers management wiki page](https://pve.proxmox.com/wiki/Linux_Container)

You need to specify a node before managing Containers. Fog-proxmox enables it by managing Containers from a node.

List all containers:

```ruby
node.containers.all
```

This returns a collection of `Fog::Proxmox::Identity::Container` models which are inherited from `Fog::Proxmox::Identity::Server` because they have many common features.

Before creating a container you can get the next available container id (integer >= 100) in the cluster:

```ruby
nextid = node.containers.next_id
```

You can also verify that an id is free or valid:

```ruby
node.containers.id_valid? nextid
```

Now that you have a valid id, you can create a container in this node.
Before creating the container, you need to have an available template uploaded into the cluster.
You can define the rootfs volume (1G), a root password and a SSH public key.

```ruby
ostemplate = 'local:vztmpl/alpine-3.7-default_20171211_amd64.tar.xz'
container_hash = { vmid: vmid, storage: 'local-lvm',
	ostemplate: ostemplate, password: 'proxmox01', 
	rootfs: 'local-lvm:1' }
node.containers.create container_hash
```

Get this container:

```ruby
container = node.containers.get nextid
```

Add options: boot at startup, OS type (alpine):

```ruby
container.update({ onboot: 1, ostype: 'alpine' })
```

Add a network interface controller (nic):

```ruby
container.update({ net0: 'bridge=vmbr0,name=eth0,ip=dhcp,ip6=dhcp' })
```

Fetch all nics:

```ruby
nics = container.config.nics
```

This returns a hash:

```ruby
nics = { net0: 'bridge=vmbr0,name=eth0,ip=dhcp,ip6=dhcp' }
```

Get mac adresses generated by Proxmox:

```ruby
container.config.mac_adresses
```

This returns an array of strings.

Get container configuration:

```ruby
container.config
```

This returns a `Fog::Proxmox::Compute::ContainerConfig` model:

```ruby
 <Fog::Proxmox::Compute::ContainerConfig
    memory:	512,
	net0:	"name=eth0,bridge=vmbr0,hwaddr=BE:3C:A9:3F:4E:39,ip=dhcp,ip6=dhcp,type=veth",
	swap:	512,
	cores:	1,
	rootfs:	"local-lvm:vm-100-disk-1,size=1G",
	hostname: "CT100",
	digest:	"e5131befed2f6ff8e11d598c4d8bb6016d5c0901",
	ostype:	"alpine",
	arch:	"amd64"
	container:	<Fog::Proxmox::Compute::Container vmid: 100, ...>
  >
```

##### Volumes container management

Before attaching a volume, you can first fetch available storages that could have images in this node:

```ruby
storages = node.storages.list_by_content_type 'images'
storage = storages[0] # local-lvm
```

A default and minimum volume is called `rootfs`.
Additional volumes could be attached to a container and are called mount points:

* **Mount points**: mp[n], n in [0..9]

The mount points id is `mp` appended with an integer (n).

More details on complete configuration options can be find in [Proxmox VE Linux Container](https://pve.proxmox.com/wiki/Linux_Container).

Then attach a volume from this storage:

```ruby
mp0 = { id: 'mp0', storage: storage.storage, size: '1' }
options = { mp: '/opt/app', backup: 0, replicate: 0, quota: 1 }
container.attach(mp0, options)
```

Extend a volume:

```ruby
container.extend('rootfs', '+5M') # add 5Mb to rootfs volume
```

Move a volume:

```ruby
container.move('rootfs', 'local-lvm', delete: 1) # move rootfs and delete original
```

Detach a volume

```ruby
container.detach('mp0') # detach
container.detach('unused0') # remove
```

Actions on your container:

```ruby
container.action('start') # start your container
container.wait_for { container.ready? } # wait until it is running
container.ready? # you can check if it is ready (i.e. running)
```

```ruby
container.action('stop') # stop your container
container.wait_for { container.status == 'stopped' } # wait until it is stopped
```

Resume, suspend actions are not implemented.

Fetch container mount points:

```ruby
mount_points = container.config.mount_points
```

This returns a hash:

```ruby
mount_points = { mp0: "local-lvm:vm-100-disk-2,mp=/opt/app,size=1G" }
```

Delete container:

```ruby
container.destroy
```

##### Backup and restore container

You can backup all node's guests or just one guest.

You need first to get a node or a container to manage its backups:

```ruby
node = compute.nodes.get 'pve'
container = node.containers.get vmid
```

Then you can backup one container:

```ruby
options = { compress: 'lzo'}
container.backup options
```

or backup all containers and servers on a node:

```ruby
node.backup options
```

You can restore a container from a backup.
Backups are volumes which content type is `backup` and owned by a container.

You first fetch the backup volumes of this container:

```ruby
volumes = container.backups
```

This returns an array of `Fog::Proxmox::Compute::Volume` instances.

Then you choose one:

```ruby
backup = volumes[0] # local:backup/vzdump-qemu-100-2018_05_15-15_18_31.vma.lzo
```

This returns a `Fog::Proxmox::Compute::Volume` instance:

```ruby
 <Fog::Proxmox::Compute::Volume
    volid="local:backup/vzdump-qemu-100-2018_05_15-15_18_31.vma.lzo",
    content="backup",
    size=376,
    format="vma.lzo",
    node=nil,
    storage=nil,
    vmid="100"
  >
```

Then you can restore it:

```ruby
options = { compress: 'lzo'}
container.restore backup
```

You can delete it:

```ruby
backup.delete
```

More details on complete backup `options` configuration hash can be find in [Backup and restore wiki page](https://pve.proxmox.com/wiki/Backup_and_Restore).

##### Snapshots container management

You need first to get a container to manage its snapshots:

```ruby
container = node.containers.get vmid
```

Then you can create a snapshot on it:

```ruby
snapname = 'snapshot1' # you define its id
container.snapshots.create snapname
```

Get a snapshot:

```ruby
snapshot = container.snapshots.get snapname
```

Add description:

```ruby
snapshot.description = 'Snapshot 1'
snapshot.update
```

Rollback container to this snapshot:

```ruby
snapshot.rollback
```

Delete snapshot:

```ruby
snapshot.destroy
```

##### Clones container management

Proxmox supports cloning containers. It creates a new container as a copy of the original container.

You need first to get a container to manage its clones and a valid new container id:

```ruby
container = node.containers.get vmid
newid = node.containers.next_id
```

Then you can clone it:

```ruby
container.clone(newid)
```

It creates a new container which id is newid. So you can manage it as a container.

Destroy the clone:

```ruby
clone = node.containers.get newid
clone.destroy
```

#### Tasks management

Proxmox supports tasks management. A task enables to follow all asynchronous actions made in a node: VM creation, start, etc. Indeed, some of these tasks could be long to execute.

You need first to get a node to manage its tasks:

```ruby
node = compute.nodes.find_by_id 'pve'
```

Search tasks (limit results to 1):

```ruby
tasks = node.tasks.search { limit: 1 }
```

Get a task by its id. This id can be retrieved as a result of an action:

```ruby
taskid = snapshot.destroy
task = node.tasks.find_by_id taskid
task.wait_for { succeeded? }
```

Stop a task:

```ruby
task.stop
```

### Examples

More examples can be seen at [examples/compute.rb](examples/compute.rb) or [spec/compute_spec.rb](spec/compute_spec.rb).