/*
 * storage.c: virStoragePool and virStorageVolume methods
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
#include "stream.h"

/* this has to be here (as opposed to below with the rest of the volume
 * stuff) because libvirt_storage_vol_get_pool() relies on it
 */
static virStorageVolPtr vol_get(VALUE v)
{
    ruby_libvirt_get_struct(StorageVol, v);
}

static VALUE c_storage_pool;
static VALUE c_storage_pool_info;

/*
 * Class Libvirt::StoragePool
 */

static void pool_free(void *d)
{
    ruby_libvirt_free_struct(StoragePool, d);
}

static virStoragePoolPtr pool_get(VALUE p)
{
    ruby_libvirt_get_struct(StoragePool, p);
}

VALUE pool_new(virStoragePoolPtr p, VALUE conn)
{
    return ruby_libvirt_new_class(c_storage_pool, p, conn, pool_free);
}

/*
 * call-seq:
 *   vol.pool -> Libvirt::StoragePool
 *
 * Call virStoragePoolLookupByVolume[https://libvirt.org/html/libvirt-libvirt-storage.html#virStoragePoolLookupByVolume]
 * to retrieve the storage pool for this volume.
 */
static VALUE libvirt_storage_vol_pool(VALUE v)
{
    virStoragePoolPtr pool;

    pool = virStoragePoolLookupByVolume(vol_get(v));
    ruby_libvirt_raise_error_if(pool == NULL, e_RetrieveError,
                                "virStoragePoolLookupByVolume",
                                ruby_libvirt_connect_get(v));

    return pool_new(pool, ruby_libvirt_conn_attr(v));
}

/*
 * call-seq:
 *   pool.build(flags=0) -> nil
 *
 * Call virStoragePoolBuild[https://libvirt.org/html/libvirt-libvirt-storage.html#virStoragePoolBuild]
 * to build this storage pool.
 */
static VALUE libvirt_storage_pool_build(int argc, VALUE *argv, VALUE p)
{
    VALUE flags = RUBY_Qnil;

    rb_scan_args(argc, argv, "01", &flags);

    ruby_libvirt_generate_call_nil(virStoragePoolBuild,
                                   ruby_libvirt_connect_get(p),
                                   pool_get(p),
                                   ruby_libvirt_value_to_uint(flags));
}

/*
 * call-seq:
 *   pool.undefine -> nil
 *
 * Call virStoragePoolUndefine[https://libvirt.org/html/libvirt-libvirt-storage.html#virStoragePoolUndefine]
 * to undefine this storage pool.
 */
static VALUE libvirt_storage_pool_undefine(VALUE p)
{
    ruby_libvirt_generate_call_nil(virStoragePoolUndefine,
                                   ruby_libvirt_connect_get(p),
                                   pool_get(p));
}

/*
 * call-seq:
 *   pool.create(flags=0) -> nil
 *
 * Call virStoragePoolCreate[https://libvirt.org/html/libvirt-libvirt-storage.html#virStoragePoolCreate]
 * to start this storage pool.
 */
static VALUE libvirt_storage_pool_create(int argc, VALUE *argv, VALUE p)
{
    VALUE flags = RUBY_Qnil;

    rb_scan_args(argc, argv, "01", &flags);

    ruby_libvirt_generate_call_nil(virStoragePoolCreate,
                                   ruby_libvirt_connect_get(p),
                                   pool_get(p),
                                   ruby_libvirt_value_to_uint(flags));
}

/*
 * call-seq:
 *   pool.destroy -> nil
 *
 * Call virStoragePoolDestroy[https://libvirt.org/html/libvirt-libvirt-storage.html#virStoragePoolDestroy]
 * to shutdown this storage pool.
 */
static VALUE libvirt_storage_pool_destroy(VALUE p)
{
    ruby_libvirt_generate_call_nil(virStoragePoolDestroy,
                                   ruby_libvirt_connect_get(p),
                                   pool_get(p));
}

/*
 * call-seq:
 *   pool.delete(flags=0) -> nil
 *
 * Call virStoragePoolDelete[https://libvirt.org/html/libvirt-libvirt-storage.html#virStoragePoolDelete]
 * to delete the data corresponding to this data pool.  This is a destructive
 * operation.
 */
static VALUE libvirt_storage_pool_delete(int argc, VALUE *argv, VALUE p)
{
    VALUE flags = RUBY_Qnil;

    rb_scan_args(argc, argv, "01", &flags);

    ruby_libvirt_generate_call_nil(virStoragePoolDelete,
                                   ruby_libvirt_connect_get(p),
                                   pool_get(p),
                                   ruby_libvirt_value_to_uint(flags));
}

/*
 * call-seq:
 *   pool.refresh(flags=0) -> nil
 *
 * Call virStoragePoolRefresh[https://libvirt.org/html/libvirt-libvirt-storage.html#virStoragePoolRefresh]
 * to refresh the list of volumes in this storage pool.
 */
