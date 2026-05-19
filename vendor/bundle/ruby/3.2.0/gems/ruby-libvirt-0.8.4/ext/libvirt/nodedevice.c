/*
 * nodedevice.c: virNodeDevice methods
 *
 * Copyright (C) 2010 Red Hat Inc.
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

static VALUE c_nodedevice;

static void nodedevice_free(void *s)
{
    ruby_libvirt_free_struct(NodeDevice, s);
}

static virNodeDevicePtr nodedevice_get(VALUE n)
{
    ruby_libvirt_get_struct(NodeDevice, n);
}

VALUE ruby_libvirt_nodedevice_new(virNodeDevicePtr n, VALUE conn)
{
    return ruby_libvirt_new_class(c_nodedevice, n, conn, nodedevice_free);
}

/*
 * call-seq:
 *   nodedevice.name -> String
 *
 * Call virNodeDeviceGetName[https://libvirt.org/html/libvirt-libvirt-nodedev.html#virNodeDeviceGetName]
 * to retrieve the name of the node device.
 */
static VALUE libvirt_nodedevice_name(VALUE c)
{
    ruby_libvirt_generate_call_string(virNodeDeviceGetName,
                                      ruby_libvirt_connect_get(c), 0,
                                      nodedevice_get(c));
}

/*
 * call-seq:
 *   nodedevice.parent -> String
 *
 * Call virNodeDeviceGetParent[https://libvirt.org/html/libvirt-libvirt-nodedev.html#virNodeDeviceGetParent]
 * to retrieve the parent of the node device.
 */
static VALUE libvirt_nodedevice_parent(VALUE c)
{
    /* unfortunately we can't use ruby_libvirt_generate_call_string() here
     * because virNodeDeviceGetParent() returns NULL as a valid value (when this
     * device has no parent).  Hand-code it instead
     */

    const char *str;

    str = virNodeDeviceGetParent(nodedevice_get(c));
    if (str == NULL) {
        return Qnil;
    }
    else {
        return rb_str_new2(str);
    }
}

/*
 * call-seq:
 *   nodedevice.num_of_caps -> Fixnum
 *
 * Call virNodeDeviceNumOfCaps[https://libvirt.org/html/libvirt-libvirt-nodedev.html#virNodeDeviceNumOfCaps]
 * to retrieve the number of capabilities of the node device.
 */
static VALUE libvirt_nodedevice_num_of_caps(VALUE c)
{
    ruby_libvirt_generate_call_int(virNodeDeviceNumOfCaps,
                                   ruby_libvirt_connect_get(c),
                                   nodedevice_get(c));
}

/*
 * call-seq:
 *   nodedevice.list_caps -> list
 *
 * Call virNodeDeviceListCaps[https://libvirt.org/html/libvirt-libvirt-nodedev.html#virNodeDeviceListCaps]
 * to retrieve a list of capabilities of the node device.
 */
static VALUE libvirt_nodedevice_list_caps(VALUE c)
{
    int r, num;
    char **names;

    num = virNodeDeviceNumOfCaps(nodedevice_get(c));
    ruby_libvirt_raise_error_if(num < 0, e_RetrieveError,
                                "virNodeDeviceNumOfCaps",
                                ruby_libvirt_connect_get(c));
    if (num == 0) {
        /* if num is 0, don't call virNodeDeviceListCaps function */
        return rb_ary_new2(num);
    }

    names = alloca(sizeof(char *) * num);
    r = virNodeDeviceListCaps(nodedevice_get(c), names, num);
    ruby_libvirt_raise_error_if(r < 0, e_RetrieveError,
                                "virNodeDeviceListCaps",
                                ruby_libvirt_connect_get(c));

    return ruby_libvirt_generate_list(r, names);
}

/*
 * call-seq:
 *   nodedevice.xml_desc(flags=0) -> String
 *
 * Call virNodeDeviceGetXMLDesc[https://libvirt.org/html/libvirt-libvirt-nodedev.html#virNodeDeviceGetXMLDesc]
 * to retrieve the XML for the node device.
 */
static VALUE libvirt_nodedevice_xml_desc(int argc, VALUE *argv, VALUE n)
{
    VALUE flags = RUBY_Qnil;

    rb_scan_args(argc, argv, "01", &flags);

    ruby_libvirt_generate_call_string(virNodeDeviceGetXMLDesc,
                                      ruby_libvirt_connect_get(n),
                                      1, nodedevice_get(n),
                                      ruby_libvirt_value_to_uint(flags));
}

/*
 * call-seq:
 *   nodedevice.detach(driver=nil, flags=0) -> nil
 *
 * Call virNodeDeviceDettach[https://libvirt.org/html/libvirt-libvirt-nodedev.html#virNodeDeviceDettach]
 * to detach the node device from the node.
 */
