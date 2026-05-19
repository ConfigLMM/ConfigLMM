/*
 * network.c: virNetwork methods
 *
 * Copyright (C) 2007,2010 Red Hat Inc.
 * Copyright (C) 2013-2016 Chris Lalancette <clalancette@gmail.com>
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 2.1 of the License, or (at your option) any later version.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public
 * License along with this library; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307  USA
 */

#include <ruby.h>
#include <libvirt/libvirt.h>
#include <libvirt/virterror.h>
#include "common.h"
#include "connect.h"
#include "extconf.h"

static VALUE c_network;

static void network_free(void *d)
{
    ruby_libvirt_free_struct(Network, d);
}

static virNetworkPtr network_get(VALUE n)
{
    ruby_libvirt_get_struct(Network, n);
}

VALUE ruby_libvirt_network_new(virNetworkPtr n, VALUE conn)
{
    return ruby_libvirt_new_class(c_network, n, conn, network_free);
}

/*
 * call-seq:
 *   net.undefine -> nil
 *
 * Call virNetworkUndefine[https://libvirt.org/html/libvirt-libvirt-network.html#virNetworkUndefine]
 * to undefine this network.
 */
static VALUE libvirt_network_undefine(VALUE n)
{
    ruby_libvirt_generate_call_nil(virNetworkUndefine,
                                   ruby_libvirt_connect_get(n),
                                   network_get(n));
}

/*
 * call-seq:
 *   net.create -> nil
 *
 * Call virNetworkCreate[https://libvirt.org/html/libvirt-libvirt-network.html#virNetworkCreate]
 * to start this network.
 */
static VALUE libvirt_network_create(VALUE n)
{
    ruby_libvirt_generate_call_nil(virNetworkCreate,
                                   ruby_libvirt_connect_get(n),
                                   network_get(n));
}

/*
 * call-seq:
 *   net.update -> nil
 *
 * Call virNetworkUpdate[https://libvirt.org/html/libvirt-libvirt-network.html#virNetworkUpdate]
 * to update this network.
 */
static VALUE libvirt_network_update(VALUE n, VALUE command, VALUE section,
                                    VALUE index, VALUE xml, VALUE flags)
{
    ruby_libvirt_generate_call_nil(virNetworkUpdate,
                                   ruby_libvirt_connect_get(n),
                                   network_get(n), NUM2UINT(command),
                                   NUM2UINT(section), NUM2INT(index),
                                   StringValuePtr(xml), NUM2UINT(flags));
}

/*
 * call-seq:
 *   net.destroy -> nil
 *
 * Call virNetworkDestroy[https://libvirt.org/html/libvirt-libvirt-network.html#virNetworkDestroy]
 * to shutdown this network.
 */
static VALUE libvirt_network_destroy(VALUE n)
{
    ruby_libvirt_generate_call_nil(virNetworkDestroy,
                                   ruby_libvirt_connect_get(n),
                                   network_get(n));
}

/*
 * call-seq:
 *   net.name -> String
 *
 * Call virNetworkGetName[https://libvirt.org/html/libvirt-libvirt-network.html#virNetworkGetName]
 * to retrieve the name of this network.
 */
static VALUE libvirt_network_name(VALUE n)
{
    ruby_libvirt_generate_call_string(virNetworkGetName,
                                      ruby_libvirt_connect_get(n), 0,
                                      network_get(n));
}

/*
 * call-seq:
 *   net.uuid -> String
 *
 * Call virNetworkGetUUIDString[https://libvirt.org/html/libvirt-libvirt-network.html#virNetworkGetUUIDString]
 * to retrieve the UUID of this network.
 */
static VALUE libvirt_network_uuid(VALUE n)
{
    ruby_libvirt_generate_uuid(virNetworkGetUUIDString,
                               ruby_libvirt_connect_get(n), network_get(n));
}

/*
 * call-seq:
 *   net.xml_desc(flags=0) -> String
 *
 * Call virNetworkGetXMLDesc[https://libvirt.org/html/libvirt-libvirt-network.html#virNetworkGetXMLDesc]
 * to retrieve the XML for this network.
 */