static VALUE libvirt_storage_pool_refresh(int argc, VALUE *argv, VALUE p)
{
    VALUE flags = RUBY_Qnil;

    rb_scan_args(argc, argv, "01", &flags);

    ruby_libvirt_generate_call_nil(virStoragePoolRefresh,
                                   ruby_libvirt_connect_get(p),
                                   pool_get(p),
                                   ruby_libvirt_value_to_uint(flags));
}

/*
 * call-seq:
 *   pool.name -> String
 *
 * Call virStoragePoolGetName[https://libvirt.org/html/libvirt-libvirt-storage.html#virStoragePoolGetName]
 * to retrieve the name of this storage pool.
 */
static VALUE libvirt_storage_pool_name(VALUE p)
{
    ruby_libvirt_generate_call_string(virStoragePoolGetName,
                                      ruby_libvirt_connect_get(p), 0,
                                      pool_get(p));
}

/*
 * call-seq:
 *   pool.uuid -> String
 *
 * Call virStoragePoolGetUUIDString[https://libvirt.org/html/libvirt-libvirt-storage.html#virStoragePoolGetUUIDString]
 * to retrieve the UUID of this storage pool.
 */
static VALUE libvirt_storage_pool_uuid(VALUE p)
{
    ruby_libvirt_generate_uuid(virStoragePoolGetUUIDString,
                               ruby_libvirt_connect_get(p), pool_get(p));
}

/*
 * call-seq:
 *   pool.info -> Libvirt::StoragePoolInfo
 *
 * Call virStoragePoolGetInfo[https://libvirt.org/html/libvirt-libvirt-storage.html#virStoragePoolGetInfo]
 * to retrieve information about this storage pool.
 */
static VALUE libvirt_storage_pool_info(VALUE p)
{
    virStoragePoolInfo info;
    int r;
    VALUE result;

    r = virStoragePoolGetInfo(pool_get(p), &info);
    ruby_libvirt_raise_error_if(r < 0, e_RetrieveError,
                                "virStoragePoolGetInfo",
                                ruby_libvirt_connect_get(p));

    result = rb_class_new_instance(0, NULL, c_storage_pool_info);
    rb_iv_set(result, "@state", INT2NUM(info.state));
    rb_iv_set(result, "@capacity", ULL2NUM(info.capacity));
    rb_iv_set(result, "@allocation", ULL2NUM(info.allocation));
    rb_iv_set(result, "@available", ULL2NUM(info.available));

    return result;
}

/*
 * call-seq:
 *   pool.xml_desc(flags=0) -> String
 *
 * Call virStoragePoolGetXMLDesc[https://libvirt.org/html/libvirt-libvirt-storage.html#virStoragePoolGetXMLDesc]
 * to retrieve the XML for this storage pool.
 */
static VALUE libvirt_storage_pool_xml_desc(int argc, VALUE *argv, VALUE p)
{
    VALUE flags = RUBY_Qnil;

    rb_scan_args(argc, argv, "01", &flags);

    ruby_libvirt_generate_call_string(virStoragePoolGetXMLDesc,
                                      ruby_libvirt_connect_get(p),
                                      1, pool_get(p),
                                      ruby_libvirt_value_to_uint(flags));
}

/*
 * call-seq:
 *   pool.autostart? -> [true|false]
 *
 * Call virStoragePoolGetAutostart[https://libvirt.org/html/libvirt-libvirt-storage.html#virStoragePoolGetAutostart]
 * to determine whether this storage pool will autostart when libvirtd starts.
 */
static VALUE libvirt_storage_pool_autostart(VALUE p)
{
    int r, autostart;

    r = virStoragePoolGetAutostart(pool_get(p), &autostart);
    ruby_libvirt_raise_error_if(r < 0, e_RetrieveError,
                                "virStoragePoolGetAutostart",
                                ruby_libvirt_connect_get(p));

    return autostart ? Qtrue : Qfalse;
}

/*
 * call-seq:
 *   pool.autostart = [true|false]
 *
 * Call virStoragePoolSetAutostart[https://libvirt.org/html/libvirt-libvirt-storage.html#virStoragePoolSetAutostart]
 * to make this storage pool start when libvirtd starts.
 */
static VALUE libvirt_storage_pool_autostart_equal(VALUE p, VALUE autostart)
{
    if (autostart != Qtrue && autostart != Qfalse) {
		rb_raise(rb_eTypeError,
                 "wrong argument type (expected TrueClass or FalseClass)");
    }

    ruby_libvirt_generate_call_nil(virStoragePoolSetAutostart,
                                   ruby_libvirt_connect_get(p),
                                   pool_get(p), RTEST(autostart) ? 1 : 0);
}

/*
 * call-seq:
 *   pool.num_of_volumes -> Fixnum
 *
 * Call virStoragePoolNumOfVolumes[https://libvirt.org/html/libvirt-libvirt-storage.html#virStoragePoolNumOfVolumes]
 * to retrieve the number of volumes in this storage pool.
 */