static VALUE libvirt_nodedevice_detach(int argc, VALUE *argv, VALUE n)
{
    VALUE driver = RUBY_Qnil, flags = RUBY_Qnil;

    rb_scan_args(argc, argv, "02", &driver, &flags);

    if (ruby_libvirt_value_to_uint(flags) != 0 ||
        ruby_libvirt_get_cstring_or_null(driver) != NULL) {
        ruby_libvirt_generate_call_nil(virNodeDeviceDetachFlags,
                                       ruby_libvirt_connect_get(n),
                                       nodedevice_get(n),
                                       ruby_libvirt_get_cstring_or_null(driver),
                                       ruby_libvirt_value_to_uint(flags));
    } else {
        ruby_libvirt_generate_call_nil(virNodeDeviceDettach,
                                       ruby_libvirt_connect_get(n),
                                       nodedevice_get(n));
    }
}

/*
 * call-seq:
 *   nodedevice.reattach -> nil
 *
 * Call virNodeDeviceReAttach[https://libvirt.org/html/libvirt-libvirt-nodedev.html#virNodeDeviceReAttach]
 * to reattach the node device to the node.
 */
static VALUE libvirt_nodedevice_reattach(VALUE n)
{
    ruby_libvirt_generate_call_nil(virNodeDeviceReAttach,
                                   ruby_libvirt_connect_get(n),
                                   nodedevice_get(n));
}

/*
 * call-seq:
 *   nodedevice.reset -> nil
 *
 * Call virNodeDeviceReset[https://libvirt.org/html/libvirt-libvirt-nodedev.html#virNodeDeviceReset]
 * to reset the node device.
 */
static VALUE libvirt_nodedevice_reset(VALUE n)
{
    ruby_libvirt_generate_call_nil(virNodeDeviceReset,
                                   ruby_libvirt_connect_get(n),
                                   nodedevice_get(n));
}

/*
 * call-seq:
 *   nodedevice.destroy -> nil
 *
 * Call virNodeDeviceDestroy[https://libvirt.org/html/libvirt-libvirt-nodedev.html#virNodeDeviceDestroy]
 * to shutdown the node device.
 */
static VALUE libvirt_nodedevice_destroy(VALUE n)
{
    ruby_libvirt_generate_call_nil(virNodeDeviceDestroy,
                                   ruby_libvirt_connect_get(n),
                                   nodedevice_get(n));
}

/*
 * call-seq:
 *   nodedevice.free -> nil
 *
 * Call virNodeDeviceFree[https://libvirt.org/html/libvirt-libvirt-nodedev.html#virNodeDeviceFree]
 * to free the node device object.  After this call the node device object is
 * no longer valid.
 */
static VALUE libvirt_nodedevice_free(VALUE n)
{
    ruby_libvirt_generate_call_free(NodeDevice, n);
}

/*
 * call-seq:
 *   nodedevice.lookup_scsi_host_by_wwn(wwnn, wwpn, flags=0) -> Libvirt::NodeDevice
 *
 * Call virNodeDeviceLookupSCSIHostByWWN[https://libvirt.org/html/libvirt-libvirt-nodedev.html#virNodeDeviceLookupSCSIHostByWWN]
 * to look up a SCSI host by its WWNN and WWPN.
 */
static VALUE libvirt_nodedevice_lookup_scsi_host_by_wwn(int argc, VALUE *argv,
                                                        VALUE n)
{
    VALUE wwnn, wwpn, flags = RUBY_Qnil;
    virNodeDevicePtr nd;

    rb_scan_args(argc, argv, "21", &wwnn, &wwpn, &flags);

    nd = virNodeDeviceLookupSCSIHostByWWN(ruby_libvirt_connect_get(n),
                                          StringValueCStr(wwnn),
                                          StringValueCStr(wwpn),
                                          ruby_libvirt_value_to_uint(flags));
    if (nd == NULL) {
        return Qnil;
    }

    return ruby_libvirt_nodedevice_new(nd, ruby_libvirt_conn_attr(n));
}


/*
 * Class Libvirt::NodeDevice
 */
void ruby_libvirt_nodedevice_init(void)
{
    c_nodedevice = rb_define_class_under(m_libvirt, "NodeDevice", rb_cObject);
    rb_undef_alloc_func(c_nodedevice);
    rb_define_singleton_method(c_nodedevice, "new",
                               ruby_libvirt_new_not_allowed, -1);

    rb_define_attr(c_nodedevice, "connection", 1, 0);

    rb_define_method(c_nodedevice, "name", libvirt_nodedevice_name, 0);
    rb_define_method(c_nodedevice, "parent", libvirt_nodedevice_parent, 0);
    rb_define_method(c_nodedevice, "num_of_caps",
                     libvirt_nodedevice_num_of_caps, 0);
    rb_define_method(c_nodedevice, "list_caps",
                     libvirt_nodedevice_list_caps, 0);
    rb_define_method(c_nodedevice, "xml_desc", libvirt_nodedevice_xml_desc, -1);
    rb_define_method(c_nodedevice, "detach", libvirt_nodedevice_detach, -1);
    rb_define_method(c_nodedevice, "reattach", libvirt_nodedevice_reattach, 0);
    rb_define_method(c_nodedevice, "reset", libvirt_nodedevice_reset, 0);
    rb_define_method(c_nodedevice, "destroy", libvirt_nodedevice_destroy, 0);
    rb_define_method(c_nodedevice, "free", libvirt_nodedevice_free, 0);
    rb_define_method(c_nodedevice, "lookup_scsi_host_by_wwn",
                     libvirt_nodedevice_lookup_scsi_host_by_wwn, -1);
}