static VALUE libvirt_network_xml_desc(int argc, VALUE *argv, VALUE n)
{
    VALUE flags = RUBY_Qnil;

    rb_scan_args(argc, argv, "01", &flags);

    ruby_libvirt_generate_call_string(virNetworkGetXMLDesc,
                                      ruby_libvirt_connect_get(n), 1,
                                      network_get(n),
                                      ruby_libvirt_value_to_uint(flags));
}

/*
 * call-seq:
 *   net.bridge_name -> String
 *
 * Call virNetworkGetBridgeName[https://libvirt.org/html/libvirt-libvirt-network.html#virNetworkGetBridgeName]
 * to retrieve the bridge name for this network.
 */
static VALUE libvirt_network_bridge_name(VALUE n)
{
    ruby_libvirt_generate_call_string(virNetworkGetBridgeName,
                                      ruby_libvirt_connect_get(n),
                                      1, network_get(n));
}

/*
 * call-seq:
 *   net.autostart? -> [true|false]
 *
 * Call virNetworkGetAutostart[https://libvirt.org/html/libvirt-libvirt-network.html#virNetworkGetAutostart]
 * to determine if this network will be autostarted when libvirtd starts.
 */
static VALUE libvirt_network_autostart(VALUE n)
{
    int r, autostart;

    r = virNetworkGetAutostart(network_get(n), &autostart);
    ruby_libvirt_raise_error_if(r < 0, e_RetrieveError, "virNetworkAutostart",
                                ruby_libvirt_connect_get(n));

    return autostart ? Qtrue : Qfalse;
}

/*
 * call-seq:
 *   net.autostart = [true|false]
 *
 * Call virNetworkSetAutostart[https://libvirt.org/html/libvirt-libvirt-network.html#virNetworkSetAutostart]
 * to set this network to be autostarted when libvirtd starts.
 */
static VALUE libvirt_network_autostart_equal(VALUE n, VALUE autostart)
{
    if (autostart != Qtrue && autostart != Qfalse) {
        rb_raise(rb_eTypeError,
                 "wrong argument type (expected TrueClass or FalseClass)");
    }

    ruby_libvirt_generate_call_nil(virNetworkSetAutostart,
                                   ruby_libvirt_connect_get(n),
                                   network_get(n), RTEST(autostart) ? 1 : 0);
}

/*
 * call-seq:
 *   net.free -> nil
 *
 * Call virNetworkFree[https://libvirt.org/html/libvirt-libvirt-network.html#virNetworkFree]
 * to free this network.  The object will no longer be valid after this call.
 */
static VALUE libvirt_network_free(VALUE n)
{
    ruby_libvirt_generate_call_free(Network, n);
}

/*
 * call-seq:
 *   net.active? -> [true|false]
 *
 * Call virNetworkIsActive[https://libvirt.org/html/libvirt-libvirt-network.html#virNetworkIsActive]
 * to determine if this network is currently active.
 */
static VALUE libvirt_network_active_p(VALUE n)
{
    ruby_libvirt_generate_call_truefalse(virNetworkIsActive,
                                         ruby_libvirt_connect_get(n),
                                         network_get(n));
}

/*
 * call-seq:
 *   net.persistent? -> [true|false]
 *
 * Call virNetworkIsPersistent[https://libvirt.org/html/libvirt-libvirt-network.html#virNetworkIsPersistent]
 * to determine if this network is persistent.
 */
static VALUE libvirt_network_persistent_p(VALUE n)
{
    ruby_libvirt_generate_call_truefalse(virNetworkIsPersistent,
                                         ruby_libvirt_connect_get(n),
                                         network_get(n));
}

struct leases_arg {
    virNetworkDHCPLeasePtr *leases;
    int nleases;
};