static VALUE libvirt_storage_pool_num_of_volumes(VALUE p)
{
    int n;

    n = virStoragePoolNumOfVolumes(pool_get(p));
    ruby_libvirt_raise_error_if(n < 0, e_RetrieveError,
                                "virStoragePoolNumOfVolumes",
                                ruby_libvirt_connect_get(p));

    return INT2NUM(n);
}

/*
 * call-seq:
 *   pool.list_volumes -> list
 *
 * Call virStoragePoolListVolumes[https://libvirt.org/html/libvirt-libvirt-storage.html#virStoragePoolListVolumes]
 * to retrieve a list of volume names in this storage pools.
 */
static VALUE libvirt_storage_pool_list_volumes(VALUE p)
{
    int r, num;
    char **names;

    num = virStoragePoolNumOfVolumes(pool_get(p));
    ruby_libvirt_raise_error_if(num < 0, e_RetrieveError,
                                "virStoragePoolNumOfVolumes",
                                ruby_libvirt_connect_get(p));
    if (num == 0) {
        return rb_ary_new2(num);
    }

    names = alloca(sizeof(char *) * num);
    r = virStoragePoolListVolumes(pool_get(p), names, num);
    ruby_libvirt_raise_error_if(r < 0, e_RetrieveError,
                                "virStoragePoolListVolumes",
                                ruby_libvirt_connect_get(p));

    return ruby_libvirt_generate_list(r, names);
}

/*
 * call-seq:
 *   pool.free -> nil
 *
 * Call virStoragePoolFree[https://libvirt.org/html/libvirt-libvirt-storage.html#virStoragePoolFree]
 * to free this storage pool object.  After this call the storage pool object
 * is no longer valid.
 */
static VALUE libvirt_storage_pool_free(VALUE p)
{
    ruby_libvirt_generate_call_free(StoragePool, p);
}

/*
 * Libvirt::StorageVol
 */
static VALUE c_storage_vol;
static VALUE c_storage_vol_info;

static void vol_free(void *d)
{
    ruby_libvirt_free_struct(StorageVol, d);
}

static VALUE vol_new(virStorageVolPtr v, VALUE conn)
{
    return ruby_libvirt_new_class(c_storage_vol, v, conn, vol_free);
}

/*
 * call-seq:
 *   pool.lookup_volume_by_name(name) -> Libvirt::StorageVol
 *
 * Call virStorageVolLookupByName[https://libvirt.org/html/libvirt-libvirt-storage.html#virStorageVolLookupByName]
 * to retrieve a storage volume object by name.
 */
static VALUE libvirt_storage_pool_lookup_vol_by_name(VALUE p, VALUE name)
{
    virStorageVolPtr vol;

    vol = virStorageVolLookupByName(pool_get(p), StringValueCStr(name));
    ruby_libvirt_raise_error_if(vol == NULL, e_RetrieveError,
                                "virStorageVolLookupByName",
                                ruby_libvirt_connect_get(p));

    return vol_new(vol, ruby_libvirt_conn_attr(p));
}

/*
 * call-seq:
 *   pool.lookup_volume_by_key(key) -> Libvirt::StorageVol
 *
 * Call virStorageVolLookupByKey[https://libvirt.org/html/libvirt-libvirt-storage.html#virStorageVolLookupByKey]
 * to retrieve a storage volume object by key.
 */
static VALUE libvirt_storage_pool_lookup_vol_by_key(VALUE p, VALUE key)
{
    virStorageVolPtr vol;

    /* FIXME: Why does this take a connection, not a pool? */
    vol = virStorageVolLookupByKey(ruby_libvirt_connect_get(p),
                                   StringValueCStr(key));
    ruby_libvirt_raise_error_if(vol == NULL, e_RetrieveError,
                                "virStorageVolLookupByKey",
                                ruby_libvirt_connect_get(p));

    return vol_new(vol, ruby_libvirt_conn_attr(p));
}

/*
 * call-seq:
 *   pool.lookup_volume_by_path(path) -> Libvirt::StorageVol
 *
 * Call virStorageVolLookupByPath[https://libvirt.org/html/libvirt-libvirt-storage.html#virStorageVolLookupByPath]
 * to retrieve a storage volume object by path.
 */
static VALUE libvirt_storage_pool_lookup_vol_by_path(VALUE p, VALUE path)
{
    virStorageVolPtr vol;

    /* FIXME: Why does this take a connection, not a pool? */
    vol = virStorageVolLookupByPath(ruby_libvirt_connect_get(p),
                                    StringValueCStr(path));
    ruby_libvirt_raise_error_if(vol == NULL, e_RetrieveError,
                                "virStorageVolLookupByPath",
                                ruby_libvirt_connect_get(p));

    return vol_new(vol, ruby_libvirt_conn_attr(p));
}

/*
 * call-seq:
 *   pool.list_all_volumes(flags=0) -> Array
 *
 * Call virStoragePoolListAllVolumes[https://libvirt.org/html/libvirt-libvirt-storage.html#virStoragePoolListAllVolumes]
 * to get an array of volume objects for all volumes.
 */
