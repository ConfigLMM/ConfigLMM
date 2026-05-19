/*
 * nwfilter.c: virNWFilter methods
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

static VALUE c_nwfilter;

static void nwfilter_free(void *n)
{
    ruby_libvirt_free_struct(NWFilter, n);
}

static virNWFilterPtr nwfilter_get(VALUE n)
{
    ruby_libvirt_get_struct(NWFilter, n);
}

VALUE ruby_libvirt_nwfilter_new(virNWFilterPtr n, VALUE conn)
{
    return ruby_libvirt_new_class(c_nwfilter, n, conn, nwfilter_free);
}

/*
 * call-seq:
 *   nwfilter.undefine -> nil
 *
 * Call virNWFilterUndefine[https://libvirt.org/html/libvirt-libvirt-nwfilter.html#virNWFilterUndefine]
 * to undefine the network filter.
 */
static VALUE libvirt_nwfilter_undefine(VALUE n)
{
    ruby_libvirt_generate_call_nil(virNWFilterUndefine,
                                   ruby_libvirt_connect_get(n),
                                   nwfilter_get(n));
}

/*
 * call-seq:
 *   nwfilter.name -> String
 *
 * Call virNWFilterGetName[https://libvirt.org/html/libvirt-libvirt-nwfilter.html#virNWFilterGetName]
 * to retrieve the network filter name.
 */
static VALUE libvirt_nwfilter_name(VALUE n)
{
    ruby_libvirt_generate_call_string(virNWFilterGetName,
                                      ruby_libvirt_connect_get(n), 0,
                                      nwfilter_get(n));
}

/*
 * call-seq:
 *   nwfilter.uuid -> String
 *
 * Call virNWFilterGetUUIDString[https://libvirt.org/html/libvirt-libvirt-nwfilter.html#virNWFilterGetUUIDString]
 * to retrieve the network filter UUID.
 */
static VALUE libvirt_nwfilter_uuid(VALUE n)
{
    ruby_libvirt_generate_uuid(virNWFilterGetUUIDString,
                               ruby_libvirt_connect_get(n), nwfilter_get(n));
}

/*
 * call-seq:
 *   nwfilter.xml_desc(flags=0) -> String
 *
 * Call virNWFilterGetXMLDesc[https://libvirt.org/html/libvirt-libvirt-nwfilter.html#virNWFilterGetXMLDesc]
 * to retrieve the XML for this network filter.
 */
static VALUE libvirt_nwfilter_xml_desc(int argc, VALUE *argv, VALUE n)
{
    VALUE flags = RUBY_Qnil;

    rb_scan_args(argc, argv, "01", &flags);

    ruby_libvirt_generate_call_string(virNWFilterGetXMLDesc,
                                      ruby_libvirt_connect_get(n), 1,
                                      nwfilter_get(n),
                                      ruby_libvirt_value_to_uint(flags));
}

/*
 * call-seq:
 *   nwfilter.free -> nil
 *
 * Call virNWFilterFree[https://libvirt.org/html/libvirt-libvirt-nwfilter.html#virNWFilterFree]
 * to free this network filter.  After this call the network filter object is
 * no longer valid.
 */
static VALUE libvirt_nwfilter_free(VALUE n)
{
    ruby_libvirt_generate_call_free(NWFilter, n);
}


/*
 * Class Libvirt::NWFilter
 */
void ruby_libvirt_nwfilter_init(void)
{
    c_nwfilter = rb_define_class_under(m_libvirt, "NWFilter", rb_cObject);
    rb_undef_alloc_func(c_nwfilter);
    rb_define_singleton_method(c_nwfilter, "new",
                               ruby_libvirt_new_not_allowed, -1);

    rb_define_attr(c_nwfilter, "connection", 1, 0);

    /* NWFilter object methods */
    rb_define_method(c_nwfilter, "undefine", libvirt_nwfilter_undefine, 0);
    rb_define_method(c_nwfilter, "name", libvirt_nwfilter_name, 0);
    rb_define_method(c_nwfilter, "uuid", libvirt_nwfilter_uuid, 0);
    rb_define_method(c_nwfilter, "xml_desc", libvirt_nwfilter_xml_desc, -1);
    rb_define_method(c_nwfilter, "free", libvirt_nwfilter_free, 0);
}