static VALUE leases_wrap(VALUE arg)
{
    struct leases_arg *e = (struct leases_arg *)arg;
    VALUE result, hash;
    virNetworkDHCPLeasePtr lease;
    int i;

    result = rb_ary_new2(e->nleases);

    for (i = 0; i < e->nleases; i++) {
        lease = e->leases[i];

        hash = rb_hash_new();
        rb_hash_aset(hash, rb_str_new2("iface"), rb_str_new2(lease->iface));
        rb_hash_aset(hash, rb_str_new2("expirytime"),
                     LL2NUM(lease->expirytime));
        rb_hash_aset(hash, rb_str_new2("type"), INT2NUM(lease->type));
        if (lease->mac) {
            rb_hash_aset(hash, rb_str_new2("mac"), rb_str_new2(lease->mac));
        }
        if (lease->iaid) {
            rb_hash_aset(hash, rb_str_new2("iaid"), rb_str_new2(lease->iaid));
        }
        rb_hash_aset(hash, rb_str_new2("ipaddr"), rb_str_new2(lease->ipaddr));
        rb_hash_aset(hash, rb_str_new2("prefix"), UINT2NUM(lease->prefix));
        if (lease->hostname) {
            rb_hash_aset(hash, rb_str_new2("hostname"),
                         rb_str_new2(lease->hostname));
        }
        if (lease->clientid) {
            rb_hash_aset(hash, rb_str_new2("clientid"),
                         rb_str_new2(lease->clientid));
        }

        rb_ary_store(result, i, hash);
    }

    return result;
}

/*
 * call-seq:
 *   net.dhcp_leases(mac=nil, flags=0) -> Hash
 *
 * Call virNetworkGetDHCPLeases[https://libvirt.org/html/libvirt-libvirt-network.html#virNetworkGetDHCPLeases]
 * to retrieve the leases for this network.
 */
static VALUE libvirt_network_get_dhcp_leases(int argc, VALUE *argv, VALUE n)
{
    VALUE mac = RUBY_Qnil, flags = RUBY_Qnil, result;
    int nleases, i = 0, exception = 0;
    virNetworkDHCPLeasePtr *leases = NULL;
    struct leases_arg args;

    rb_scan_args(argc, argv, "02", &mac, &flags);

    nleases = virNetworkGetDHCPLeases(network_get(n),
                                      ruby_libvirt_get_cstring_or_null(mac),
                                      &leases,
                                      ruby_libvirt_value_to_uint(flags));
    ruby_libvirt_raise_error_if(nleases < 0, e_Error, "virNetworkGetDHCPLeases",
                                ruby_libvirt_connect_get(n));

    args.leases = leases;
    args.nleases = nleases;
    result = rb_protect(leases_wrap, (VALUE)&args, &exception);

    for (i = 0; i < nleases; i++) {
        virNetworkDHCPLeaseFree(leases[i]);
    }
    free(leases);

    if (exception) {
        rb_jump_tag(exception);
    }

    return result;
}

/*
 * Class Libvirt::Network
 */