static VALUE libvirt_storage_pool_list_all_volumes(int argc, VALUE *argv,
                                                   VALUE p)
{
    ruby_libvirt_generate_call_list_all(virStorageVolPtr, argc, argv,
                                        virStoragePoolListAllVolumes,
                                        pool_get(p), ruby_libvirt_conn_attr(p),
                                        vol_new, virStorageVolFree);
}

/*
 * call-seq:
 *   vol.name -> String
 *
 * Call virStorageVolGetName[https://libvirt.org/html/libvirt-libvirt-storage.html#virStorageVolGetName]
 * to retrieve the name of this storage volume.
 */
static VALUE libvirt_storage_vol_name(VALUE v)
{
    ruby_libvirt_generate_call_string(virStorageVolGetName,
                                      ruby_libvirt_connect_get(v), 0,
                                      vol_get(v));
}

/*
 * call-seq:
 *   vol.key -> String
 *
 * Call virStorageVolGetKey[https://libvirt.org/html/libvirt-libvirt-storage.html#virStorageVolGetKey]
 * to retrieve the key for this storage volume.
 */
static VALUE libvirt_storage_vol_key(VALUE v)
{
    ruby_libvirt_generate_call_string(virStorageVolGetKey,
                                      ruby_libvirt_connect_get(v), 0,
                                      vol_get(v));
}

/*
 * call-seq:
 *   pool.create_volume_xml(xml, flags=0) -> Libvirt::StorageVol
 *
 * Call virStorageVolCreateXML[https://libvirt.org/html/libvirt-libvirt-storage.html#virStorageVolCreateXML]
 * to create a new storage volume from xml.
 */
static VALUE libvirt_storage_pool_create_volume_xml(int argc, VALUE *argv,
                                                    VALUE p)
{
    virStorageVolPtr vol;
    VALUE xml, flags = RUBY_Qnil;

    rb_scan_args(argc, argv, "11", &xml, &flags);

    vol = virStorageVolCreateXML(pool_get(p), StringValueCStr(xml),
                                 ruby_libvirt_value_to_uint(flags));
    ruby_libvirt_raise_error_if(vol == NULL, e_Error, "virStorageVolCreateXML",
                                ruby_libvirt_connect_get(p));

    return vol_new(vol, ruby_libvirt_conn_attr(p));
}

/*
 * call-seq:
 *   pool.create_volume_xml_from(xml, clonevol, flags=0) -> Libvirt::StorageVol
 *
 * Call virStorageVolCreateXMLFrom[https://libvirt.org/html/libvirt-libvirt-storage.html#virStorageVolCreateXMLFrom]
 * to clone a volume from an existing volume with the properties specified in
 * xml.
 */
static VALUE libvirt_storage_pool_create_volume_xml_from(int argc, VALUE *argv,
                                                         VALUE p)
{
    virStorageVolPtr vol;
    VALUE xml, flags = RUBY_Qnil, cloneval = RUBY_Qnil;

    rb_scan_args(argc, argv, "21", &xml, &cloneval, &flags);

    vol = virStorageVolCreateXMLFrom(pool_get(p), StringValueCStr(xml),
                                     vol_get(cloneval),
                                     ruby_libvirt_value_to_uint(flags));
    ruby_libvirt_raise_error_if(vol == NULL, e_Error,
                                "virStorageVolCreateXMLFrom",
                                ruby_libvirt_connect_get(p));

    return vol_new(vol, ruby_libvirt_conn_attr(p));
}

/*
 * call-seq:
 *   pool.active? -> [true|false]
 *
 * Call virStoragePoolIsActive[https://libvirt.org/html/libvirt-libvirt-storage.html#virStoragePoolIsActive]
 * to determine if this storage pool is active.
 */
static VALUE libvirt_storage_pool_active_p(VALUE p)
{
    ruby_libvirt_generate_call_truefalse(virStoragePoolIsActive,
                                         ruby_libvirt_connect_get(p),
                                         pool_get(p));
}

/*
 * call-seq:
 *   pool.persistent? -> [true|false]
 *
 * Call virStoragePoolIsPersistent[https://libvirt.org/html/libvirt-libvirt-storage.html#virStoragePoolIsPersistent]
 * to determine if this storage pool is persistent.
 */
static VALUE libvirt_storage_pool_persistent_p(VALUE p)
{
    ruby_libvirt_generate_call_truefalse(virStoragePoolIsPersistent,
                                         ruby_libvirt_connect_get(p),
                                         pool_get(p));
}

/*
 * call-seq:
 *   vol.delete(flags=0) -> nil
 *
 * Call virStorageVolDelete[https://libvirt.org/html/libvirt-libvirt-storage.html#virStorageVolDelete]
 * to delete this volume.  This is a destructive operation.
 */
