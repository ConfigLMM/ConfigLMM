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
require_relative './proxmox_vcr'

describe Fog::Proxmox::Identity do
  before :all do
    @proxmox_vcr = ProxmoxVCR.new(
      vcr_directory: 'spec/fixtures/proxmox/identity',
      service_class: Fog::Proxmox::Identity
    )
    @service = @proxmox_vcr.service
    @proxmox_url = @proxmox_vcr.url
    @username = @proxmox_vcr.username
    @password = @proxmox_vcr.password
    @tokenid = @proxmox_vcr.tokenid
    @token = @proxmox_vcr.token
  end

  it 'authenticates with access ticket' do
    VCR.use_cassette('auth_access_ticket') do
      Fog::Proxmox::Identity.new(proxmox_url: @proxmox_url,
                                 proxmox_auth_method: Fog::Proxmox::Auth::Token::AccessTicket::NAME, proxmox_username: @username, proxmox_password: @password)
      _(proc do
        Fog::Proxmox::Identity.new(proxmox_url: @proxmox_url,
                                   proxmox_auth_method: Fog::Proxmox::Auth::Token::AccessTicket::NAME, proxmox_username: @username, proxmox_password: 'wrong_password')
      end).must_raise Excon::Errors::Unauthorized
      _(proc do
        Fog::Proxmox::Identity.new(proxmox_url: @proxmox_url, proxmox_username: @username, proxmox_password: @password)
      end).must_raise ArgumentError
      _(proc do
        Fog::Proxmox::Identity.new(proxmox_url: @proxmox_url,
                                   proxmox_auth_method: Fog::Proxmox::Auth::Token::AccessTicket::NAME, proxmox_password: @password)
      end).must_raise Fog::Proxmox::Auth::Token::AccessTicket::URIError
      _(proc do
        Fog::Proxmox::Identity.new(proxmox_url: @proxmox_url,
                                   proxmox_auth_method: Fog::Proxmox::Auth::Token::AccessTicket::NAME, proxmox_username: @username)
      end).must_raise Fog::Proxmox::Auth::Token::AccessTicket::URIError
      _(proc do
        Fog::Proxmox::Identity.new(proxmox_auth_method: Fog::Proxmox::Auth::Token::AccessTicket::NAME,
                                   proxmox_username: @username, proxmox_password: 'wrong_password')
      end).must_raise ArgumentError
    end
  end

  it 'authenticates with user token' do
    VCR.use_cassette('auth_user_token') do
      Fog::Proxmox::Identity.new(proxmox_url: @proxmox_url,
                                 proxmox_auth_method: Fog::Proxmox::Auth::Token::UserToken::NAME, proxmox_userid: @username, proxmox_tokenid: @tokenid, proxmox_token: @token)
      _(proc do
        Fog::Proxmox::Identity.new(proxmox_url: @proxmox_url,
                                   proxmox_auth_method: Fog::Proxmox::Auth::Token::UserToken::NAME, proxmox_userid: @username, proxmox_tokenid: @tokenid, proxmox_token: 'wrong_token')
      end).must_raise Excon::Errors::Unauthorized
      _(proc do
        Fog::Proxmox::Identity.new(proxmox_auth_method: Fog::Proxmox::Auth::Token::UserToken::NAME,
                                   proxmox_userid: @username, proxmox_tokenid: @tokenid, proxmox_token: 'wrong_token')
      end).must_raise ArgumentError
      _(proc do
        Fog::Proxmox::Identity.new(proxmox_url: @proxmox_url, proxmox_userid: @username, proxmox_tokenid: @tokenid,
                                   proxmox_token: 'wrong_token')
      end).must_raise ArgumentError
      _(proc do
        Fog::Proxmox::Identity.new(proxmox_url: @proxmox_url,
                                   proxmox_auth_method: Fog::Proxmox::Auth::Token::UserToken::NAME, proxmox_userid: @username, proxmox_token: @token)
      end).must_raise Fog::Proxmox::Auth::Token::UserToken::URIError
      _(proc do
        Fog::Proxmox::Identity.new(proxmox_url: @proxmox_url,
                                   proxmox_auth_method: Fog::Proxmox::Auth::Token::UserToken::NAME, proxmox_tokenid: @tokenid, proxmox_token: @token)
      end).must_raise Fog::Proxmox::Auth::Token::UserToken::URIError
      _(proc do
        Fog::Proxmox::Identity.new(proxmox_url: @proxmox_url,
                                   proxmox_auth_method: Fog::Proxmox::Auth::Token::UserToken::NAME, proxmox_userid: @username, proxmox_tokenid: @tokenid)
      end).must_raise Fog::Proxmox::Auth::Token::UserToken::URIError
    end
  end

  it 'checks access ticket with path and privs' do
    VCR.use_cassette('auth') do
      principal = { username: @username, password: @password, privs: ['User.Modify'], path: 'access', otp: 'proxmox01' }
      permissions = @service.check_permissions(principal)
      _(permissions).wont_be_nil
      _(permissions).wont_be_empty
      _(permissions['username']).must_equal @username
      _(permissions['cap']).wont_be_empty
    end
  end

  it 'reads server version' do
    VCR.use_cassette('read_version') do
      version = @service.read_version
      _(version).wont_be_nil
      version.include? 'version'
    end
  end

  it 'CRUD users' do
    VCR.use_cassette('users') do
      bob_hash = {
        userid: 'bobsinclar@pve',
        password: 'bobsinclar1',
        firstname: 'Bob',
        lastname: 'Sinclar',
        email: 'bobsinclar@proxmox.com'
      }
      # Create 1st time
      @service.users.create(bob_hash)
      # Find by id
      bob = @service.users.get bob_hash[:userid]
      _(bob).wont_be_nil
      # Create 2nd time must fails
      _(proc do
        @service.users.create(bob_hash)
      end).must_raise Excon::Errors::InternalServerError
      # all users
      users_all = @service.users.all
      _(users_all).wont_be_nil
      _(users_all).wont_be_empty
      _(users_all).must_include bob
      # Update
      bob.comment = 'novelist'
      bob.enable  = 0
      @service.groups.create(groupid: 'group1')
      @service.groups.create(groupid: 'group2')
      bob.groups = %w[group1 group2]
      bob.update
      # change bob's password with special characters
      bob.password = 'bobsinclar&!.-_2'
      bob.change_password
      # disabled users
      users_disabled = @service.users.all('enabled' => 0)
      _(users_disabled).wont_be_nil
      _(users_disabled).wont_be_empty
      _(users_disabled).must_include bob
      # Delete
      bob.destroy
      group1 = @service.groups.get 'group1'
      group1.destroy
      group2 = @service.groups.get 'group2'
      group2.destroy
      bob = @service.users.get bob_hash[:userid]
      _(bob).must_be_nil
    end
  end

  it 'CRUD groups' do
    VCR.use_cassette('groups') do
      group_hash = { groupid: 'group1' }
      # Create 1st time
      @service.groups.create(group_hash)
      # Find by id
      group = @service.groups.get group_hash[:groupid]
      _(group).wont_be_nil
      # Create 2nd time must fails
      _(proc do
        @service.groups.create(group_hash)
      end).must_raise Excon::Errors::InternalServerError
      # Update
      group.comment = 'Group 1'
      group.update
      # all groups
      groups_all = @service.groups.all
      _(groups_all).wont_be_nil
      _(groups_all).wont_be_empty
      _(groups_all).must_include group
      # Delete
      group.destroy
      group1 = @service.groups.get group_hash[:groupid]
      _(group1).must_be_nil
    end
  end

  it 'CRUD roles' do
    VCR.use_cassette('roles') do
      role_hash = { roleid: 'PVETestAuditor' }
      # Create 1st time
      @service.roles.create(role_hash)
      # Find by id
      role = @service.roles.get role_hash[:roleid]
      _(role).wont_be_nil
      # Create 2nd time must fails
      _(proc do
        @service.roles.create(role_hash)
      end).must_raise Excon::Errors::InternalServerError
      # # Update
      role.privs = 'Datastore.Audit Sys.Audit VM.Audit'
      role.update
      # # all groups
      roles_all = @service.roles.all
      _(roles_all).wont_be_nil
      _(roles_all).wont_be_empty
      _(roles_all).must_include role
      # Delete
      role.destroy
      role = @service.roles.get role_hash[:roleid]
      _(role).must_be_nil
    end
  end

  it 'CRUD domains' do
    VCR.use_cassette('domains') do
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
      ad_hash = {
        realm: 'ActiveDirectory',
        type: 'ad',
        domain: 'proxmox.com',
        server1: 'localhost',
        port: 389,
        default: 0,
        secure: 0
      }
      # Create 1st time
      @service.domains.create(ldap_hash)
      # Find by id
      ldap = @service.domains.get ldap_hash[:realm]
      _(ldap).wont_be_nil
      # Create 1st time
      @service.domains.create(ad_hash)
      # Create 2nd time must fails
      _(proc do
        @service.domains.create(ldap_hash)
      end).must_raise Excon::Errors::InternalServerError
      # Create 2nd time must fails
      _(proc do
        @service.domains.create(ad_hash)
      end).must_raise Excon::Errors::InternalServerError
      # Update
      ldap.type.comment = 'Test domain LDAP'
      ldap.type.tfa = 'type=oath,step=30,digits=8'
      ldap.update
      # Find by id
      ad = @service.domains.get ad_hash[:realm]
      _(ad).wont_be_nil
      ad.type.tfa = 'type=yubico,id=1,key=2,url=http://localhost'
      ad.update
      # all groups
      domains_all = @service.domains.all
      _(domains_all).wont_be_nil
      _(domains_all).wont_be_empty
      _(domains_all).must_include ldap
      _(domains_all).must_include ad
      # Delete
      ldap.destroy
      ad.destroy
      ldap = @service.domains.get ldap_hash[:realm]
      _(ldap).must_be_nil
      ad = @service.domains.get ad_hash[:realm]
      _(ad).must_be_nil
    end
  end

  it 'adds or removes permissions' do
    VCR.use_cassette('permissions') do
      # Add ACL to users
      bob_hash = {
        userid: 'bobsinclar@pve',
        password: 'bobsinclar1',
        firstname: 'Bob',
        lastname: 'Sinclar',
        email: 'bobsinclar@proxmox.com'
      }
      role_hash = {
        roleid: 'PVETestAdmin',
        privs: 'User.Modify,Group.Allocate'
      }
      @service.roles.create(role_hash)
      role = @service.roles.get(role_hash[:roleid])
      _(role).wont_be_nil
      @service.users.create(bob_hash)
      bob = @service.users.get bob_hash[:userid]
      _(bob).wont_be_nil
      permission = @service.permissions.create(type: 'user', roleid: role.roleid, path: '/access', ugid: bob.userid)
      _(permission).wont_be_nil
      # Read all permissions
      permissions = @service.permissions.all
      _(permissions).wont_be_empty
      _(permissions).must_include permission
      # Read user permissions
      _(bob.permissions).wont_be_empty
      _(bob.permissions.keys).must_include '/access'
      _(bob.permissions.keys).must_include '/access/groups'
      # Remove ACL to users
      permissions.destroy(type: 'user', roleid: role.roleid, path: '/access', ugid: bob.userid)
      permission = @service.permissions.get('user', role.roleid, '/access', bob.userid)
      _(permission).must_be_nil
      bob = @service.users.get bob_hash[:userid]
      bob.destroy
      # Add ACL to groups
      group1 = @service.groups.create(groupid: 'group1', comment: 'Group 1')
      permission = @service.permissions.create(type: 'group', roleid: role.roleid, path: '/access',
                                               ugid: group1.groupid)
      _(permission).wont_be_nil
      # Read new permission
      permissions = @service.permissions.all
      _(permissions).wont_be_empty
      _(permissions).must_include permission
      # Remove ACL to groups
      permissions.destroy(type: 'group', roleid: role.roleid, path: '/access', ugid: group1.groupid)
      permissions = @service.permissions.all
      _(permissions).must_be_empty
      group1.destroy
      role.destroy
      role = @service.roles.get(role_hash[:roleid])
      _(role).must_be_nil
    end
  end

  it 'CRUD pools' do
    VCR.use_cassette('pools') do
      pool_hash = { poolid: 'pool1' }
      # Create 1st time
      @service.pools.create(pool_hash)
      # Find by id
      pool = @service.pools.get pool_hash[:poolid]
      _(pool).wont_be_nil
      # Create 2nd time must fails
      _(proc do
        @service.pools.create(pool_hash)
      end).must_raise Excon::Errors::InternalServerError
      # Update
      # Add comment
      pool.comment = 'Pool 1'
      pool.update
      # Add storage as member
      pool.add_server 100 # do nothing if server does not exist
      pool.add_storage 'local-lvm'
      _(pool.members).wont_be_nil
      _(pool.members).wont_be_empty
      _(pool.members.size).must_equal 1 # no vm 100
      _(pool.has_server?(100)).must_equal false
      _(pool.has_storage?('local-lvm')).must_equal true
      # all pools
      pools_all = @service.pools.all
      _(pools_all).wont_be_nil
      _(pools_all).wont_be_empty
      _(pools_all).must_include pool
      # Delete
      pool.remove_server 100
      pool.remove_storage 'local-lvm'
      _(pool.members).must_be_empty
      pool.destroy
      pool = @service.pools.get pool_hash[:poolid]
      _(pool).must_be_nil
    end
  end

  it 'CRUD user tokens' do
    VCR.use_cassette('tokens') do
      # Get user
      bob_hash = {
        userid: 'bobsinclar@pve',
        password: 'bobsinclar1',
        firstname: 'Bob',
        lastname: 'Sinclar',
        email: 'bobsinclar@proxmox.com'
      }
      token_hash = {
        userid: bob_hash[:userid],
        tokenid: 'bobsinclar1'
      }
      @service.users.create(bob_hash)
      bob = @service.users.get token_hash[:userid]
      _(bob).wont_be_nil
      # Create Token
      token = bob.tokens.create(token_hash)
      token_info = token.info
      _(token_info).wont_be_nil
      # all user tokens
      tokens_all = bob.tokens.all
      _(tokens_all).wont_be_nil
      _(tokens_all).wont_be_empty
      _(tokens_all).must_include token
      # Find token info by tokenid
      token_get = bob.tokens.get(token_hash[:tokenid])
      _(token_get).wont_be_nil
      _(token_get).must_equal token
      # Update
      token.comment = 'test'
      token.expire  = 0
      token.privsep = 0
      token.update
      # Delete
      token.destroy
      token = bob.tokens.get token_hash[:tokenid]
      _(token).must_be_nil
      bob.destroy
      bob = @service.users.get bob_hash[:userid]
      _(bob).must_be_nil
    end
  end
end
