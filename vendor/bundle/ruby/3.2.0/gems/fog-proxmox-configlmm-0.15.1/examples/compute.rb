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

# There are basically two modes of operation for these specs.
#
# 1. ENV[PROXMOX_URL] exists: talk to an actual Proxmox server and record HTTP
#    traffic in VCRs at "spec/debug" (credentials are read from the conventional
#    environment variables: PROXMOX_URL, PROXMOX_USERNAME, PROXMOX_PASSWORD)
# 2. otherwise (Travis, etc): use VCRs at "spec/fixtures/proxmox/#{service}"

require 'fog/proxmox'

proxmox_url = 'https://172.26.49.146:8006/api2/json'
proxmox_username = 'root@pam'
proxmox_password = 'proxmox01'

# Create service compute
compute = Fog::Proxmox::Compute.new(
  proxmox_url: proxmox_url,
  proxmox_username: proxmox_username,
  proxmox_password: proxmox_password
)

# Create pools
pool_hash = { poolid: 'pool1' }
pool1 = compute.pools.create(pool_hash)

# Get one pool by id
pool1 = compute.pools.get 'pool1'

# Update pool
pool1.comment 'pool 1'
pool1.update

# List all pools
compute.pools.all

# List pool by pool
compute.pools.each do |pool|
  # pool ...
end

# Delete pool
pool1.destroy

# Create servers

# Get node owner
node_name = 'proxmox'
node = compute.nodes.get node_name

# Get next free vmid
vmid = node.servers.next_id
server_hash = { vmid: vmid }

# Create server
node.servers.create(server_hash)

# Check already used vmid
node.servers.id_valid? vmid

# Get server
server = node.servers.get vmid

# Update config server
# Add cdrom empty
config_hash = { ide2: 'none,media=cdrom' }
server.update(config_hash)
# Attach a hdd
virtio0 = { id: 'virtio0', storage: storage.storage, size: '1' }
ide0 = { id: 'ide0', storage: storage.storage, size: '1' }
options = { backup: 0, replicate: 0 }
server.attach(virtio0, options)
server.attach(ide0, options)
# Resize disk server
server.extend('virtio0', '+1G')
# Move disk server
server.move('virtio0', 'local')
# Detach a disk
server.detach 'ide0'
# Remove it
server.detach 'unused0'
# Detach another device
server.detach 'ide2'
# Add network interface
config_hash = { net0: 'virtio,bridge=vmbr0' }
server.update(config_hash)
# Add start at boot, keyboard fr, linux 3.x os type, kvm hardware disabled (proxmox guest in virtualbox)
config_hash = { onboot: 1, keyboard: 'fr', ostype: 'l26', kvm: 0 }
server.update(config_hash)
# Get configuration model
config = server.config
# Get nics config
nics = server.config.nics
nics[:net0]
# Get hdd controllers (ide, sata, scsi or virtio) config
# All return hashes with key equals to controller id
disks = server.config.disks
ide0 = disks.get('ide0')
virtio0 = disks.get('virtio0')
# Get mac_addresses
server.config.mac_adresses
# List all servers
servers_all = node.servers.all

# Start server
server.action('start')
# Wait until task is complete
server.wait_for { ready? }
# Suspend server
server.action('suspend')
# Wait until task is complete
server.wait_for { server.qmpstatus == 'paused' }
# Resume server
server.action('resume')
# Wait until task is complete
server.wait_for { ready? }
# Stop server
server.action('stop')
# Wait until task is complete
server.wait_for { server.status == 'stopped' }

# Backup a server
server.backup(compress: 'lzo')

# Fetch a backup volume (first one)
volume = server.backups.first

# Restore it
server.restore volume

# Delete a backup
volume.destroy

# Snapshot a server
server.snapshots.create(name: 'snapshot1')

# Fetch it
snapshot = server.snapshots.get 'snapshot1'
# Fetch all
server.snapshots.all

# Update snapshot
snapshot.description 'Snapshot 1'
snapshot.update

# Delete snapshot
snapshot.destroy

# Fetch disk images
server.config.disks

# Delete server
server.destroy

# Create containers
node_name = 'proxmox'
node = compute.nodes.get node_name
ostemplate = 'local:vztmpl/alpine-3.7-default_20171211_amd64.tar.xz'
container_hash = {
  vmid: vmid,
  storage: 'local-lvm',
  ostemplate: ostemplate,
  password: 'proxmox01',
  rootfs: 'local-lvm:1'
}

# Get next free vmid
vmid = node.containers.next_id

node.containers.create(container_hash)
# Check already used vmid
valid = node.containers.id_valid? vmid

# Get container
container = node.containers.get(vmid)

# Get container config
container.config
# Update config container
# Attach an aditional mount point
mp0 = { id: 'mp0', storage: 'local-lvm', size: '1' }
options = { mp: '/opt/app', backup: 0, replicate: 0, quota: 1 }
container.attach(mp0, options)
# Resize rootfs container
container.extend('rootfs', '+1G')
# Move rootfs container and delete original
container.move('rootfs', 'local-lvm', delete: 1)
# Detach a mount point
container.detach 'mp0'
# Remove it
container.detach 'unused0'
# Add network interface
config_hash = { net0: 'bridge=vmbr0,name=eth0,ip=dhcp,ip6=dhcp' }
container.update(config_hash)
# Add start at boot, linux os type alpine
config_hash = { onboot: 1, ostype: 'alpine' }
container.update(config_hash)
# Get mac_addresses
container.mac_adresses
# Get interfaces
container.config.interfaces
# Get additional mount points
container.config.mount_points
# List all servers
containers_all = node.containers.all

# Start container
container.action('start')
# Wait until task is complete
container.wait_for { ready? }
# Stop container
container.action('stop')
# Wait until task is complete
container.wait_for { container.status == 'stopped' }

# Backup a container
container.backup(compress: 'lzo')

# Fetch a backup volume (first one)
volume = container.backups.first

# Restore it
container.restore volume

# Delete a backup
volume.destroy

# Snapshot a container
container.snapshots.create(name: 'snapshot1')

# Fetch it
snapshot = container.snapshots.get 'snapshot1'
# Fetch all
container.snapshots.all

# Update snapshot
snapshot.description 'Snapshot 1'
snapshot.update

# Delete snapshot
snapshot.destroy

# Fetch additional mount points
container.config.mount_points
# Fetch network interfaces
container.config.interfaces

# Delete container
container.destroy

# List 1 task
filters = { limit: 1 }
node = compute.nodes.get 'proxmox'
tasks = node.tasks.all(filters)
# Get task
upid = tasks[0].upid
task = node.tasks.get(upid)
# Stop task
task.stop