static VALUE libvirt_storage_vol_delete(int argc, VALUE *argv, VALUE v)
{
    VALUE flags = RUBY_Qnil;

    rb_scan_args(argc, argv, "01", &flags);

    ruby_libvirt_generate_call_nil(virStorageVolDelete,
                                   ruby_libvirt_connect_get(v),
                                   vol_get(v),
                                   ruby_libvirt_value_to_uint(flags));
}

/*
 * call-seq:
 *   vol.wipe(flags=0) -> nil
 *
 * Call virStorageVolWipe[https://libvirt.org/html/libvirt-libvirt-storage.html#virStorageVolWipe]
 * to wipe the data from this storage volume.  This is a destructive operation.
 */
static VALUE libvirt_storage_vol_wipe(int argc, VALUE *argv, VALUE v)
{
    VALUE flags = RUBY_Qnil;

    rb_scan_args(argc, argv, "01", &flags);

    ruby_libvirt_generate_call_nil(virStorageVolWipe,
                                   ruby_libvirt_connect_get(v),
                                   vol_get(v),
                                   ruby_libvirt_value_to_uint(flags));
}

/*
 * call-seq:
 *   vol.info -> Libvirt::StorageVolInfo
 *
 * Call virStorageVolGetInfo[https://libvirt.org/html/libvirt-libvirt-storage.html#virStorageVolGetInfo]
 * to retrieve information about this storage volume.
 */
static VALUE libvirt_storage_vol_info(VALUE v)
{
    virStorageVolInfo info;
    int r;
    VALUE result;

    r = virStorageVolGetInfo(vol_get(v), &info);
    ruby_libvirt_raise_error_if(r < 0, e_RetrieveError, "virStorageVolGetInfo",
                                ruby_libvirt_connect_get(v));

    result = rb_class_new_instance(0, NULL, c_storage_vol_info);
    rb_iv_set(result, "@type", INT2NUM(info.type));
    rb_iv_set(result, "@capacity", ULL2NUM(info.capacity));
    rb_iv_set(result, "@allocation", ULL2NUM(info.allocation));

    return result;
}

/*
 * call-seq:
 *   vol.xml_desc(flags=0) -> String
 *
 * Call virStorageVolGetXMLDesc[https://libvirt.org/html/libvirt-libvirt-storage.html#virStorageVolGetXMLDesc]
 * to retrieve the xml for this storage volume.
 */
static VALUE libvirt_storage_vol_xml_desc(int argc, VALUE *argv, VALUE v)
{
    VALUE flags = RUBY_Qnil;

    rb_scan_args(argc, argv, "01", &flags);

    ruby_libvirt_generate_call_string(virStorageVolGetXMLDesc,
                                      ruby_libvirt_connect_get(v),
                                      1, vol_get(v),
                                      ruby_libvirt_value_to_uint(flags));
}

/*
 * call-seq:
 *   vol.path -> String
 *
 * Call virStorageVolGetPath[https://libvirt.org/html/libvirt-libvirt-storage.html#virStorageVolGetPath]
 * to retrieve the path for this storage volume.
 */
static VALUE libvirt_storage_vol_path(VALUE v)
{
    ruby_libvirt_generate_call_string(virStorageVolGetPath,
                                      ruby_libvirt_connect_get(v), 1,
                                      vol_get(v));
}

/*
 * call-seq:
 *   vol.free -> nil
 *
 * Call virStorageVolFree[https://libvirt.org/html/libvirt-libvirt-storage.html#virStorageVolFree]
 * to free the storage volume object.  After this call the storage volume object
 * is no longer valid.
 */
static VALUE libvirt_storage_vol_free(VALUE v)
{
    ruby_libvirt_generate_call_free(StorageVol, v);
}

/*
 * call-seq:
 *   vol.download(stream, offset, length, flags=0) -> nil
 *
 * Call virStorageVolDownload[https://libvirt.org/html/libvirt-libvirt-storage.html#virStorageVolDownload]
 * to download the content of a volume as a stream.
 */
static VALUE libvirt_storage_vol_download(int argc, VALUE *argv, VALUE v)
{
    VALUE st = RUBY_Qnil, offset = RUBY_Qnil, length = RUBY_Qnil, flags = RUBY_Qnil;

    rb_scan_args(argc, argv, "31", &st, &offset, &length, &flags);

    ruby_libvirt_generate_call_nil(virStorageVolDownload,
                                   ruby_libvirt_connect_get(v),
                                   vol_get(v), ruby_libvirt_stream_get(st),
                                   NUM2ULL(offset), NUM2ULL(length),
                                   ruby_libvirt_value_to_uint(flags));
}

/*
 * call-seq:
 *   vol.upload(stream, offset, length, flags=0) -> nil
 *
 * Call virStorageVolUpload[https://libvirt.org/html/libvirt-libvirt-storage.html#virStorageVolUpload]
 * to upload new content to a volume from a stream.
 */