void ruby_libvirt_network_init(void)
{
    c_network = rb_define_class_under(m_libvirt, "Network", rb_cObject);
    rb_undef_alloc_func(c_network);
    rb_define_singleton_method(c_network, "new",
                               ruby_libvirt_new_not_allowed, -1);

    rb_define_attr(c_network, "connection", 1, 0);

    rb_define_method(c_network, "undefine", libvirt_network_undefine, 0);
    rb_define_method(c_network, "create", libvirt_network_create, 0);
    rb_define_method(c_network, "update", libvirt_network_update, 5);

    rb_define_method(c_network, "destroy", libvirt_network_destroy, 0);
    rb_define_method(c_network, "name", libvirt_network_name, 0);
    rb_define_method(c_network, "uuid", libvirt_network_uuid, 0);
    rb_define_method(c_network, "xml_desc", libvirt_network_xml_desc, -1);
    rb_define_method(c_network, "bridge_name", libvirt_network_bridge_name, 0);
    rb_define_method(c_network, "autostart", libvirt_network_autostart, 0);
    rb_define_method(c_network, "autostart?", libvirt_network_autostart, 0);
    rb_define_method(c_network, "autostart=", libvirt_network_autostart_equal,
                     1);
    rb_define_method(c_network, "free", libvirt_network_free, 0);
    rb_define_method(c_network, "active?", libvirt_network_active_p, 0);
    rb_define_method(c_network, "persistent?", libvirt_network_persistent_p, 0);
    /* Ideally we would just have the "UPDATE_COMMAND_NONE" constant.
     * Unfortunately we screwed up long ago, and we have to
     * leave "NETWORK_UPDATE_COMMAND_NONE" for backwards compatibility.
     */
    rb_define_const(c_network, "UPDATE_COMMAND_NONE",
                    INT2NUM(VIR_NETWORK_UPDATE_COMMAND_NONE));
    rb_define_const(c_network, "NETWORK_UPDATE_COMMAND_NONE",
                    INT2NUM(VIR_NETWORK_UPDATE_COMMAND_NONE));
    /* Ideally we would just have the "UPDATE_COMMAND_MODIFY" constant.
     * Unfortunately we screwed up long ago, and we have to
     * leave "NETWORK_UPDATE_COMMAND_MODIFY" for backwards compatibility.
     */
    rb_define_const(c_network, "UPDATE_COMMAND_MODIFY",
                    INT2NUM(VIR_NETWORK_UPDATE_COMMAND_MODIFY));
    rb_define_const(c_network, "NETWORK_UPDATE_COMMAND_MODIFY",
                    INT2NUM(VIR_NETWORK_UPDATE_COMMAND_MODIFY));
    /* Ideally we would just have the "UPDATE_COMMAND_ADD_LAST" constant.
     * Unfortunately we screwed up long ago, and we have to
     * leave "NETWORK_UPDATE_COMMAND_ADD_LAST" for backwards compatibility.
     */
    rb_define_const(c_network, "UPDATE_COMMAND_ADD_LAST",
                    INT2NUM(VIR_NETWORK_UPDATE_COMMAND_ADD_LAST));
    rb_define_const(c_network, "NETWORK_UPDATE_COMMAND_ADD_LAST",
                    INT2NUM(VIR_NETWORK_UPDATE_COMMAND_ADD_LAST));
    /* Ideally we would just have the "UPDATE_COMMAND_ADD_FIRST" constant.
     * Unfortunately we screwed up long ago, and we have to
     * leave "NETWORK_UPDATE_COMMAND_ADD_FIRST" for backwards compatibility.
     */
    rb_define_const(c_network, "UPDATE_COMMAND_ADD_FIRST",
                    INT2NUM(VIR_NETWORK_UPDATE_COMMAND_ADD_FIRST));
    rb_define_const(c_network, "NETWORK_UPDATE_COMMAND_ADD_FIRST",
                    INT2NUM(VIR_NETWORK_UPDATE_COMMAND_ADD_FIRST));
    /* Ideally we would just have the "SECTION_NONE" constant.
     * Unfortunately we screwed up long ago, and we have to
     * leave "NETWORK_SECTION_NONE" for backwards compatibility.
     */
    rb_define_const(c_network, "SECTION_NONE",
                    INT2NUM(VIR_NETWORK_SECTION_NONE));
    rb_define_const(c_network, "NETWORK_SECTION_NONE",
                    INT2NUM(VIR_NETWORK_SECTION_NONE));
    /* Ideally we would just have the "SECTION_BRIDGE" constant.
     * Unfortunately we screwed up long ago, and we have to
     * leave "NETWORK_SECTION_BRIDGE" for backwards compatibility.
     */
    rb_define_const(c_network, "SECTION_BRIDGE",
                    INT2NUM(VIR_NETWORK_SECTION_BRIDGE));
    rb_define_const(c_network, "NETWORK_SECTION_BRIDGE",
                    INT2NUM(VIR_NETWORK_SECTION_BRIDGE));
    /* Ideally we would just have the "SECTION_DOMAIN" constant.
     * Unfortunately we screwed up long ago, and we have to
     * leave "NETWORK_SECTION_DOMAIN" for backwards compatibility.
     */
    rb_define_const(c_network, "SECTION_DOMAIN",
                    INT2NUM(VIR_NETWORK_SECTION_DOMAIN));
    rb_define_const(c_network, "NETWORK_SECTION_DOMAIN",
                    INT2NUM(VIR_NETWORK_SECTION_DOMAIN));
    /* Ideally we would just have the "SECTION_IP" constant.
     * Unfortunately we screwed up long ago, and we have to
     * leave "NETWORK_SECTION_IP" for backwards compatibility.
     */
    rb_define_const(c_network, "SECTION_IP",
                    INT2NUM(VIR_NETWORK_SECTION_IP));
    rb_define_const(c_network, "NETWORK_SECTION_IP",
                    INT2NUM(VIR_NETWORK_SECTION_IP));
    /* Ideally we would just have the "SECTION_IP_DHCP_HOST" constant.
     * Unfortunately we screwed up long ago, and we have to
     * leave "NETWORK_SECTION_IP_DHCP_HOST" for backwards compatibility.
     */
    rb_define_const(c_network, "SECTION_IP_DHCP_HOST",
                    INT2NUM(VIR_NETWORK_SECTION_IP_DHCP_HOST));
    rb_define_const(c_network, "NETWORK_SECTION_IP_DHCP_HOST",
                    INT2NUM(VIR_NETWORK_SECTION_IP_DHCP_HOST));
    /* Ideally we would just have the "SECTION_IP_DHCP_RANGE" constant.
     * Unfortunately we screwed up long ago, and we have to
     * leave "NETWORK_SECTION_IP_DHCP_RANGE" for backwards compatibility.
     */
    rb_define_const(c_network, "SECTION_IP_DHCP_RANGE",
                    INT2NUM(VIR_NETWORK_SECTION_IP_DHCP_RANGE));
    rb_define_const(c_network, "NETWORK_SECTION_IP_DHCP_RANGE",
                    INT2NUM(VIR_NETWORK_SECTION_IP_DHCP_RANGE));
    /* Ideally we would just have the "SECTION_FORWARD" constant.
     * Unfortunately we screwed up long ago, and we have to
     * leave "NETWORK_SECTION_FORWARD" for backwards compatibility.
     */
    rb_define_const(c_network, "SECTION_FORWARD",
                    INT2NUM(VIR_NETWORK_SECTION_FORWARD));
    rb_define_const(c_network, "NETWORK_SECTION_FORWARD",
                    INT2NUM(VIR_NETWORK_SECTION_FORWARD));
    /* Ideally we would just have the "SECTION_FORWARD_INTERFACE" constant.
     * Unfortunately we screwed up long ago, and we have to
     * leave "NETWORK_SECTION_FORWARD_INTERFACE" for backwards compatibility.
     */
    rb_define_const(c_network, "SECTION_FORWARD_INTERFACE",
                    INT2NUM(VIR_NETWORK_SECTION_FORWARD_INTERFACE));
    rb_define_const(c_network, "NETWORK_SECTION_FORWARD_INTERFACE",
                    INT2NUM(VIR_NETWORK_SECTION_FORWARD_INTERFACE));
    /* Ideally we would just have the "SECTION_FORWARD_PF" constant.
     * Unfortunately we screwed up long ago, and we have to
     * leave "NETWORK_SECTION_FORWARD_PF" for backwards compatibility.
     */
    rb_define_const(c_network, "SECTION_FORWARD_PF",
                    INT2NUM(VIR_NETWORK_SECTION_FORWARD_PF));
    rb_define_const(c_network, "NETWORK_SECTION_FORWARD_PF",
                    INT2NUM(VIR_NETWORK_SECTION_FORWARD_PF));
    /* Ideally we would just have the "SECTION_PORTGROUP" constant.
     * Unfortunately we screwed up long ago, and we have to
     * leave "NETWORK_SECTION_PORTGROUP" for backwards compatibility.
     */
    rb_define_const(c_network, "SECTION_PORTGROUP",
                    INT2NUM(VIR_NETWORK_SECTION_PORTGROUP));
    rb_define_const(c_network, "NETWORK_SECTION_PORTGROUP",
                    INT2NUM(VIR_NETWORK_SECTION_PORTGROUP));
    /* Ideally we would just have the "SECTION_DNS_HOST" constant.
     * Unfortunately we screwed up long ago, and we have to
     * leave "NETWORK_SECTION_DNS_HOST" for backwards compatibility.
     */
    rb_define_const(c_network, "SECTION_DNS_HOST",
                    INT2NUM(VIR_NETWORK_SECTION_DNS_HOST));
    rb_define_const(c_network, "NETWORK_SECTION_DNS_HOST",
                    INT2NUM(VIR_NETWORK_SECTION_DNS_HOST));
    /* Ideally we would just have the "SECTION_DNS_TXT" constant.
     * Unfortunately we screwed up long ago, and we have to
     * leave "NETWORK_SECTION_DNS_TXT" for backwards compatibility.
     */
    rb_define_const(c_network, "SECTION_DNS_TXT",
                    INT2NUM(VIR_NETWORK_SECTION_DNS_TXT));
    rb_define_const(c_network, "NETWORK_SECTION_DNS_TXT",
                    INT2NUM(VIR_NETWORK_SECTION_DNS_TXT));
    /* Ideally we would just have the "SECTION_DNS_SRV" constant.
     * Unfortunately we screwed up long ago, and we have to
     * leave "NETWORK_SECTION_DNS_SRV" for backwards compatibility.
     */
    rb_define_const(c_network, "SECTION_DNS_SRV",
                    INT2NUM(VIR_NETWORK_SECTION_DNS_SRV));
    rb_define_const(c_network, "NETWORK_SECTION_DNS_SRV",
                    INT2NUM(VIR_NETWORK_SECTION_DNS_SRV));
    /* Ideally we would just have the "UPDATE_AFFECT_CURRENT" constant.
     * Unfortunately we screwed up long ago, and we have to
     * leave "NETWORK_UPDATE_AFFECT_CURRENT" for backwards compatibility.
     */
    rb_define_const(c_network, "UPDATE_AFFECT_CURRENT",
                    INT2NUM(VIR_NETWORK_UPDATE_AFFECT_CURRENT));
    rb_define_const(c_network, "NETWORK_UPDATE_AFFECT_CURRENT",
                    INT2NUM(VIR_NETWORK_UPDATE_AFFECT_CURRENT));
    /* Ideally we would just have the "UPDATE_AFFECT_LIVE" constant.
     * Unfortunately we screwed up long ago, and we have to
     * leave "NETWORK_UPDATE_AFFECT_LIVE" for backwards compatibility.
     */
    rb_define_const(c_network, "UPDATE_AFFECT_LIVE",
                    INT2NUM(VIR_NETWORK_UPDATE_AFFECT_LIVE));
    rb_define_const(c_network, "NETWORK_UPDATE_AFFECT_LIVE",
                    INT2NUM(VIR_NETWORK_UPDATE_AFFECT_LIVE));
    /* Ideally we would just have the "UPDATE_AFFECT_CONFIG" constant.
     * Unfortunately we screwed up long ago, and we have to
     * leave "NETWORK_UPDATE_AFFECT_CONFIG" for backwards compatibility.
     */
    rb_define_const(c_network, "UPDATE_AFFECT_CONFIG",
                    INT2NUM(VIR_NETWORK_UPDATE_AFFECT_CONFIG));
    rb_define_const(c_network, "NETWORK_UPDATE_AFFECT_CONFIG",
                    INT2NUM(VIR_NETWORK_UPDATE_AFFECT_CONFIG));

    rb_define_const(c_network, "XML_INACTIVE",
                    INT2NUM(VIR_NETWORK_XML_INACTIVE));
    rb_define_const(c_network, "UPDATE_COMMAND_DELETE",
                    INT2NUM(VIR_NETWORK_UPDATE_COMMAND_DELETE));

    rb_define_method(c_network, "dhcp_leases",
                     libvirt_network_get_dhcp_leases, -1);

    rb_define_const(c_network, "IP_ADDR_TYPE_IPV4",
                    INT2NUM(VIR_IP_ADDR_TYPE_IPV4));

    rb_define_const(c_network, "IP_ADDR_TYPE_IPV6",
                    INT2NUM(VIR_IP_ADDR_TYPE_IPV6));
}
