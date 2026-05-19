# Identity

This document shows you the identity service (or user management) available with fog-proxmox.

Proxmox supports many authentication sources (PAM, LDAP, Active Directory) and an authorization management (ACL, privileges).

You can see more details in [Proxmox user management wiki page](https://pve.proxmox.com/wiki/User_Management)

## Starting irb console

```ruby
irb
```

```ruby
require 'fog/proxmox'
```

## Create identity service

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
	proxmox_userid: 'your_user@your_realm', 
	proxmox_tokenid: 'his_tokenid',
	proxmox_token: 'his_token',
	connection_options: { ... }
)      
```

[connection_options](connection_parameters.md) are also available and optional.

## Fog Abstractions

Fog provides both a **model** and **request** abstraction. The request abstraction provides the most efficient interface and the model abstraction wraps the request abstraction to provide a convenient `ActiveModel` like interface.

### Request Layer

The request abstraction maps directly to the [Proxmox VE API](https://pve.proxmox.com/wiki/Proxmox_VE_API). It provides an interface to the Proxmox Identity service.

To see a list of requests supported by the identity service:

```ruby
identity.requests
```

To learn more about Identity request methods refer to source files.

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
		<td>update</td>
		<td>Updates object.<br>
		Note: not all objects support updating object.</td>
	</tr>
	<tr>
		<td>destroy</td>
		<td>
			Destroys object.<br>
			Note: this is a non-blocking call and object deletion might not be instantaneous.
		</td>
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
</table>

The remainder of this document details the model abstraction.

#### Users management

List all users:

```ruby
identity.users.all
```

This returns a collection of `Fog::Proxmox::Identity::User` models:

Create a user:

```ruby
identity.users.create({
    userid: 'bobsinclar@pve',
    password: 'bobsinclar1',
    firstname: 'Bob',
    lastname: 'Sinclar',
    email: 'bobsinclar@proxmox.com'
})
```

Get a user:

```ruby
user = identity.users.find_by_id 'bobsinclar@pve'
```

Change his password:

```ruby
user.password = 'bobsinclar2'
user.change_password
```

Add groups to user:

```ruby
user.groups = %w[group1 group2]
user.update
```

Delete user:

```ruby
user.destroy
```

#### Groups management

Proxmox supports permissions management by group.

Proxmox recommends to manage permissions by group instead of by user.

List all groups:

```ruby
identity.groups.all
```

This returns a collection of `Fog::Proxmox::Identity::Group` models:

Create a group:

```ruby
identity.groups.create({
    groupid: 'group1'
})
```

Get a group:

```ruby
group = identity.groups.find_by_id 'group1'
```

Add a comment:

```ruby
group.comment = 'Group 1'
group.update
```

Delete group:

```ruby
group.destroy
```

#### Domains management

Proxmox supports 4 domains or realms (sources of authentication): PAM, PVE, LDAP and Active Directory.

Proxmox server has two default domains: PAM and PVE.

List all domains:

```ruby
identity.domains.all
```

This returns a collection of `Fog::Proxmox::Identity::Domain` models:

Create a LDAP domain:

```ruby
identity.domains.create({
        realm: 'LDAP',
        type: 'ldap',
        base_dn: 'ou=People,dc=ldap-test,dc=com',
        user_attr: 'LDAP',
        server1: 'localhost',
        port: 389,
        default: 0,
        secure: 0
      })
```

Get a domain:

```ruby
ldap = identity.domains.find_by_id 'LDAP'
```

Add a comment and a two factor authentication (OATH) to LDAP realm:

```ruby
ldap.type.comment = 'Test domain LDAP'
ldap.type.tfa = 'type=oath,step=30,digits=8'
ldap.update
```

Delete domain:

```ruby
ldap.destroy
```

#### Roles management

Proxmox supports roles management to give permissions to group of users.

Proxmox server has several defaults roles already created. See [Proxmox user management wiki page](https://pve.proxmox.com/wiki/User_Management)

List all roles:

```ruby
identity.roles.all
```

This returns a collection of `Fog::Proxmox::Identity::Role` models:

Create a new role:

```ruby
identity.roles.create({ roleid: 'PVETestAuditor' })
```

Get the role:

```ruby
role = identity.groups.find_by_id 'PVETestAuditor'
```

Add privileges to this new role:

```ruby
role.privs = 'Datastore.Audit Sys.Audit VM.Audit'
role.update
```

List of all available privileges can be seen at [Proxmox user management wiki page](https://pve.proxmox.com/wiki/User_Management)

Delete role:

```ruby
role.destroy
```

#### Permissions management

Proxmox supports permissions management. Access permissions are assigned to objects, such as a virtual machines, storages or pools of resources. It uses path to identify these objects. Path is the same as REST API path.

See more details in [Proxmox user management wiki page](https://pve.proxmox.com/wiki/User_Management)

List all permissions:

```ruby
identity.permissions.all
```

This returns a collection of `Fog::Proxmox::Identity::Permission` models:

Add a new permission (manage users) to a user:

```ruby
identity.permissions.add({
    path: '/access/users',
    roles: 'PVEUserAdmin',
    users: 'bobsinclar@pve'
})
```

Add a new permission (manage users) to a group of users:

```ruby
identity.permissions.add({
    path: '/access/users',
    roles: 'PVEUserAdmin',
    groups: 'group1'
})
```

Remove a permission to a user:

```ruby
identity.permissions.remove({
    path: '/access/users',
    roles: 'PVEUserAdmin',
    users: 'bobsinclar@pve'
})
```

User permissions:


```ruby
bob = identity.users.get 'bobsinclar@pve'
bob.permissions
```

#### Pools management

Proxmox supports pools management of VMs or storages. It eases managing permissions on these.

Create a pool:

```ruby
identity.pools.create { poolid: 'pool1' }
```

Get a pool:

```ruby
pool1 = identity.pools.find_by_id 'pool1'
```

Add comment, server 100 and storage local-lvm to the pool:

```ruby
pool1.comment = 'Pool 1'
pool1.update
pool1.add_server 100
pool1.add_storage 'local-lvm '
```

Get all pools:

```ruby
identity.pools.all
```

Delete pool:

```ruby
# you need to remove all members before deleting pool
pool1.remove_server 100
pool1.remove_storage 'local-lvm '
pool1.destroy
```

### Examples

More examples can be seen at [examples/identity.rb](examples/identity.rb) or [spec/identity_spec.rb](spec/identity_spec.rb).