static VALUE libvirt_storage_vol_upload(int argc, VALUE *argv, VALUE v)
{
    VALUE st = RUBY_Qnil, offset = RUBY_Qnil, length = RUBY_Qnil, flags = RUBY_Qnil;

    rb_scan_args(argc, argv, "31", &st, &offset, &length, &flags);

    ruby_libvirt_generate_call_nil(virStorageVolUpload,
                                   ruby_libvirt_connect_get(v),
                                   vol_get(v), ruby_libvirt_stream_get(st),
                                   NUM2ULL(offset), NUM2ULL(length),
                                   ruby_libvirt_value_to_uint(flags));
}

/*
 * call-seq:
 *   vol.wipe_pattern(alg, flags=0) -> nil
 *
 * Call virStorageVolWipePattern[https://libvirt.org/html/libvirt-libvirt-storage.html#virStorageVolWipePattern]
 * to wipe the data from this storage volume.  This is a destructive operation.
 */
static VALUE libvirt_storage_vol_wipe_pattern(int argc, VALUE *argv, VALUE v)
{
    VALUE alg = RUBY_Qnil, flags = RUBY_Qnil;

    rb_scan_args(argc, argv, "11", &alg, &flags);

    ruby_libvirt_generate_call_nil(virStorageVolWipePattern,
                                   ruby_libvirt_connect_get(v),
                                   vol_get(v), NUM2UINT(alg),
                                   ruby_libvirt_value_to_uint(flags));
}

/*
 * call-seq:
 *   vol.resize(capacity, flags=0) -> nil
 *
 * Call virStorageVolResize[https://libvirt.org/html/libvirt-libvirt-storage.html#virStorageVolResize]
 * to resize the associated storage volume.
 */
static VALUE libvirt_storage_vol_resize(int argc, VALUE *argv, VALUE v)
{
    VALUE capacity = RUBY_Qnil, flags = RUBY_Qnil;

    rb_scan_args(argc, argv, "11", &capacity, &flags);

    ruby_libvirt_generate_call_nil(virStorageVolResize,
                                   ruby_libvirt_connect_get(v),
                                   vol_get(v), NUM2ULL(capacity),
                                   ruby_libvirt_value_to_uint(flags));
}

