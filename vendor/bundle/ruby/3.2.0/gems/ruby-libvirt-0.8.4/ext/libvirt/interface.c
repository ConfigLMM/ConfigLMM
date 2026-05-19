/*
 * interface.c: virInterface methods
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

static VALUE c_interface;

static void interface_free(void *i)
{
    ruby_libvirt_free_struct(Interface, i);
}

static virInterfacePtr interface_get(VALUE i)
{
    ruby_libvirt_get_struct(Interface, i);
}

VALUE ruby_libvirt_interface_new(virInterfacePtr i, VALUE conn)
{
    return ruby_libvirt_new_class(c_interface, i, conn, interface_free);
}

/*
 * call-seq:
 *   interface.undefine -> nil
 *
 * Call virInterfaceUndefine[https://libvirt.org/html/libvirt-libvirt-interface.html#virInterfaceUndefine]
 * to undefine this interface.
 */
static VALUE libvirt_interface_undefine(VALUE i)
{
    ruby_libvirt_generate_call_nil(virInterfaceUndefine,
                                   ruby_libvirt_connect_get(i),
                                   interface_get(i));
}

/*
 * call-seq:
 *   interface.create(flags=0) -> nil
 *
 * Call virInterfaceCreate[https://libvirt.org/html/libvirt-libvirt-interface.html#virInterfaceCreate]
 * to start this interface.
 */
static VALUE libvirt_interface_create(int argc, VALUE *argv, VALUE i)
{
    VALUE flags = RUBY_Qnil;

    rb_scan_args(argc, argv, "01", &flags);

    ruby_libvirt_generate_call_nil(virInterfaceCreate,
                                   ruby_libvirt_connect_get(i),
                                   interface_get(i),
                                   ruby_libvirt_value_to_uint(flags));
}

/*
 * call-seq:
 *   interface.destroy(flags=0) -> nil
 *
 * Call virInterfaceDestroy[https://libvirt.org/html/libvirt-libvirt-interface.html#virInterfaceDestroy]
 * to shutdown this interface.
 */
static VALUE libvirt_interface_destroy(int argc, VALUE *argv, VALUE i)
{
    VALUE flags = RUBY_Qnil;

    rb_scan_args(argc, argv, "01", &flags);

    ruby_libvirt_generate_call_nil(virInterfaceDestroy,
                                   ruby_libvirt_connect_get(i),
                                   interface_get(i),
                                   ruby_libvirt_value_to_uint(flags));
}

/*
 * call-seq:
 *   interface.active? -> [true|false]
 *
 * Call virInterfaceIsActive[https://libvirt.org/html/libvirt-libvirt-interface.html#virInterfaceIsActive]
 * to determine if this interface is currently active.
 */
static VALUE libvirt_interface_active_p(VALUE p)
{
    ruby_libvirt_generate_call_truefalse(virInterfaceIsActive,
                                         ruby_libvirt_connect_get(p),
                                         interface_get(p));
}

/*
 * call-seq:
 *   interface.name -> String
 *
 * Call virInterfaceGetName[https://libvirt.org/html/libvirt-libvirt-interface.html#virInterfaceGetName]
 * to retrieve the name of this interface.
 */
static VALUE libvirt_interface_name(VALUE i)
{
    ruby_libvirt_generate_call_string(virInterfaceGetName,
                                      ruby_libvirt_connect_get(i), 0,
                                      interface_get(i));
}

/*
 * call-seq:
 *   interface.mac -> String
 *
 * Call virInterfaceGetMACString[https://libvirt.org/html/libvirt-libvirt-interface.html#virInterfaceGetMACString]
 * to retrieve the MAC address of this interface.
 */
static VALUE libvirt_interface_mac(VALUE i)
{
    ruby_libvirt_generate_call_string(virInterfaceGetMACString,
                                      ruby_libvirt_connect_get(i),
                                      0, interface_get(i));
}

/*
 * call-seq:
 *   interface.xml_desc -> String
 *
 * Call virInterfaceGetXMLDesc[https://libvirt.org/html/libvirt-libvirt-interface.html#virInterfaceGetXMLDesc]
 * to retrieve the XML of this interface.
 */
static VALUE libvirt_interface_xml_desc(int argc, VALUE *argv, VALUE i)
{
    VALUE flags = RUBY_Qnil;

    rb_scan_args(argc, argv, "01", &flags);

    ruby_libvirt_generate_call_string(virInterfaceGetXMLDesc,
                                      ruby_libvirt_connect_get(i),
                                      1, interface_get(i),
                                      ruby_libvirt_value_to_uint(flags));
}

/*
 * call-seq:
 *   interface.free -> nil
 *
 * Call virInterfaceFree[https://libvirt.org/html/libvirt-libvirt-interface.html#virInterfaceFree]
 * to free this interface.  The object will no longer be valid after this call.
 */
static VALUE libvirt_interface_free(VALUE i)
{
    ruby_libvirt_generate_call_free(Interface, i);
}

/*
 * Class Libvirt::Interface
 */
void ruby_libvirt_interface_init(void)
{
    c_interface = rb_define_class_under(m_libvirt, "Interface", rb_cObject);
    rb_undef_alloc_func(c_interface);
    rb_define_singleton_method(c_interface, "new",
                               ruby_libvirt_new_not_allowed, -1);

    rb_define_const(c_interface, "XML_INACTIVE",
                    INT2NUM(VIR_INTERFACE_XML_INACTIVE));
    rb_define_attr(c_interface, "connection", 1, 0);

    /* Interface object methods */
    rb_define_method(c_interface, "name", libvirt_interface_name, 0);
    rb_define_method(c_interface, "mac", libvirt_interface_mac, 0);
    rb_define_method(c_interface, "xml_desc", libvirt_interface_xml_desc, -1);
    rb_define_method(c_interface, "undefine", libvirt_interface_undefine, 0);
    rb_define_method(c_interface, "create", libvirt_interface_create, -1);
    rb_define_method(c_interface, "destroy", libvirt_interface_destroy, -1);
    rb_define_method(c_interface, "free", libvirt_interface_free, 0);
    rb_define_method(c_interface, "active?", libvirt_interface_active_p, 0);
}
