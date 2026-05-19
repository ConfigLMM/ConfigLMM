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

# Create service identity with access ticket
identity = Fog::Proxmox::Identity.new(
  proxmox_url: proxmox_url,
  proxmox_auth_method: 'access_ticket',
  proxmox_username: proxmox_username,
  proxmox_password: proxmox_password
)

# or with a user token
identity = Fog::Proxmox::Identity.new(
	proxmox_url: proxmox_url, 
	proxmox_auth_method: 'user_token', 
	proxmox_userid: proxmox_username, 
	proxmox_tokenid: 'root1',
	proxmox_token: 'ed6402b4-641d-46b1-b20a-33ba9ba12f54'
)      

# Get proxmox version
identity.read_version

# Create a new user
bob_hash = {
  userid: 'bobsinclar@proxmox',
  password: 'bobsinclar1',
  firstname: 'Bob',
  lastname: 'Sinclar',
  email: 'bobsinclar@proxmox.com'
}

identity.users.create(bob_hash)

# Get a user by id
bob = identity.users.get 'bobsinclar@proxmox'

# List all users
identity.users.all

# List user by user
identity.users.each do |user|
  # user ...
end

# Update user
bob.comment = 'novelist'
# add groups
bob.groups = %w[group1]
bob.update

# List user permissions
bob.permissions

# Delete user
bob.destroy

# Create groups
group_hash = { groupid: 'group1' }
identity.domains.create(group_hash)

# Get one group by id
group1 = identity.groups.get 'group1'

# Update group
group1.comment 'Group 1'
group1.update

# List all groups
identity.groups.all

# List group by group
identity.groups.each do |group|
  # group ...
end

# Delete group
group1.destroy

# Create roles
role_hash = { roleid: 'role1' }
identity.roles.create(role_hash)

# Get one role by id
role1 = identity.roles.get 'role1'

# Update role
role1.comment 'Role 1'
role1.update

# List all roles
identity.roles.all

# List role by role
identity.roles.each do |role|
  # role ...
end

# Delete role
role1.destroy

# Create a new domain (authentication server)
# Three types: PAM, PROXMOX, LDAP and ActiveDirectory
# PAM and PROXMOX already exist by default
# LDAP sample:
ldap_hash = {
  realm: 'LDAP',
  type: 'ldap',
  base_dn: 'ou=People,dc=ldap-test,dc=com',
  user_attr: 'LDAP',
  server1: 'localhost',
  port: 389,
  default: 0,
  secure: 0
}
# ActiveDirectory sample:
# ad_hash = {
#   realm: 'ActiveDirectory',
#   type: 'ad',
#   domain: 'proxmox.com',
#   server1: 'localhost',
#   port: 389,
#   default: 0,
#   secure: 0
# }

identity.domains.create(ldap_hash)

# List domains
identity.domains.each do |domain|
  # domain ...
end

# Find domain by id
ldap = identity.domains.get ldap_hash[:realm]

# Update domain
ldap.type.comment = 'Test domain LDAP'
# Two types of Two Factors Authentication (TFA): oath and yubico
ldap.type.tfa = 'type=oath,step=30,digits=8'
# ad.type.tfa = 'type=yubico,id=1,key=2,url=http://localhost'
ldap.update

# Delete domain
ldap.destroy

# Add a user permission
permission_hash = {
  type: 'user'
  path: '/access',
  roleid: 'PROXMOXUserAdmin',
  ugid: bob_hash[:userid]
}
# Add a group permission
# permission_hash = {
#   type: 'group'
#   path: '/access',
#   roleid: 'PROXMOXUserAdmin',
#   ugid: 'group1'
# }
permission = identity.permissions.create(permission_hash)

# List all permissions
identity.permissions.all

# List permission by permission
identity.permissions.each do |permission|
  # permission ...
end

# Remove permission
permission = identity.get(permission_hash)
permission.destroy