void ruby_libvirt_storage_init(void)
{
    /*
     * Class Libvirt::StoragePool and Libvirt::StoragePoolInfo
     */
    c_storage_pool_info = rb_define_class_under(m_libvirt, "StoragePoolInfo",
                                                rb_cObject);
    rb_define_attr(c_storage_pool_info, "state", 1, 0);
    rb_define_attr(c_storage_pool_info, "capacity", 1, 0);
    rb_define_attr(c_storage_pool_info, "allocation", 1, 0);
    rb_define_attr(c_storage_pool_info, "available", 1, 0);

    c_storage_pool = rb_define_class_under(m_libvirt, "StoragePool",
                                           rb_cObject);
    rb_undef_alloc_func(c_storage_pool);
    rb_define_singleton_method(c_storage_pool, "new",
                               ruby_libvirt_new_not_allowed, -1);

    rb_define_attr(c_storage_pool, "connection", 1, 0);

    /* virStoragePoolState */
    rb_define_const(c_storage_pool, "INACTIVE",
                    INT2NUM(VIR_STORAGE_POOL_INACTIVE));
    rb_define_const(c_storage_pool, "BUILDING",
                    INT2NUM(VIR_STORAGE_POOL_BUILDING));
    rb_define_const(c_storage_pool, "RUNNING",
                    INT2NUM(VIR_STORAGE_POOL_RUNNING));
    rb_define_const(c_storage_pool, "DEGRADED",
                    INT2NUM(VIR_STORAGE_POOL_DEGRADED));
    rb_define_const(c_storage_pool, "INACCESSIBLE",
                    INT2NUM(VIR_STORAGE_POOL_INACCESSIBLE));

    rb_define_const(c_storage_pool, "XML_INACTIVE",
                    INT2NUM(VIR_STORAGE_XML_INACTIVE));

    /* virStoragePoolBuildFlags */
    rb_define_const(c_storage_pool, "BUILD_NEW",
                    INT2NUM(VIR_STORAGE_POOL_BUILD_NEW));
    rb_define_const(c_storage_pool, "BUILD_REPAIR",
                    INT2NUM(VIR_STORAGE_POOL_BUILD_REPAIR));
    rb_define_const(c_storage_pool, "BUILD_RESIZE",
                    INT2NUM(VIR_STORAGE_POOL_BUILD_RESIZE));

    /* virStoragePoolDeleteFlags */
    rb_define_const(c_storage_pool, "DELETE_NORMAL",
                    INT2NUM(VIR_STORAGE_POOL_DELETE_NORMAL));
    rb_define_const(c_storage_pool, "DELETE_ZEROED",
                    INT2NUM(VIR_STORAGE_POOL_DELETE_ZEROED));

    rb_define_const(c_storage_pool, "CREATE_PREALLOC_METADATA",
                    INT2NUM(VIR_STORAGE_VOL_CREATE_PREALLOC_METADATA));
    rb_define_const(c_storage_pool, "CREATE_REFLINK",
                    INT2NUM(VIR_STORAGE_VOL_CREATE_REFLINK));

    rb_define_const(c_storage_pool, "CREATE_NORMAL",
                    INT2NUM(VIR_STORAGE_POOL_CREATE_NORMAL));
    rb_define_const(c_storage_pool, "CREATE_WITH_BUILD",
                    INT2NUM(VIR_STORAGE_POOL_CREATE_WITH_BUILD));
    rb_define_const(c_storage_pool, "CREATE_WITH_BUILD_OVERWRITE",
                    INT2NUM(VIR_STORAGE_POOL_CREATE_WITH_BUILD_OVERWRITE));
    rb_define_const(c_storage_pool, "CREATE_WITH_BUILD_NO_OVERWRITE",
                    INT2NUM(VIR_STORAGE_POOL_CREATE_WITH_BUILD_NO_OVERWRITE));

    /* Creating/destroying pools */
    rb_define_method(c_storage_pool, "build", libvirt_storage_pool_build, -1);
    rb_define_method(c_storage_pool, "undefine", libvirt_storage_pool_undefine,
                     0);
    rb_define_method(c_storage_pool, "create", libvirt_storage_pool_create, -1);
    rb_define_method(c_storage_pool, "destroy", libvirt_storage_pool_destroy,
                     0);
    rb_define_method(c_storage_pool, "delete", libvirt_storage_pool_delete, -1);
    rb_define_method(c_storage_pool, "refresh", libvirt_storage_pool_refresh,
                     -1);
    /* StoragePool information */
    rb_define_method(c_storage_pool, "name", libvirt_storage_pool_name, 0);
    rb_define_method(c_storage_pool, "uuid", libvirt_storage_pool_uuid, 0);
    rb_define_method(c_storage_pool, "info", libvirt_storage_pool_info, 0);
    rb_define_method(c_storage_pool, "xml_desc", libvirt_storage_pool_xml_desc,
                     -1);
    rb_define_method(c_storage_pool, "autostart",
                     libvirt_storage_pool_autostart, 0);
    rb_define_method(c_storage_pool, "autostart?",
                     libvirt_storage_pool_autostart, 0);
    rb_define_method(c_storage_pool, "autostart=",
                     libvirt_storage_pool_autostart_equal, 1);
    /* List/lookup storage volumes within a pool */
    rb_define_method(c_storage_pool, "num_of_volumes",
                     libvirt_storage_pool_num_of_volumes, 0);
    rb_define_method(c_storage_pool, "list_volumes",
                     libvirt_storage_pool_list_volumes, 0);
    /* Lookup volumes based on various attributes */
    rb_define_method(c_storage_pool, "lookup_volume_by_name",
                     libvirt_storage_pool_lookup_vol_by_name, 1);
    rb_define_method(c_storage_pool, "lookup_volume_by_key",
                     libvirt_storage_pool_lookup_vol_by_key, 1);
    rb_define_method(c_storage_pool, "lookup_volume_by_path",
                     libvirt_storage_pool_lookup_vol_by_path, 1);
    rb_define_method(c_storage_pool, "free", libvirt_storage_pool_free, 0);
    rb_define_method(c_storage_pool, "create_volume_xml",
                     libvirt_storage_pool_create_volume_xml, -1);
    rb_define_alias(c_storage_pool, "create_vol_xml", "create_volume_xml");
    rb_define_method(c_storage_pool, "create_volume_xml_from",
                     libvirt_storage_pool_create_volume_xml_from, -1);
    rb_define_alias(c_storage_pool, "create_vol_xml_from",
                    "create_volume_xml_from");
    rb_define_method(c_storage_pool, "active?", libvirt_storage_pool_active_p,
                     0);
    rb_define_method(c_storage_pool, "persistent?",
                     libvirt_storage_pool_persistent_p, 0);

    rb_define_method(c_storage_pool, "list_all_volumes",
                     libvirt_storage_pool_list_all_volumes, -1);

    rb_define_const(c_storage_pool, "BUILD_NO_OVERWRITE",
                    INT2NUM(VIR_STORAGE_POOL_BUILD_NO_OVERWRITE));
    rb_define_const(c_storage_pool, "BUILD_OVERWRITE",
                    INT2NUM(VIR_STORAGE_POOL_BUILD_OVERWRITE));

    /*
     * Class Libvirt::StorageVol and Libvirt::StorageVolInfo
     */
    c_storage_vol_info = rb_define_class_under(m_libvirt, "StorageVolInfo",
                                               rb_cObject);
    rb_define_attr(c_storage_vol_info, "type", 1, 0);
    rb_define_attr(c_storage_vol_info, "capacity", 1, 0);
    rb_define_attr(c_storage_vol_info, "allocation", 1, 0);

    c_storage_vol = rb_define_class_under(m_libvirt, "StorageVol",
                                          rb_cObject);
    rb_undef_alloc_func(c_storage_vol);
    rb_define_singleton_method(c_storage_vol, "new",
                               ruby_libvirt_new_not_allowed, -1);

    rb_define_const(c_storage_vol, "XML_INACTIVE",
                    INT2NUM(VIR_STORAGE_XML_INACTIVE));

    /* virStorageVolType */
    rb_define_const(c_storage_vol, "FILE", INT2NUM(VIR_STORAGE_VOL_FILE));
    rb_define_const(c_storage_vol, "BLOCK", INT2NUM(VIR_STORAGE_VOL_BLOCK));
    rb_define_const(c_storage_vol, "DIR", INT2NUM(VIR_STORAGE_VOL_DIR));
    rb_define_const(c_storage_vol, "NETWORK", INT2NUM(VIR_STORAGE_VOL_NETWORK));
    rb_define_const(c_storage_vol, "NETDIR", INT2NUM(VIR_STORAGE_VOL_NETDIR));

    /* virStorageVolDeleteFlags */
    rb_define_const(c_storage_vol, "DELETE_NORMAL",
                    INT2NUM(VIR_STORAGE_VOL_DELETE_NORMAL));
    rb_define_const(c_storage_vol, "DELETE_ZEROED",
                    INT2NUM(VIR_STORAGE_VOL_DELETE_ZEROED));
    rb_define_const(c_storage_vol, "DELETE_WITH_SNAPSHOTS",
                    INT2NUM(VIR_STORAGE_VOL_DELETE_WITH_SNAPSHOTS));

    rb_define_method(c_storage_vol, "pool", libvirt_storage_vol_pool, 0);
    rb_define_method(c_storage_vol, "name", libvirt_storage_vol_name, 0);
    rb_define_method(c_storage_vol, "key", libvirt_storage_vol_key, 0);
    rb_define_method(c_storage_vol, "delete", libvirt_storage_vol_delete, -1);
    rb_define_method(c_storage_vol, "wipe", libvirt_storage_vol_wipe, -1);
    rb_define_method(c_storage_vol, "wipe_pattern",
                     libvirt_storage_vol_wipe_pattern, -1);
    rb_define_const(c_storage_vol, "WIPE_ALG_ZERO",
                    INT2NUM(VIR_STORAGE_VOL_WIPE_ALG_ZERO));
    rb_define_const(c_storage_vol, "WIPE_ALG_NNSA",
                    INT2NUM(VIR_STORAGE_VOL_WIPE_ALG_NNSA));
    rb_define_const(c_storage_vol, "WIPE_ALG_DOD",
                    INT2NUM(VIR_STORAGE_VOL_WIPE_ALG_DOD));
    rb_define_const(c_storage_vol, "WIPE_ALG_BSI",
                    INT2NUM(VIR_STORAGE_VOL_WIPE_ALG_BSI));
    rb_define_const(c_storage_vol, "WIPE_ALG_GUTMANN",
                    INT2NUM(VIR_STORAGE_VOL_WIPE_ALG_GUTMANN));
    rb_define_const(c_storage_vol, "WIPE_ALG_SCHNEIER",
                    INT2NUM(VIR_STORAGE_VOL_WIPE_ALG_SCHNEIER));
    rb_define_const(c_storage_vol, "WIPE_ALG_PFITZNER7",
                    INT2NUM(VIR_STORAGE_VOL_WIPE_ALG_PFITZNER7));
    rb_define_const(c_storage_vol, "WIPE_ALG_PFITZNER33",
                    INT2NUM(VIR_STORAGE_VOL_WIPE_ALG_PFITZNER33));
    rb_define_const(c_storage_vol, "WIPE_ALG_RANDOM",
                    INT2NUM(VIR_STORAGE_VOL_WIPE_ALG_RANDOM));

    rb_define_method(c_storage_vol, "info", libvirt_storage_vol_info, 0);
    rb_define_method(c_storage_vol, "xml_desc", libvirt_storage_vol_xml_desc,
                     -1);
    rb_define_method(c_storage_vol, "path", libvirt_storage_vol_path, 0);
    rb_define_method(c_storage_vol, "free", libvirt_storage_vol_free, 0);

    rb_define_method(c_storage_vol, "download", libvirt_storage_vol_download,
                     -1);
    rb_define_method(c_storage_vol, "upload", libvirt_storage_vol_upload, -1);

    rb_define_const(c_storage_vol, "RESIZE_ALLOCATE",
                    INT2NUM(VIR_STORAGE_VOL_RESIZE_ALLOCATE));
    rb_define_const(c_storage_vol, "RESIZE_DELTA",
                    INT2NUM(VIR_STORAGE_VOL_RESIZE_DELTA));
    rb_define_const(c_storage_vol, "RESIZE_SHRINK",
                    INT2NUM(VIR_STORAGE_VOL_RESIZE_SHRINK));
    rb_define_method(c_storage_vol, "resize", libvirt_storage_vol_resize, -1);
}
