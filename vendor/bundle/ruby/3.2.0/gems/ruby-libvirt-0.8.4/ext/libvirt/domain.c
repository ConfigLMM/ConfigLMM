/*
 * domain.c: virDomain methods
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

#include <stdint.h>
#include <unistd.h>
#include <ruby.h>
/* we need to include st.h since ruby 1.8 needs it for RHash */
#include <ruby/st.h>
#include <libvirt/libvirt.h>
#include <libvirt/libvirt-qemu.h>
#include <libvirt/libvirt-lxc.h>
#include <libvirt/virterror.h>
#include "common.h"
#include "connect.h"
#include "extconf.h"
#include "stream.h"

static VALUE c_domain;
static VALUE c_domain_info;
static VALUE c_domain_ifinfo;
VALUE c_domain_security_label;
static VALUE c_domain_block_stats;
static VALUE c_domain_block_info;
static VALUE c_domain_memory_stats;
static VALUE c_domain_snapshot;
static VALUE c_domain_job_info;
static VALUE c_domain_vcpuinfo;
static VALUE c_domain_control_info;
static VALUE c_domain_block_job_info;

static void domain_free(void *d)
{
    ruby_libvirt_free_struct(Domain, d);
}

VALUE ruby_libvirt_domain_new(virDomainPtr d, VALUE conn)
{
    return ruby_libvirt_new_class(c_domain, d, conn, domain_free);
}

virDomainPtr ruby_libvirt_domain_get(VALUE d)
{
    ruby_libvirt_get_struct(Domain, d);
}

static void domain_input_to_fixnum_and_flags(VALUE in, VALUE *hash, VALUE *flags)
{
    if (TYPE(in) == T_FIXNUM) {
        *hash = in;
        *flags = INT2NUM(0);
    }
    else if (TYPE(in) == T_ARRAY) {
        if (RARRAY_LEN(in) != 2) {
            rb_raise(rb_eArgError, "wrong number of arguments (%ld for 2)",
                     RARRAY_LEN(in));
        }
        *hash = rb_ary_entry(in, 0);
        *flags = rb_ary_entry(in, 1);
    }
    else {
        rb_raise(rb_eTypeError,
                 "wrong argument type (expected Number or Array)");
    }
}

/*
 * call-seq:
 *   dom.migrate(dconn, flags=0, dname=nil, uri=nil, bandwidth=0) -> Libvirt::Domain
 *
 * Call virDomainMigrate[https://libvirt.org/html/libvirt-libvirt-domain.html#virDomainMigrate]
 * to migrate a domain from the host on this connection to the connection
 * referenced in dconn.
 */
static VALUE libvirt_domain_migrate(int argc, VALUE *argv, VALUE d)
{
    VALUE dconn, flags, dname, uri, bandwidth;
    virDomainPtr ddom = NULL;

    rb_scan_args(argc, argv, "14", &dconn, &flags, &dname, &uri,
                 &bandwidth);

    ddom = virDomainMigrate(ruby_libvirt_domain_get(d),
                            ruby_libvirt_connect_get(dconn),
                            ruby_libvirt_value_to_ulong(flags),
                            ruby_libvirt_get_cstring_or_null(dname),
                            ruby_libvirt_get_cstring_or_null(uri),
                            ruby_libvirt_value_to_ulong(bandwidth));

    ruby_libvirt_raise_error_if(ddom == NULL, e_Error, "virDomainMigrate",
                                ruby_libvirt_connect_get(d));

    return ruby_libvirt_domain_new(ddom, dconn);
}

/*
 * call-seq:
 *   dom.migrate_to_uri(duri, flags=0, dname=nil, bandwidth=0) -> nil
 *
 * Call virDomainMigrateToURI[https://libvirt.org/html/libvirt-libvirt-domain.html#virDomainMigrateToURI]
 * to migrate a domain from the host on this connection to the host whose
 * libvirt URI is duri.
 */
static VALUE libvirt_domain_migrate_to_uri(int argc, VALUE *argv, VALUE d)
{
    VALUE duri, flags, dname, bandwidth;

    rb_scan_args(argc, argv, "13", &duri, &flags, &dname, &bandwidth);

    ruby_libvirt_generate_call_nil(virDomainMigrateToURI,
                                   ruby_libvirt_connect_get(d),
                                   ruby_libvirt_domain_get(d),
                                   StringValueCStr(duri), NUM2ULONG(flags),
                                   ruby_libvirt_get_cstring_or_null(dname),
                                   ruby_libvirt_value_to_ulong(bandwidth));
}

/*
 * call-seq:
 *   dom.migrate_set_max_downtime(downtime, flags=0) -> nil
 *
 * Call virDomainMigrateSetMaxDowntime[https://libvirt.org/html/libvirt-libvirt-domain.html#virDomainMigrateSetMaxDowntime]
 * to set the maximum downtime desired for live migration.  Deprecated; use
 * dom.migrate_max_downtime= instead.
 */
static VALUE libvirt_domain_migrate_set_max_downtime(int argc, VALUE *argv,
                                                     VALUE d)
{
    VALUE downtime, flags;

    rb_scan_args(argc, argv, "11", &downtime, &flags);

    ruby_libvirt_generate_call_nil(virDomainMigrateSetMaxDowntime,
                                   ruby_libvirt_connect_get(d),
                                   ruby_libvirt_domain_get(d),
                                   NUM2ULL(downtime),
                                   ruby_libvirt_value_to_uint(flags));
}

/*
 * call-seq:
 *   dom.migrate_max_downtime = downtime,flags=0
 *
 * Call virDomainMigrateSetMaxDowntime[https://libvirt.org/html/libvirt-libvirt-domain.html#virDomainMigrateSetMaxDowntime]
 * to set the maximum downtime desired for live migration.
 */
static VALUE libvirt_domain_migrate_max_downtime_equal(VALUE d, VALUE in)
{
    VALUE downtime, flags;

    domain_input_to_fixnum_and_flags(in, &downtime, &flags);

    ruby_libvirt_generate_call_nil(virDomainMigrateSetMaxDowntime,
                                   ruby_libvirt_connect_get(d),
                                   ruby_libvirt_domain_get(d),
                                   NUM2ULL(downtime),
                                   ruby_libvirt_value_to_uint(flags));
}

/*
 * call-seq:
 *   dom.migrate2(dconn, dxml=nil, flags=0, dname=nil, uri=nil, bandwidth=0) -> Libvirt::Domain
 *
 * Call virDomainMigrate2[https://libvirt.org/html/libvirt-libvirt-domain.html#virDomainMigrate2]
 * to migrate a domain from the host on this connection to the connection
 * referenced in dconn.
 */
static VALUE libvirt_domain_migrate2(int argc, VALUE *argv, VALUE d)
{
    VALUE dconn, dxml, flags, dname, uri, bandwidth;
    virDomainPtr ddom = NULL;

    rb_scan_args(argc, argv, "15", &dconn, &dxml, &flags, &dname, &uri,
                 &bandwidth);

    ddom = virDomainMigrate2(ruby_libvirt_domain_get(d),
                             ruby_libvirt_connect_get(dconn),
                             ruby_libvirt_get_cstring_or_null(dxml),
                             ruby_libvirt_value_to_ulong(flags),
                             ruby_libvirt_get_cstring_or_null(dname),
                             ruby_libvirt_get_cstring_or_null(uri),
                             ruby_libvirt_value_to_ulong(bandwidth));

    ruby_libvirt_raise_error_if(ddom == NULL, e_Error, "virDomainMigrate2",
                                ruby_libvirt_connect_get(d));

    return ruby_libvirt_domain_new(ddom, dconn);
}

/*
 * call-seq:
 *   dom.migrate_to_uri2(duri=nil, migrate_uri=nil, dxml=nil, flags=0, dname=nil, bandwidth=0) -> nil
 *
 * Call virDomainMigrateToURI2[https://libvirt.org/html/libvirt-libvirt-domain.html#virDomainMigrateToURI2]
 * to migrate a domain from the host on this connection to the host whose
 * libvirt URI is duri.
 */
static VALUE libvirt_domain_migrate_to_uri2(int argc, VALUE *argv, VALUE d)
{
    VALUE duri, migrate_uri, dxml, flags, dname, bandwidth;

    rb_scan_args(argc, argv, "06", &duri, &migrate_uri, &dxml, &flags, &dname,
                 &bandwidth);

    ruby_libvirt_generate_call_nil(virDomainMigrateToURI2,
                                   ruby_libvirt_connect_get(d),
                                   ruby_libvirt_domain_get(d),
                                   ruby_libvirt_get_cstring_or_null(duri),
                                   ruby_libvirt_get_cstring_or_null(migrate_uri),
                                   ruby_libvirt_get_cstring_or_null(dxml),
                                   ruby_libvirt_value_to_ulong(flags),
                                   ruby_libvirt_get_cstring_or_null(dname),
                                   ruby_libvirt_value_to_ulong(bandwidth));
}

/*
 * call-seq:
 *   dom.migrate_set_max_speed(bandwidth, flags=0) -> nil
 *
 * Call virDomainMigrateSetMaxSpeed[https://libvirt.org/html/libvirt-libvirt-domain.html#virDomainMigrateSetMaxSpeed]
 * to set the maximum bandwidth allowed for live migration.  Deprecated; use
 * dom.migrate_max_speed= instead.
 */
static VALUE libvirt_domain_migrate_set_max_speed(int argc, VALUE *argv,
                                                  VALUE d)
{
    VALUE bandwidth, flags;

    rb_scan_args(argc, argv, "11", &bandwidth, &flags);

    ruby_libvirt_generate_call_nil(virDomainMigrateSetMaxSpeed,
                                   ruby_libvirt_connect_get(d),
                                   ruby_libvirt_domain_get(d),
                                   NUM2ULONG(bandwidth),
                                   ruby_libvirt_value_to_uint(flags));
}

/*
 * call-seq:
 *   dom.migrate_max_speed = bandwidth,flags=0
 *
 * Call virDomainMigrateSetMaxSpeed[https://libvirt.org/html/libvirt-libvirt-domain.html#virDomainMigrateSetMaxSpeed]
 * to set the maximum bandwidth allowed for live migration.
 */
static VALUE libvirt_domain_migrate_max_speed_equal(VALUE d, VALUE in)
{
    VALUE bandwidth, flags;

    domain_input_to_fixnum_and_flags(in, &bandwidth, &flags);

    ruby_libvirt_generate_call_nil(virDomainMigrateSetMaxSpeed,
                                   ruby_libvirt_connect_get(d),
                                   ruby_libvirt_domain_get(d),
                                   NUM2ULONG(bandwidth),
                                   ruby_libvirt_value_to_uint(flags));
}

/*
 * call-seq:
 *   dom.shutdown(flags=0) -> nil
 *
 * Call virDomainShutdown[https://libvirt.org/html/libvirt-libvirt-domain.html#virDomainShutdown]
 * to do a soft shutdown of the domain.  The mechanism for doing the shutdown
 * is hypervisor specific, and may require software running inside the domain
 * to succeed.
 */
static VALUE libvirt_domain_shutdown(int argc, VALUE *argv, VALUE d)
{
    VALUE flags;

    rb_scan_args(argc, argv, "01", &flags);

    if (ruby_libvirt_value_to_uint(flags) != 0) {
        ruby_libvirt_generate_call_nil(virDomainShutdownFlags,
                                       ruby_libvirt_connect_get(d),
                                       ruby_libvirt_domain_get(d),
                                       ruby_libvirt_value_to_uint(flags));
    } else {
        ruby_libvirt_generate_call_nil(virDomainShutdown,
                                       ruby_libvirt_connect_get(d),
                                       ruby_libvirt_domain_get(d));
    }
}

/*
 * call-seq:
 *   dom.reboot(flags=0) -> nil
 *
 * Call virDomainReboot[https://libvirt.org/html/libvirt-libvirt-domain.html#virDomainReboot]
 * to do a reboot of the domain.
 */
static VALUE libvirt_domain_reboot(int argc, VALUE *argv, VALUE d)
{
    VALUE flags;

    rb_scan_args(argc, argv, "01", &flags);

    ruby_libvirt_generate_call_nil(virDomainReboot, ruby_libvirt_connect_get(d),
                                   ruby_libvirt_domain_get(d),
                                   ruby_libvirt_value_to_uint(flags));
}

/*
 * call-seq:
 *   dom.destroy(flags=0) -> nil
 *
 * Call virDomainDestroy[https://libvirt.org/html/libvirt-libvirt-domain.html#virDomainDestroy]
 * to do a hard power-off of the domain.
 */
static VALUE libvirt_domain_destroy(int argc, VALUE *argv, VALUE d)
{
    VALUE flags;

    rb_scan_args(argc, argv, "01", &flags);

    if (ruby_libvirt_value_to_uint(flags) != 0) {
        ruby_libvirt_generate_call_nil(virDomainDestroyFlags,
                                       ruby_libvirt_connect_get(d),
                                       ruby_libvirt_domain_get(d),
                                       ruby_libvirt_value_to_uint(flags));
    } else {
        ruby_libvirt_generate_call_nil(virDomainDestroy,
                                       ruby_libvirt_connect_get(d),
                                       ruby_libvirt_domain_get(d));
    }
}

/*
 * call-seq:
 *   dom.suspend -> nil
 *
 * Call virDomainSuspend[https://libvirt.org/html/libvirt-libvirt-domain.html#virDomainSuspend]
 * to stop the domain from executing.  The domain will still continue to
 * consume memory, but will not take any CPU time.
 */
static VALUE libvirt_domain_suspend(VALUE d)
{
    ruby_libvirt_generate_call_nil(virDomainSuspend,
                                   ruby_libvirt_connect_get(d),
                                   ruby_libvirt_domain_get(d));
}

/*
 * call-seq:
 *   dom.resume -> nil
 *
 * Call virDomainResume[https://libvirt.org/html/libvirt-libvirt-domain.html#virDomainResume]
 * to resume a suspended domain.  After this call the domain will start
 * consuming CPU resources again.
 */
static VALUE libvirt_domain_resume(VALUE d)
{
    ruby_libvirt_generate_call_nil(virDomainResume, ruby_libvirt_connect_get(d),
                                   ruby_libvirt_domain_get(d));
}

/*
 * call-seq:
 *   dom.save(filename, dxml=nil, flags=0) -> nil
 *
 * Call virDomainSave[https://libvirt.org/html/libvirt-libvirt-domain.html#virDomainSave]
 * to save the domain state to filename.  After this call, the domain will no
 * longer be consuming any resources.
 */
static VALUE libvirt_domain_save(int argc, VALUE *argv, VALUE d)
{
    VALUE flags, to, dxml;

    rb_scan_args(argc, argv, "12", &to, &dxml, &flags);

    if (ruby_libvirt_value_to_uint(flags) != 0 || TYPE(dxml) != T_NIL) {
        ruby_libvirt_generate_call_nil(virDomainSaveFlags,
                                       ruby_libvirt_connect_get(d),
                                       ruby_libvirt_domain_get(d),
                                       StringValueCStr(to),
                                       ruby_libvirt_get_cstring_or_null(dxml),
                                       ruby_libvirt_value_to_uint(flags));
    } else {
        ruby_libvirt_generate_call_nil(virDomainSave,
                                       ruby_libvirt_connect_get(d),
                                       ruby_libvirt_domain_get(d),
                                       StringValueCStr(to));
    }
}

/*
 * call-seq:
 *   dom.managed_save(flags=0) -> nil
 *
 * Call virDomainManagedSave[https://libvirt.org/html/libvirt-libvirt-domain.html#virDomainManagedSave]
 * to do a managed save of the domain.  The domain will be saved to a place
 * of libvirt's choosing.
 */
static VALUE libvirt_domain_managed_save(int argc, VALUE *argv, VALUE d)
{
    VALUE flags;

    rb_scan_args(argc, argv, "01", &flags);

    ruby_libvirt_generate_call_nil(virDomainManagedSave,
                                   ruby_libvirt_connect_get(d),
                                   ruby_libvirt_domain_get(d),
                                   ruby_libvirt_value_to_uint(flags));
}

/*
 * call-seq:
 *   dom.has_managed_save?(flags=0) -> [True|False]
 *
 * Call virDomainHasManagedSaveImage[https://libvirt.org/html/libvirt-libvirt-domain.html#virDomainHasManagedSaveImage]
 * to determine if a particular domain has a managed save image.
 */
static VALUE libvirt_domain_has_managed_save(int argc, VALUE *argv, VALUE d)
{
    VALUE flags;

    rb_scan_args(argc, argv, "01", &flags);

    ruby_libvirt_generate_call_truefalse(virDomainHasManagedSaveImage,
                                         ruby_libvirt_connect_get(d),
                                         ruby_libvirt_domain_get(d),
                                         ruby_libvirt_value_to_uint(flags));
}

/*
 * call-seq:
 *   dom.managed_save_remove(flags=0) -> nil
 *
 * Call virDomainManagedSaveRemove[https://libvirt.org/html/libvirt-libvirt-domain.html#virDomainManagedSaveRemove]
 * to remove the managed save image for a domain.
 */
static VALUE libvirt_domain_managed_save_remove(int argc, VALUE *argv, VALUE d)
{
    VALUE flags;

    rb_scan_args(argc, argv, "01", &flags);

    ruby_libvirt_generate_call_nil(virDomainManagedSaveRemove,
                                   ruby_libvirt_connect_get(d),
                                   ruby_libvirt_domain_get(d),
                                   ruby_libvirt_value_to_uint(flags));
}

/*
 * call-seq:
 *   dom.core_dump(filename, flags=0) -> nil
 *
 * Call virDomainCoreDump[https://libvirt.org/html/libvirt-libvirt-domain.html#virDomainCoreDump]
 * to do a full memory dump of the domain to filename.
 */
static VALUE libvirt_domain_core_dump(int argc, VALUE *argv, VALUE d)
{
    VALUE to, flags;

    rb_scan_args(argc, argv, "11", &to, &flags);

    ruby_libvirt_generate_call_nil(virDomainCoreDump,
                                   ruby_libvirt_connect_get(d),
                                   ruby_libvirt_domain_get(d),
                                   StringValueCStr(to),
                                   ruby_libvirt_value_to_uint(flags));
}

/*
 * call-seq:
 *   Libvirt::Domain::restore(conn, filename) -> nil
 *
 * Call virDomainRestore[https://libvirt.org/html/libvirt-libvirt-domain.html#virDomainRestore]
 * to restore the domain from the filename.
 */
static VALUE libvirt_domain_s_restore(VALUE RUBY_LIBVIRT_UNUSED(klass), VALUE c,
                                      VALUE from)
{
    ruby_libvirt_generate_call_nil(virDomainRestore,
                                   ruby_libvirt_connect_get(c),
                                   ruby_libvirt_connect_get(c),
                                   StringValueCStr(from));
}

/*
 * call-seq:
 *   dom.info -> Libvirt::Domain::Info
 *
 * Call virDomainGetInfo[https://libvirt.org/html/libvirt-libvirt-domain.html#virDomainGetInfo]
 * to retrieve domain information.
 */
static VALUE libvirt_domain_info(VALUE d)
{
    virDomainInfo info;
    int r;
    VALUE result;

    r = virDomainGetInfo(ruby_libvirt_domain_get(d), &info);
    ruby_libvirt_raise_error_if(r < 0, e_RetrieveError, "virDomainGetInfo",
                                ruby_libvirt_connect_get(d));

    result = rb_class_new_instance(0, NULL, c_domain_info);
    rb_iv_set(result, "@state", CHR2FIX(info.state));
    rb_iv_set(result, "@max_mem", ULONG2NUM(info.maxMem));
    rb_iv_set(result, "@memory", ULONG2NUM(info.memory));
    rb_iv_set(result, "@nr_virt_cpu", INT2NUM((int) info.nrVirtCpu));
    rb_iv_set(result, "@cpu_time", ULL2NUM(info.cpuTime));

    return result;
}

/*
 * call-seq:
 *   dom.security_label -> Libvirt::Domain::SecurityLabel
 *
 * Call virDomainGetSecurityLabel[https://libvirt.org/html/libvirt-libvirt-domain.html#virDomainGetSecurityLabel]
 * to retrieve the security label applied to this domain.
 */
static VALUE libvirt_domain_security_label(VALUE d)
{
    virSecurityLabel seclabel;
    int r;
    VALUE result;

    r = virDomainGetSecurityLabel(ruby_libvirt_domain_get(d), &seclabel);
    ruby_libvirt_raise_error_if(r < 0, e_RetrieveError,
                                "virDomainGetSecurityLabel",
                                ruby_libvirt_connect_get(d));

    result = rb_class_new_instance(0, NULL, c_domain_security_label);
    rb_iv_set(result, "@label", rb_str_new2(seclabel.label));
    rb_iv_set(result, "@enforcing", INT2NUM(seclabel.enforcing));

    return result;
}

/*
 * call-seq:
 *   dom.block_stats(path) -> Libvirt::Domain::BlockStats
 *
 * Call virDomainBlockStats[https://libvirt.org/html/libvirt-libvirt-domain.html#virDomainBlockStats]
 * to retrieve statistics about domain block device path.
 */
static VALUE libvirt_domain_block_stats(VALUE d, VALUE path)
{
    virDomainBlockStatsStruct stats;
    int r;
    VALUE result;

    r = virDomainBlockStats(ruby_libvirt_domain_get(d), StringValueCStr(path),
                            &stats, sizeof(stats));
    ruby_libvirt_raise_error_if(r < 0, e_RetrieveError, "virDomainBlockStats",
                                ruby_libvirt_connect_get(d));

    result = rb_class_new_instance(0, NULL, c_domain_block_stats);
    rb_iv_set(result, "@rd_req", LL2NUM(stats.rd_req));
    rb_iv_set(result, "@rd_bytes", LL2NUM(stats.rd_bytes));
    rb_iv_set(result, "@wr_req", LL2NUM(stats.wr_req));
    rb_iv_set(result, "@wr_bytes", LL2NUM(stats.wr_bytes));
    rb_iv_set(result, "@errs", LL2NUM(stats.errs));

    return result;
}

/*
 * call-seq:
 *   dom.memory_stats(flags=0) -> [ Libvirt::Domain::MemoryStats ]
 *
 * Call virDomainMemoryStats[https://libvirt.org/html/libvirt-libvirt-domain.html#virDomainMemoryStats]
 * to retrieve statistics about the amount of memory consumed by a domain.
 */
static VALUE libvirt_domain_memory_stats(int argc, VALUE *argv, VALUE d)
{
    virDomainMemoryStatStruct stats[6];
    int i, r;
    VALUE result, flags, tmp;

    rb_scan_args(argc, argv, "01", &flags);

    r = virDomainMemoryStats(ruby_libvirt_domain_get(d), stats, 6,
                             ruby_libvirt_value_to_uint(flags));
    ruby_libvirt_raise_error_if(r < 0, e_RetrieveError, "virDomainMemoryStats",
                                ruby_libvirt_connect_get(d));

    /* FIXME: the right rubyish way to have done this would have been to
     * create a hash with the values, something like:
     *
     * { 'SWAP_IN' => 0, 'SWAP_OUT' => 98, 'MAJOR_FAULT' => 45,
     *   'MINOR_FAULT' => 55, 'UNUSED' => 455, 'AVAILABLE' => 98 }
     *
     * Unfortunately this has already been released with the array version
     * so we have to maintain compatibility with that.  We should probably add
     * a new memory_stats-like call that properly creates the hash.
     */
    result = rb_ary_new2(r);
    for (i = 0; i < r; i++) {
        tmp = rb_class_new_instance(0, NULL, c_domain_memory_stats);
        rb_iv_set(tmp, "@tag", INT2NUM(stats[i].tag));
        rb_iv_set(tmp, "@val", ULL2NUM(stats[i].val));

        rb_ary_store(result, i, tmp);
    }

    return result;
}

/*
 * call-seq:
 *   dom.blockinfo(path, flags=0) -> Libvirt::Domain::BlockInfo
 *
 * Call virDomainGetBlockInfo[https://libvirt.org/html/libvirt-libvirt-domain.html#virDomainGetBlockInfo]
 * to retrieve information about the backing file path for the domain.
 */
static VALUE libvirt_domain_block_info(int argc, VALUE *argv, VALUE d)
{
    virDomainBlockInfo info;
    int r;
    VALUE result, flags, path;

    rb_scan_args(argc, argv, "11", &path, &flags);

    r = virDomainGetBlockInfo(ruby_libvirt_domain_get(d), StringValueCStr(path),
                              &info, ruby_libvirt_value_to_uint(flags));
    ruby_libvirt_raise_error_if(r < 0, e_RetrieveError,
                                "virDomainGetBlockInfo",
                                ruby_libvirt_connect_get(d));

    result = rb_class_new_instance(0, NULL, c_domain_block_info);
    rb_iv_set(result, "@capacity", ULL2NUM(info.capacity));
    rb_iv_set(result, "@allocation", ULL2NUM(info.allocation));
    rb_iv_set(result, "@physical", ULL2NUM(info.physical));

    return result;
}

/*
 * call-seq:
 *   dom.block_peek(path, offset, size, flags=0) -> String
 *
 * Call virDomainBlockPeek[https://libvirt.org/html/libvirt-libvirt-domain.html#virDomainBlockPeek]
 * to read size number of bytes, starting at offset offset from domain backing
 * file path.  Due to limitations of the libvirt remote protocol, the user
 * should never request more than 64k bytes.
 */
static VALUE libvirt_domain_block_peek(int argc, VALUE *argv, VALUE d)
{
    VALUE path, offset, size, flags;
    char *buffer;
    int r;

    rb_scan_args(argc, argv, "31", &path, &offset, &size, &flags);

    buffer = alloca(sizeof(char) * NUM2UINT(size));

    r = virDomainBlockPeek(ruby_libvirt_domain_get(d), StringValueCStr(path),
                           NUM2ULL(offset), NUM2UINT(size), buffer,
                           ruby_libvirt_value_to_uint(flags));
    ruby_libvirt_raise_error_if(r < 0, e_RetrieveError, "virDomainBlockPeek",
                                ruby_libvirt_connect_get(d));

    return rb_str_new(buffer, NUM2UINT(size));
}

/*
 * call-seq:
 *   dom.memory_peek(start, size, flags=Libvirt::Domain::MEMORY_VIRTUAL) -> String
 *
 * Call virDomainMemoryPeek[https://libvirt.org/html/libvirt-libvirt-domain.html#virDomainMemoryPeek]
 * to read size number of bytes from offset start from the domain memory.
 * Due to limitations of the libvirt remote protocol, the user
 * should never request more than 64k bytes.
 */
static VALUE libvirt_domain_memory_peek(int argc, VALUE *argv, VALUE d)
{
    VALUE start, size, flags;
    char *buffer;
    int r;

    rb_scan_args(argc, argv, "21", &start, &size, &flags);

    if (NIL_P(flags)) {
        flags = INT2NUM(VIR_MEMORY_VIRTUAL);
    }

    buffer = alloca(sizeof(char) * NUM2UINT(size));

    r = virDomainMemoryPeek(ruby_libvirt_domain_get(d), NUM2ULL(start),
                            NUM2UINT(size), buffer, NUM2UINT(flags));
    ruby_libvirt_raise_error_if(r < 0, e_RetrieveError, "virDomainMemoryPeek",
                                ruby_libvirt_connect_get(d));

    return rb_str_new(buffer, NUM2UINT(size));
}

/* call-seq:
 *   dom.vcpus -> [ Libvirt::Domain::VCPUInfo ]
 *
 * Call virDomainGetVcpus[https://libvirt.org/html/libvirt-libvirt-domain.html#virDomainGetVcpus]
 * to retrieve detailed information about the state of a domain's virtual CPUs.
 */
static VALUE libvirt_domain_vcpus(VALUE d)
{
    virDomainInfo dominfo;
    virVcpuInfoPtr cpuinfo = NULL;
    unsigned char *cpumap;
    int cpumaplen, r, j, maxcpus;
    VALUE result, vcpuinfo, p2vcpumap;
    unsigned short i;

    r = virDomainGetInfo(ruby_libvirt_domain_get(d), &dominfo);
    ruby_libvirt_raise_error_if(r < 0, e_RetrieveError, "virDomainGetInfo",
                                ruby_libvirt_connect_get(d));

    cpuinfo = alloca(sizeof(virVcpuInfo) * dominfo.nrVirtCpu);

    maxcpus = ruby_libvirt_get_maxcpus(ruby_libvirt_connect_get(d));

    cpumaplen = VIR_CPU_MAPLEN(maxcpus);

    cpumap = alloca(sizeof(unsigned char) * cpumaplen * dominfo.nrVirtCpu);

    r = virDomainGetVcpus(ruby_libvirt_domain_get(d), cpuinfo,
                          dominfo.nrVirtCpu, cpumap, cpumaplen);
    if (r < 0) {
        /* if the domain is not shutoff, then this is an error */
        ruby_libvirt_raise_error_if(dominfo.state != VIR_DOMAIN_SHUTOFF,
                                    e_RetrieveError, "virDomainGetVcpus",
                                    ruby_libvirt_connect_get(d));

        /* otherwise, we can try to call virDomainGetVcpuPinInfo to get the
         * information instead
         */
        r = virDomainGetVcpuPinInfo(ruby_libvirt_domain_get(d),
                                    dominfo.nrVirtCpu, cpumap, cpumaplen,
                                    VIR_DOMAIN_AFFECT_CONFIG);
        ruby_libvirt_raise_error_if(r < 0, e_RetrieveError,
                                    "virDomainGetVcpuPinInfo",
                                    ruby_libvirt_connect_get(d));
    }

    result = rb_ary_new();

    for (i = 0; i < r; i++) {
        vcpuinfo = rb_class_new_instance(0, NULL, c_domain_vcpuinfo);
        if (cpuinfo != NULL) {
            rb_iv_set(vcpuinfo, "@number", INT2NUM(cpuinfo[i].number));
            rb_iv_set(vcpuinfo, "@state", INT2NUM(cpuinfo[i].state));
            rb_iv_set(vcpuinfo, "@cpu_time", ULL2NUM(cpuinfo[i].cpuTime));
            rb_iv_set(vcpuinfo, "@cpu", INT2NUM(cpuinfo[i].cpu));
        }
        else {
            rb_iv_set(vcpuinfo, "@number", Qnil);
            rb_iv_set(vcpuinfo, "@state", Qnil);
            rb_iv_set(vcpuinfo, "@cpu_time", Qnil);
            rb_iv_set(vcpuinfo, "@cpu", Qnil);
        }

        p2vcpumap = rb_ary_new();

        for (j = 0; j < maxcpus; j++) {
            rb_ary_push(p2vcpumap, (VIR_CPU_USABLE(cpumap, cpumaplen,
                                                   i, j)) ? Qtrue : Qfalse);
        }
        rb_iv_set(vcpuinfo, "@cpumap", p2vcpumap);

        rb_ary_push(result, vcpuinfo);
    }

    return result;
}

/*
 * call-seq:
 *   dom.active? -> [true|false]
 *
 * Call virDomainIsActive[https://libvirt.org/html/libvirt-libvirt-domain.html#virDomainIsActive]
 * to determine if this domain is currently active.
 */
static VALUE libvirt_domain_active_p(VALUE d)
{
    ruby_libvirt_generate_call_truefalse(virDomainIsActive,
                                         ruby_libvirt_connect_get(d),
                                         ruby_libvirt_domain_get(d));
}

/*
 * call-seq:
 *   dom.persistent? -> [true|false]
 *
 * Call virDomainIsPersistent[https://libvirt.org/html/libvirt-libvirt-domain.html#virDomainIsPersistent]
 * to determine if this is a persistent domain.
 */
static VALUE libvirt_domain_persistent_p(VALUE d)
{
    ruby_libvirt_generate_call_truefalse(virDomainIsPersistent,
                                         ruby_libvirt_connect_get(d),
                                         ruby_libvirt_domain_get(d));
}

/*
 * call-seq:
 *   dom.ifinfo(if) -> Libvirt::Domain::IfInfo
 *
 * Call virDomainInterfaceStats[https://libvirt.org/html/libvirt-libvirt-domain.html#virDomainInterfaceStats]
 * to retrieve statistics about domain interface if.
 */
static VALUE libvirt_domain_if_stats(VALUE d, VALUE sif)
{
    char *ifname = ruby_libvirt_get_cstring_or_null(sif);
    virDomainInterfaceStatsStruct ifinfo;
    int r;
    VALUE result = Qnil;

    if (ifname) {
        r = virDomainInterfaceStats(ruby_libvirt_domain_get(d), ifname, &ifinfo,
                                    sizeof(virDomainInterfaceStatsStruct));
        ruby_libvirt_raise_error_if(r < 0, e_RetrieveError,
                                    "virDomainInterfaceStats",
                                    ruby_libvirt_connect_get(d));

        result = rb_class_new_instance(0, NULL, c_domain_ifinfo);
        rb_iv_set(result, "@rx_bytes", LL2NUM(ifinfo.rx_bytes));
        rb_iv_set(result, "@rx_packets", LL2NUM(ifinfo.rx_packets));
        rb_iv_set(result, "@rx_errs", LL2NUM(ifinfo.rx_errs));
        rb_iv_set(result, "@rx_drop", LL2NUM(ifinfo.rx_drop));
        rb_iv_set(result, "@tx_bytes", LL2NUM(ifinfo.tx_bytes));
        rb_iv_set(result, "@tx_packets", LL2NUM(ifinfo.tx_packets));
        rb_iv_set(result, "@tx_errs", LL2NUM(ifinfo.tx_errs));
        rb_iv_set(result, "@tx_drop", LL2NUM(ifinfo.tx_drop));
    }
    return result;
}

/*
 * call-seq:
 *   dom.name -> String
 *
 * Call virDomainGetName[https://libvirt.org/html/libvirt-libvirt-domain.html#virDomainGetName]
 * to retrieve the name of this domain.
 */
static VALUE libvirt_domain_name(VALUE d)
{
    ruby_libvirt_generate_call_string(virDomainGetName,
                                      ruby_libvirt_connect_get(d), 0,
                                      ruby_libvirt_domain_get(d));
}

/*
 * call-seq:
 *   dom.id -> Fixnum
 *
 * Call virDomainGetID[https://libvirt.org/html/libvirt-libvirt-domain.html#virDomainGetID]
 * to retrieve the ID of this domain.  If the domain isn't running, this will
 * be -1.
 */
static VALUE libvirt_domain_id(VALUE d)
{
    unsigned int id;
    int out;

    id = virDomainGetID(ruby_libvirt_domain_get(d));

    /* we need to cast the unsigned int id to a signed int out to handle the
     * -1 case
     */
    out = id;
    ruby_libvirt_raise_error_if(out == -1, e_RetrieveError, "virDomainGetID",
                                ruby_libvirt_connect_get(d));

    return INT2NUM(out);
}

/*
 * call-seq:
 *   dom.uuid -> String
 *
 * Call virDomainGetUUIDString[https://libvirt.org/html/libvirt-libvirt-domain.html#virDomainGetUUIDString]
 * to retrieve the UUID of this domain.
 */
static VALUE libvirt_domain_uuid(VALUE d)
{
    ruby_libvirt_generate_uuid(virDomainGetUUIDString,
                               ruby_libvirt_connect_get(d),
                               ruby_libvirt_domain_get(d));
}

/*
 * call-seq:
 *   dom.os_type -> String
 *
 * Call virDomainGetOSType[https://libvirt.org/html/libvirt-libvirt-domain.html#virDomainGetOSType]
 * to retrieve the os_type of this domain.  In libvirt terms, os_type determines
 * whether this domain is fully virtualized, paravirtualized, or a container.
 */
static VALUE libvirt_domain_os_type(VALUE d)
{
    ruby_libvirt_generate_call_string(virDomainGetOSType,
                                      ruby_libvirt_connect_get(d), 1,
                                      ruby_libvirt_domain_get(d));
}

/*
 * call-seq:
 *   dom.max_memory -> Fixnum
 *
 * Call virDomainGetMaxMemory[https://libvirt.org/html/libvirt-libvirt-domain.html#virDomainGetMaxMemory]
 * to retrieve the maximum amount of memory this domain is allowed to access.
 * Note that the current amount of memory this domain is allowed to access may
 * be different (see dom.memory_set).
 */
static VALUE libvirt_domain_max_memory(VALUE d)
{
    unsigned long max_memory;

    max_memory = virDomainGetMaxMemory(ruby_libvirt_domain_get(d));
    ruby_libvirt_raise_error_if(max_memory == 0, e_RetrieveError,
                                "virDomainGetMaxMemory",
                                ruby_libvirt_connect_get(d));

    return ULONG2NUM(max_memory);
}

/*
 * call-seq:
 *   dom.max_memory = Fixnum
 *
 * Call virDomainSetMaxMemory[https://libvirt.org/html/libvirt-libvirt-domain.html#virDomainSetMaxMemory]
 * to set the maximum amount of memory (in kilobytes) this domain should be
 * allowed to access.
 */
static VALUE libvirt_domain_max_memory_equal(VALUE d, VALUE max_memory)
{
    int r;

    r = virDomainSetMaxMemory(ruby_libvirt_domain_get(d),
                              NUM2ULONG(max_memory));
    ruby_libvirt_raise_error_if(r < 0, e_DefinitionError,
                                "virDomainSetMaxMemory",
                                ruby_libvirt_connect_get(d));

    return ULONG2NUM(max_memory);
}

/*
 * call-seq:
 *   dom.memory = Fixnum,flags=0
 *
 * Call virDomainSetMemory[https://libvirt.org/html/libvirt-libvirt-domain.html#virDomainSetMemory]
 * to set the amount of memory (in kilobytes) this domain should currently
 * have.  Note this will only succeed if both the hypervisor and the domain on
 * this connection support ballooning.
 */
static VALUE libvirt_domain_memory_equal(VALUE d, VALUE in)
{
    VALUE memory, flags;
    int r;

    domain_input_to_fixnum_and_flags(in, &memory, &flags);

    if (ruby_libvirt_value_to_uint(flags) != 0) {
        r = virDomainSetMemoryFlags(ruby_libvirt_domain_get(d),
                                    NUM2ULONG(memory),
                                    ruby_libvirt_value_to_uint(flags));
    } else {
        r = virDomainSetMemory(ruby_libvirt_domain_get(d),
                               NUM2ULONG(memory));
    }

    ruby_libvirt_raise_error_if(r < 0, e_DefinitionError, "virDomainSetMemory",
                                ruby_libvirt_connect_get(d));

    return ULONG2NUM(memory);
}

/*
 * call-seq:
 *   dom.max_vcpus -> Fixnum
 *
 * Call virDomainGetMaxVcpus[https://libvirt.org/html/libvirt-libvirt-domain.html#virDomainGetMaxVcpus]
 * to retrieve the maximum number of virtual CPUs this domain can use.
 */
static VALUE libvirt_domain_max_vcpus(VALUE d)
{
    ruby_libvirt_generate_call_int(virDomainGetMaxVcpus,
                                   ruby_libvirt_connect_get(d),
                                   ruby_libvirt_domain_get(d));
}

/* call-seq:
 *   dom.num_vcpus(flags) -> Fixnum
 *
 * Call virDomainGetVcpusFlags[https://libvirt.org/html/libvirt-libvirt-domain.html#virDomainGetVcpusFlags]
 * to retrieve the number of virtual CPUs assigned to this domain.
 */
static VALUE libvirt_domain_num_vcpus(VALUE d, VALUE flags)
{
    ruby_libvirt_generate_call_int(virDomainGetVcpusFlags,
                                   ruby_libvirt_connect_get(d),
                                   ruby_libvirt_domain_get(d),
                                   ruby_libvirt_value_to_uint(flags));
}

/*
 * call-seq:
 *   dom.vcpus = Fixnum,flags=0
 *
 * Call virDomainSetVcpus[https://libvirt.org/html/libvirt-libvirt-domain.html#virDomainSetVcpus]
 * to set the current number of virtual CPUs this domain should have.  Note
 * that this will only work if both the hypervisor and domain on this
 * connection support virtual CPU hotplug/hot-unplug.
 */
static VALUE libvirt_domain_vcpus_equal(VALUE d, VALUE in)
{
    VALUE nvcpus, flags = Qnil;

    if (TYPE(in) == T_FIXNUM) {
        nvcpus = in;
        ruby_libvirt_generate_call_nil(virDomainSetVcpus,
                                       ruby_libvirt_connect_get(d),
                                       ruby_libvirt_domain_get(d),
                                       NUM2UINT(nvcpus));
    } else if (TYPE(in) == T_ARRAY) {
        if (RARRAY_LEN(in) != 2) {
            rb_raise(rb_eArgError, "wrong number of arguments (%ld for 2)",
                     RARRAY_LEN(in));
        }
        nvcpus = rb_ary_entry(in, 0);
        flags = rb_ary_entry(in, 1);
        ruby_libvirt_generate_call_nil(virDomainSetVcpusFlags,
                                       ruby_libvirt_connect_get(d),
                                       ruby_libvirt_domain_get(d),
                                       NUM2UINT(nvcpus),
                                       NUM2UINT(flags));
    } else {
        rb_raise(rb_eTypeError,
                 "wrong argument type (expected Number or Array)");
    }
}

/*
 * call-seq:
 *   dom.vcpus_flags = Fixnum,flags=0
 *

 * Call virDomainSetVcpusFlags[https://libvirt.org/html/libvirt-libvirt-domain.html#virDomainSetVcpusFlags]
 * to set the current number of virtual CPUs this domain should have.  The
 * flags parameter controls whether the change is made to the running domain
 * the domain configuration, or both, and must not be 0.  Deprecated;
 * use dom.vcpus= instead.
 */
static VALUE libvirt_domain_vcpus_flags_equal(VALUE d, VALUE in)
{
    VALUE nvcpus, flags;

    domain_input_to_fixnum_and_flags(in, &nvcpus, &flags);

    ruby_libvirt_generate_call_nil(virDomainSetVcpusFlags,
                                   ruby_libvirt_connect_get(d),
                                   ruby_libvirt_domain_get(d), NUM2UINT(nvcpus),
                                   NUM2UINT(flags));
}

/*
 * call-seq:
 *   dom.pin_vcpu(vcpu, cpulist, flags=0) -> nil
 *
 * Call virDomainPinVcpu[https://libvirt.org/html/libvirt-libvirt-domain.html#virDomainPinVcpu]
 * to pin a particular virtual CPU to a range of physical processors.  The
 * cpulist should be an array of Fixnums representing the physical processors
 * this virtual CPU should be allowed to be scheduled on.
 */
static VALUE libvirt_domain_pin_vcpu(int argc, VALUE *argv, VALUE d)
{
    VALUE vcpu, cpulist, flags, e;
    int i, cpumaplen, maxcpus;
    unsigned char *cpumap;

    rb_scan_args(argc, argv, "21", &vcpu, &cpulist, &flags);

    Check_Type(cpulist, T_ARRAY);

    maxcpus = ruby_libvirt_get_maxcpus(ruby_libvirt_connect_get(d));

    cpumaplen = VIR_CPU_MAPLEN(maxcpus);

    cpumap = alloca(sizeof(unsigned char) * cpumaplen);
    MEMZERO(cpumap, unsigned char, cpumaplen);

    for (i = 0; i < RARRAY_LEN(cpulist); i++) {
        e = rb_ary_entry(cpulist, i);
        VIR_USE_CPU(cpumap, NUM2UINT(e));
    }

    if (ruby_libvirt_value_to_uint(flags) != 0) {
        ruby_libvirt_generate_call_nil(virDomainPinVcpuFlags,
                                       ruby_libvirt_connect_get(d),
                                       ruby_libvirt_domain_get(d),
                                       NUM2UINT(vcpu),
                                       cpumap,
                                       cpumaplen,
                                       ruby_libvirt_value_to_uint(flags));
    } else {
        ruby_libvirt_generate_call_nil(virDomainPinVcpu,
                                       ruby_libvirt_connect_get(d),
                                       ruby_libvirt_domain_get(d),
                                       NUM2UINT(vcpu),
                                       cpumap, cpumaplen);
    }
}

/*
 * call-seq:
 *   dom.xml_desc(flags=0) -> String
 *
 * Call virDomainGetXMLDesc[https://libvirt.org/html/libvirt-libvirt-domain.html#virDomainGetXMLDesc]
 * to retrieve the XML describing this domain.
 */
static VALUE libvirt_domain_xml_desc(int argc, VALUE *argv, VALUE d)
{
    VALUE flags;

    rb_scan_args(argc, argv, "01", &flags);

    ruby_libvirt_generate_call_string(virDomainGetXMLDesc,
                                      ruby_libvirt_connect_get(d), 1,
                                      ruby_libvirt_domain_get(d),
                                      ruby_libvirt_value_to_uint(flags));
}

/*
 * call-seq:
 *   dom.undefine(flags=0) -> nil
 *
 * Call virDomainUndefine[https://libvirt.org/html/libvirt-libvirt-domain.html#virDomainUndefine]
 * to undefine the domain.  After this call, the domain object is no longer
 * valid.
 */
static VALUE libvirt_domain_undefine(int argc, VALUE *argv, VALUE d)
{
    VALUE flags;

    rb_scan_args(argc, argv, "01", &flags);

    if (ruby_libvirt_value_to_uint(flags) != 0) {
        ruby_libvirt_generate_call_nil(virDomainUndefineFlags,
                                       ruby_libvirt_connect_get(d),
                                       ruby_libvirt_domain_get(d),
                                       ruby_libvirt_value_to_uint(flags));
    } else {
        ruby_libvirt_generate_call_nil(virDomainUndefine,
                                       ruby_libvirt_connect_get(d),
                                       ruby_libvirt_domain_get(d));
    }
}

/*
 * call-seq:
 *   dom.create(flags=0) -> nil
 *
 * Call virDomainCreate[https://libvirt.org/html/libvirt-libvirt-domain.html#virDomainCreate]
 * to start an already defined domain.
 */
static VALUE libvirt_domain_create(int argc, VALUE *argv, VALUE d)
{
    VALUE flags;

    rb_scan_args(argc, argv, "01", &flags);

    if (ruby_libvirt_value_to_uint(flags) != 0) {
        ruby_libvirt_generate_call_nil(virDomainCreateWithFlags,
                                       ruby_libvirt_connect_get(d),
                                       ruby_libvirt_domain_get(d),
                                       ruby_libvirt_value_to_uint(flags));
    } else {
        ruby_libvirt_generate_call_nil(virDomainCreate,
                                       ruby_libvirt_connect_get(d),
                                       ruby_libvirt_domain_get(d));
    }
}

/*
 * call-seq:
 *   dom.autostart -> [true|false]
 *
 * Call virDomainGetAutostart[https://libvirt.org/html/libvirt-libvirt-domain.html#virDomainGetAutostart]
 * to find out the state of the autostart flag for a domain.
 */
static VALUE libvirt_domain_autostart(VALUE d)
{
    int r, autostart;

    r = virDomainGetAutostart(ruby_libvirt_domain_get(d), &autostart);
    ruby_libvirt_raise_error_if(r < 0, e_RetrieveError, "virDomainAutostart",
                                ruby_libvirt_connect_get(d));

    return autostart ? Qtrue : Qfalse;
}

/*
 * call-seq:
 *   dom.autostart = [true|false]
 *
 * Call virDomainSetAutostart[https://libvirt.org/html/libvirt-libvirt-domain.html#virDomainSetAutostart]
 * to make this domain autostart when libvirtd starts up.
 */
static VALUE libvirt_domain_autostart_equal(VALUE d, VALUE autostart)
{
    if (autostart != Qtrue && autostart != Qfalse) {
		rb_raise(rb_eTypeError,
                 "wrong argument type (expected TrueClass or FalseClass)");
    }

    ruby_libvirt_generate_call_nil(virDomainSetAutostart,
                                   ruby_libvirt_connect_get(d),
                                   ruby_libvirt_domain_get(d),
                                   RTEST(autostart) ? 1 : 0);
}

/*
 * call-seq:
 *   dom.attach_device(device_xml, flags=0) -> nil
 *
 * Call virDomainAttachDeviceFlags[https://libvirt.org/html/libvirt-libvirt-domain.html#virDomainAttachDeviceFlags]
 * to attach the device described by the device_xml to the domain.
 */
static VALUE libvirt_domain_attach_device(int argc, VALUE *argv, VALUE d)
{
    VALUE xml, flags;

    rb_scan_args(argc, argv, "11", &xml, &flags);

    /* NOTE: can't use virDomainAttachDevice() when flags==0 here
     *       because that function only works on active domains and
     *       VIR_DOMAIN_AFFECT_CURRENT==0.
     *
     * See https://gitlab.com/libvirt/libvirt-ruby/-/issues/11 */
    ruby_libvirt_generate_call_nil(virDomainAttachDeviceFlags,
                                   ruby_libvirt_connect_get(d),
                                   ruby_libvirt_domain_get(d),
                                   StringValueCStr(xml),
                                   ruby_libvirt_value_to_uint(flags));
}

/*
 * call-seq:
 *   dom.detach_device(device_xml, flags=0) -> nil
 *
 * Call virDomainDetachDeviceFlags[https://libvirt.org/html/libvirt-libvirt-domain.html#virDomainDetachDeviceFlags]
 * to detach the device described by the device_xml from the domain.
 */
static VALUE libvirt_domain_detach_device(int argc, VALUE *argv, VALUE d)
{
    VALUE xml, flags;

    rb_scan_args(argc, argv, "11", &xml, &flags);

    /* NOTE: can't use virDomainDetachDevice() when flags==0 here
     *       because that function only works on active domains and
     *       VIR_DOMAIN_AFFECT_CURRENT==0.
     *
     * See https://gitlab.com/libvirt/libvirt-ruby/-/issues/11 */
    ruby_libvirt_generate_call_nil(virDomainDetachDeviceFlags,
                                   ruby_libvirt_connect_get(d),
                                   ruby_libvirt_domain_get(d),
                                   StringValueCStr(xml),
                                   ruby_libvirt_value_to_uint(flags));
}

/*
 * call-seq:
 *   dom.update_device(device_xml, flags=0) -> nil
 *
 * Call virDomainUpdateDeviceFlags[https://libvirt.org/html/libvirt-libvirt-domain.html#virDomainUpdateDeviceFlags]
 * to update the device described by the device_xml.
 */
static VALUE libvirt_domain_update_device(int argc, VALUE *argv, VALUE d)
{
    VALUE xml, flags;

    rb_scan_args(argc, argv, "11", &xml, &flags);

    ruby_libvirt_generate_call_nil(virDomainUpdateDeviceFlags,
                                   ruby_libvirt_connect_get(d),
                                   ruby_libvirt_domain_get(d),
                                   StringValueCStr(xml),
                                   ruby_libvirt_value_to_uint(flags));
}

/*
 * call-seq:
 *   dom.free -> nil
 *
 * Call virDomainFree[https://libvirt.org/html/libvirt-libvirt-domain.html#virDomainFree]
 * to free a domain object.
 */
static VALUE libvirt_domain_free(VALUE d)
{
    ruby_libvirt_generate_call_free(Domain, d);
}

static void domain_snapshot_free(void *d)
{
    ruby_libvirt_free_struct(DomainSnapshot, d);
}

static VALUE domain_snapshot_new(virDomainSnapshotPtr d, VALUE domain)
{
    VALUE result;

    result = ruby_libvirt_new_class(c_domain_snapshot, d,
                                    rb_iv_get(domain, "@connection"),
                                    domain_snapshot_free);
    rb_iv_set(result, "@domain", domain);

    return result;
}

static virDomainSnapshotPtr domain_snapshot_get(VALUE d)
{
    ruby_libvirt_get_struct(DomainSnapshot, d);
}

/*
 * call-seq:
 *   dom.snapshot_create_xml(snapshot_xml, flags=0) -> Libvirt::Domain::Snapshot
 *
 * Call virDomainSnapshotCreateXML[https://libvirt.org/html/libvirt-libvirt-domain.html#virDomainSnapshotCreateXML]
 * to create a new snapshot based on snapshot_xml.
 */
static VALUE libvirt_domain_snapshot_create_xml(int argc, VALUE *argv, VALUE d)
{
    VALUE xmlDesc, flags;
    virDomainSnapshotPtr ret;

    rb_scan_args(argc, argv, "11", &xmlDesc, &flags);

    ret = virDomainSnapshotCreateXML(ruby_libvirt_domain_get(d),
                                     StringValueCStr(xmlDesc),
                                     ruby_libvirt_value_to_uint(flags));

    ruby_libvirt_raise_error_if(ret == NULL, e_Error,
                                "virDomainSnapshotCreateXML",
                                ruby_libvirt_connect_get(d));

    return domain_snapshot_new(ret, d);
}

/*
 * call-seq:
 *   dom.num_of_snapshots(flags=0) -> Fixnum
 *
 * Call virDomainSnapshotNum[https://libvirt.org/html/libvirt-libvirt-domain.html#virDomainSnapshotNum]
 * to retrieve the number of available snapshots for this domain.
 */
static VALUE libvirt_domain_num_of_snapshots(int argc, VALUE *argv, VALUE d)
{
    VALUE flags;

    rb_scan_args(argc, argv, "01", &flags);

    ruby_libvirt_generate_call_int(virDomainSnapshotNum,
                                   ruby_libvirt_connect_get(d),
                                   ruby_libvirt_domain_get(d),
                                   ruby_libvirt_value_to_uint(flags));
}

/*
 * call-seq:
 *   dom.list_snapshots(flags=0) -> list
 *
 * Call virDomainSnapshotListNames[https://libvirt.org/html/libvirt-libvirt-domain.html#virDomainSnapshotListNames]
 * to retrieve a list of snapshot names available for this domain.
 */
static VALUE libvirt_domain_list_snapshots(int argc, VALUE *argv, VALUE d)
{
    VALUE flags;
    int r, num;
    char **names;

    rb_scan_args(argc, argv, "01", &flags);

    if (TYPE(flags) != T_NIL && TYPE(flags) != T_FIXNUM) {
        rb_raise(rb_eTypeError,
                 "wrong argument type (expected Number)");
    }

    num = virDomainSnapshotNum(ruby_libvirt_domain_get(d), 0);
    ruby_libvirt_raise_error_if(num < 0, e_RetrieveError,
                                "virDomainSnapshotNum",
                                ruby_libvirt_connect_get(d));
    if (num == 0) {
        /* if num is 0, don't call virDomainSnapshotListNames function */
        return rb_ary_new2(num);
    }

    names = alloca(sizeof(char *) * num);

    r = virDomainSnapshotListNames(ruby_libvirt_domain_get(d), names, num,
                                   ruby_libvirt_value_to_uint(flags));
    ruby_libvirt_raise_error_if(r < 0, e_RetrieveError,
                                "virDomainSnapshotListNames",
                                ruby_libvirt_connect_get(d));

    return ruby_libvirt_generate_list(r, names);
}

/*
 * call-seq:
 *   dom.lookup_snapshot_by_name(name, flags=0) -> Libvirt::Domain::Snapshot
 *
 * Call virDomainSnapshotLookupByName[https://libvirt.org/html/libvirt-libvirt-domain.html#virDomainSnapshotLookupByName]
 * to retrieve a snapshot object corresponding to snapshot name.
 */
static VALUE libvirt_domain_lookup_snapshot_by_name(int argc, VALUE *argv,
                                                    VALUE d)
{
    virDomainSnapshotPtr snap;
    VALUE name, flags;

    rb_scan_args(argc, argv, "11", &name, &flags);

    snap = virDomainSnapshotLookupByName(ruby_libvirt_domain_get(d),
                                         StringValueCStr(name),
                                         ruby_libvirt_value_to_uint(flags));
    ruby_libvirt_raise_error_if(snap == NULL, e_RetrieveError,
                                "virDomainSnapshotLookupByName",
                                ruby_libvirt_connect_get(d));

    return domain_snapshot_new(snap, d);
}

/*
 * call-seq:
 *   dom.has_current_snapshot?(flags=0) -> [true|false]
 *
 * Call virDomainHasCurrentSnapshot[https://libvirt.org/html/libvirt-libvirt-domain.html#virDomainHasCurrentSnapshot]
 * to find out if this domain has a snapshot active.
 */
static VALUE libvirt_domain_has_current_snapshot_p(int argc, VALUE *argv,
                                                   VALUE d)
{
    VALUE flags;

    rb_scan_args(argc, argv, "01", &flags);

    ruby_libvirt_generate_call_truefalse(virDomainHasCurrentSnapshot,
                                         ruby_libvirt_connect_get(d),
                                         ruby_libvirt_domain_get(d),
                                         ruby_libvirt_value_to_uint(flags));
}

/*
 * call-seq:
 *   dom.revert_to_snapshot(snapshot_object, flags=0) -> nil
 *
 * Call virDomainRevertToSnapshot[https://libvirt.org/html/libvirt-libvirt-domain.html#virDomainRevertToSnapshot]
 * to restore this domain to a previously saved snapshot.
 */
static VALUE libvirt_domain_revert_to_snapshot(int argc, VALUE *argv, VALUE d)
{
    VALUE snap, flags;

    rb_scan_args(argc, argv, "11", &snap, &flags);

    ruby_libvirt_generate_call_nil(virDomainRevertToSnapshot,
                                   ruby_libvirt_connect_get(d),
                                   domain_snapshot_get(snap),
                                   ruby_libvirt_value_to_uint(flags));
}

/*
 * call-seq:
 *   dom.current_snapshot(flags=0) -> Libvirt::Domain::Snapshot
 *
 * Call virDomainCurrentSnapshot[https://libvirt.org/html/libvirt-libvirt-domain.html#virDomainCurrentSnapshot]
 * to retrieve the current snapshot for this domain (if any).
 */
static VALUE libvirt_domain_current_snapshot(int argc, VALUE *argv, VALUE d)
{
    VALUE flags;
    virDomainSnapshotPtr snap;

    rb_scan_args(argc, argv, "01", &flags);

    snap = virDomainSnapshotCurrent(ruby_libvirt_domain_get(d),
                                    ruby_libvirt_value_to_uint(flags));
    ruby_libvirt_raise_error_if(snap == NULL, e_RetrieveError,
                                "virDomainSnapshotCurrent",
                                ruby_libvirt_connect_get(d));

    return domain_snapshot_new(snap, d);
}

/*
 * call-seq:
 *   snapshot.xml_desc(flags=0) -> String
 *
 * Call virDomainSnapshotGetXMLDesc[https://libvirt.org/html/libvirt-libvirt-domain.html#virDomainSnapshotGetXMLDesc]
 * to retrieve the xml description for this snapshot.
 */
static VALUE libvirt_domain_snapshot_xml_desc(int argc, VALUE *argv, VALUE s)
{
    VALUE flags;

    rb_scan_args(argc, argv, "01", &flags);

    ruby_libvirt_generate_call_string(virDomainSnapshotGetXMLDesc,
                                      ruby_libvirt_connect_get(s), 1,
                                      domain_snapshot_get(s),
                                      ruby_libvirt_value_to_uint(flags));
}

/*
 * call-seq:
 *   snapshot.delete(flags=0) -> nil
 *
 * Call virDomainSnapshotDelete[https://libvirt.org/html/libvirt-libvirt-domain.html#virDomainSnapshotDelete]
 * to delete this snapshot.
 */
static VALUE libvirt_domain_snapshot_delete(int argc, VALUE *argv, VALUE s)
{
    VALUE flags;

    rb_scan_args(argc, argv, "01", &flags);

    ruby_libvirt_generate_call_nil(virDomainSnapshotDelete,
                                   ruby_libvirt_connect_get(s),
                                   domain_snapshot_get(s),
                                   ruby_libvirt_value_to_uint(flags));
}

/*
 * call-seq:
 *   snapshot.free -> nil
 *
 * Call virDomainSnapshotFree[https://libvirt.org/html/libvirt-libvirt-domain.html#virDomainSnapshotFree]
 * to free up the snapshot object.  After this call the snapshot object is
 * no longer valid.
 */
static VALUE libvirt_domain_snapshot_free(VALUE s)
{
    ruby_libvirt_generate_call_free(DomainSnapshot, s);
}


/*
 * call-seq:
 *   snapshot.name -> String
 *
 * Call virDomainSnapshotGetName[https://libvirt.org/html/libvirt-libvirt-domain.html#virDomainSnapshotGetName]
 * to get the name associated with a snapshot.
 */
static VALUE libvirt_domain_snapshot_name(VALUE s)
{
    ruby_libvirt_generate_call_string(virDomainSnapshotGetName,
                                      ruby_libvirt_connect_get(s),
                                      0, domain_snapshot_get(s));
}


/*
 * call-seq:
 *   dom.job_info -> Libvirt::Domain::JobInfo
 *
 * Call virDomainGetJobInfo[https://libvirt.org/html/libvirt-libvirt-domain.html#virDomainGetJobInfo]
 * to retrieve the current state of the running domain job.
 */
static VALUE libvirt_domain_job_info(VALUE d)
{
    int r;
    virDomainJobInfo info;
    VALUE result;

    r = virDomainGetJobInfo(ruby_libvirt_domain_get(d), &info);
    ruby_libvirt_raise_error_if(r < 0, e_RetrieveError, "virDomainGetJobInfo",
                                ruby_libvirt_connect_get(d));

    result = rb_class_new_instance(0, NULL, c_domain_job_info);
    rb_iv_set(result, "@type", INT2NUM(info.type));
    rb_iv_set(result, "@time_elapsed", ULL2NUM(info.timeElapsed));
    rb_iv_set(result, "@time_remaining", ULL2NUM(info.timeRemaining));
    rb_iv_set(result, "@data_total", ULL2NUM(info.dataTotal));
    rb_iv_set(result, "@data_processed", ULL2NUM(info.dataProcessed));
    rb_iv_set(result, "@data_remaining", ULL2NUM(info.dataRemaining));
    rb_iv_set(result, "@mem_total", ULL2NUM(info.memTotal));
    rb_iv_set(result, "@mem_processed", ULL2NUM(info.memProcessed));
    rb_iv_set(result, "@mem_remaining", ULL2NUM(info.memRemaining));
    rb_iv_set(result, "@file_total", ULL2NUM(info.fileTotal));
    rb_iv_set(result, "@file_processed", ULL2NUM(info.fileProcessed));
    rb_iv_set(result, "@file_remaining", ULL2NUM(info.fileRemaining));

    return result;
}

/*
 * call-seq:
 *   dom.abort_job -> nil
 *
 * Call virDomainAbortJob[https://libvirt.org/html/libvirt-libvirt-domain.html#virDomainAbortJob]
 * to abort the currently running job on this domain.
 */
static VALUE libvirt_domain_abort_job(VALUE d)
{
    ruby_libvirt_generate_call_nil(virDomainAbortJob,
                                   ruby_libvirt_connect_get(d),
                                   ruby_libvirt_domain_get(d));
}


struct create_sched_type_args {
    char *type;
    int nparams;
};

static VALUE create_sched_type_array(VALUE input)
{
    struct create_sched_type_args *args;
    VALUE result;

    args = (struct create_sched_type_args *)input;

    result = rb_ary_new();
    rb_ary_push(result, rb_str_new2(args->type));
    rb_ary_push(result, INT2NUM(args->nparams));

    return result;
}

/*
 * call-seq:
 *   dom.scheduler_type -> [type, #params]
 *
 * Call virDomainGetSchedulerType[https://libvirt.org/html/libvirt-libvirt-domain.html#virDomainGetSchedulerType]
 * to retrieve the scheduler type used on this domain.
 */
static VALUE libvirt_domain_scheduler_type(VALUE d)
{
    int nparams, exception = 0;
    char *type;
    VALUE result;
    struct create_sched_type_args args;

    type = virDomainGetSchedulerType(ruby_libvirt_domain_get(d), &nparams);

    ruby_libvirt_raise_error_if(type == NULL, e_RetrieveError,
                                "virDomainGetSchedulerType",
                                ruby_libvirt_connect_get(d));

    args.type = type;
    args.nparams = nparams;
    result = rb_protect(create_sched_type_array, (VALUE)&args, &exception);
    if (exception) {
        free(type);
        rb_jump_tag(exception);
    }

    return result;
}

/*
 * call-seq:
 *   dom.qemu_monitor_command(cmd, flags=0) -> String
 *
 * Call virDomainQemuMonitorCommand
 * to send a qemu command directly to the monitor.  Note that this will only
 * work on qemu hypervisors, and the input and output formats are not
 * guaranteed to be stable.  Also note that using this command can severly
 * impede libvirt's ability to manage the domain; use with caution!
 */
static VALUE libvirt_domain_qemu_monitor_command(int argc, VALUE *argv, VALUE d)
{
    VALUE cmd, flags, ret;
    char *result;
    int r, exception = 0;
    const char *type;

    rb_scan_args(argc, argv, "11", &cmd, &flags);

    type = virConnectGetType(ruby_libvirt_connect_get(d));
    ruby_libvirt_raise_error_if(type == NULL, e_Error, "virConnectGetType",
                                ruby_libvirt_connect_get(d));
    /* The type != NULL check is actually redundant, since if type was NULL
     * we would have raised an exception above.  It's here to shut clang,
     * since clang can't tell that we would never reach this.
     */
    if (type != NULL && strcmp(type, "QEMU") != 0) {
        rb_raise(rb_eTypeError,
                 "Tried to use virDomainQemuMonitor command on %s connection",
                 type);
    }

    r = virDomainQemuMonitorCommand(ruby_libvirt_domain_get(d),
                                    StringValueCStr(cmd), &result,
                                    ruby_libvirt_value_to_uint(flags));
    ruby_libvirt_raise_error_if(r < 0, e_RetrieveError,
                                "virDomainQemuMonitorCommand",
                                ruby_libvirt_connect_get(d));

    ret = rb_protect(ruby_libvirt_str_new2_wrap, (VALUE)&result, &exception);
    free(result);
    if (exception) {
        rb_jump_tag(exception);
    }

    return ret;
}

/*
 * call-seq:
 *   dom.updated? ->  [True|False]
 *
 * Call virDomainIsUpdated[https://libvirt.org/html/libvirt-libvirt-domain.html#virDomainIsUpdated]
 * to determine whether the definition for this domain has been updated.
 */
static VALUE libvirt_domain_is_updated(VALUE d)
{
    ruby_libvirt_generate_call_truefalse(virDomainIsUpdated,
                                         ruby_libvirt_connect_get(d),
                                         ruby_libvirt_domain_get(d));
}

static const char *scheduler_nparams(VALUE d,
                                     unsigned int RUBY_LIBVIRT_UNUSED(flags),
                                     void *RUBY_LIBVIRT_UNUSED(opaque),
                                     int *nparams)
{
    char *type;

    type = virDomainGetSchedulerType(ruby_libvirt_domain_get(d), nparams);
    if (type == NULL) {
        return "virDomainGetSchedulerType";
    }

    xfree(type);

    return NULL;
}

static const char *scheduler_get(VALUE d, unsigned int flags, void *voidparams,
                                 int *nparams,
                                 void *RUBY_LIBVIRT_UNUSED(opaque))
{
    virTypedParameterPtr params = (virTypedParameterPtr)voidparams;

    if (flags != 0) {
        if (virDomainGetSchedulerParametersFlags(ruby_libvirt_domain_get(d), params,
                                                 nparams, flags) < 0) {
            return "virDomainGetSchedulerParameters";
        }
    } else {
        if (virDomainGetSchedulerParameters(ruby_libvirt_domain_get(d),
                                            params, nparams) < 0) {
            return "virDomainGetSchedulerParameters";
        }
    }

    return NULL;
}

static const char *scheduler_set(VALUE d, unsigned int flags,
                                 virTypedParameterPtr params, int nparams,
                                 void *RUBY_LIBVIRT_UNUSED(opaque))
{
    if (flags != 0) {
        if (virDomainSetSchedulerParametersFlags(ruby_libvirt_domain_get(d), params,
                                                 nparams, flags) < 0) {
            return "virDomainSetSchedulerParameters";
        }
    } else {
        if (virDomainSetSchedulerParameters(ruby_libvirt_domain_get(d),
                                            params, nparams) < 0) {
            return "virDomainSetSchedulerParameters";
        }
    }

    return NULL;
}

/*
 * call-seq:
 *   dom.scheduler_parameters(flags=0) -> Hash
 *
 * Call virDomainGetSchedulerParameters[https://libvirt.org/html/libvirt-libvirt-domain.html#virDomainGetSchedulerParameters]
 * to retrieve all of the scheduler parameters for this domain.  The keys and
 * values in the hash that is returned are hypervisor specific.
 */
static VALUE libvirt_domain_scheduler_parameters(int argc, VALUE *argv, VALUE d)
{
    VALUE flags;

    rb_scan_args(argc, argv, "01", &flags);

    return ruby_libvirt_get_typed_parameters(d,
                                             ruby_libvirt_value_to_uint(flags),
                                             NULL, scheduler_nparams,
                                             scheduler_get);
}

static struct ruby_libvirt_typed_param domain_scheduler_allowed[] = {
    {VIR_DOMAIN_SCHEDULER_CPU_SHARES, VIR_TYPED_PARAM_ULLONG},
    {VIR_DOMAIN_SCHEDULER_VCPU_PERIOD, VIR_TYPED_PARAM_ULLONG},
    {VIR_DOMAIN_SCHEDULER_VCPU_QUOTA, VIR_TYPED_PARAM_LLONG},
    {VIR_DOMAIN_SCHEDULER_EMULATOR_PERIOD, VIR_TYPED_PARAM_ULLONG},
    {VIR_DOMAIN_SCHEDULER_EMULATOR_QUOTA, VIR_TYPED_PARAM_LLONG},
    {VIR_DOMAIN_SCHEDULER_WEIGHT, VIR_TYPED_PARAM_UINT},
    {VIR_DOMAIN_SCHEDULER_CAP, VIR_TYPED_PARAM_UINT},
    {VIR_DOMAIN_SCHEDULER_RESERVATION, VIR_TYPED_PARAM_LLONG},
    {VIR_DOMAIN_SCHEDULER_LIMIT, VIR_TYPED_PARAM_LLONG},
    {VIR_DOMAIN_SCHEDULER_SHARES, VIR_TYPED_PARAM_INT},
};

/*
 * call-seq:
 *   dom.scheduler_parameters = Hash
 *
 * Call virDomainSetSchedulerParameters[https://libvirt.org/html/libvirt-libvirt-domain.html#virDomainSetSchedulerParameters]
 * to set the scheduler parameters for this domain.  The keys and values in
 * the input hash are hypervisor specific.  If an empty hash is given, no
 * changes are made (and no error is raised).
 */
static VALUE libvirt_domain_scheduler_parameters_equal(VALUE d, VALUE input)
{
    VALUE hash, flags;

    ruby_libvirt_assign_hash_and_flags(input, &hash, &flags);

    return ruby_libvirt_set_typed_parameters(d, hash, NUM2UINT(flags), NULL,
                                             domain_scheduler_allowed,
                                             ARRAY_SIZE(domain_scheduler_allowed),
                                             scheduler_set);
}

static const char *memory_nparams(VALUE d, unsigned int flags,
                                  void *RUBY_LIBVIRT_UNUSED(opaque),
                                  int *nparams)
{
    if (virDomainGetMemoryParameters(ruby_libvirt_domain_get(d), NULL, nparams,
                                     flags) < 0) {
        return "virDomainGetMemoryParameters";
    }

    return NULL;
}

static const char *memory_get(VALUE d, unsigned int flags, void *voidparams,
                              int *nparams, void *RUBY_LIBVIRT_UNUSED(opaque))
{
    virTypedParameterPtr params = (virTypedParameterPtr)voidparams;

    if (virDomainGetMemoryParameters(ruby_libvirt_domain_get(d), params,
                                     nparams, flags) < 0) {
        return "virDomainGetMemoryParameters";
    }

    return NULL;
}

static const char *memory_set(VALUE d, unsigned int flags,
                              virTypedParameterPtr params, int nparams,
                              void *RUBY_LIBVIRT_UNUSED(opaque))
{
    if (virDomainSetMemoryParameters(ruby_libvirt_domain_get(d), params,
                                     nparams, flags) < 0) {
        return "virDomainSetMemoryParameters";
    }

    return NULL;
}

/*
 * call-seq:
 *   dom.memory_parameters(flags=0) -> Hash
 *
 * Call virDomainGetMemoryParameters[https://libvirt.org/html/libvirt-libvirt-domain.html#virDomainGetMemoryParameters]
 * to retrieve all of the memory parameters for this domain.  The keys and
 * values in the hash that is returned are hypervisor specific.
 */
static VALUE libvirt_domain_memory_parameters(int argc, VALUE *argv, VALUE d)
{
    VALUE flags;

    rb_scan_args(argc, argv, "01", &flags);

    return ruby_libvirt_get_typed_parameters(d,
                                             ruby_libvirt_value_to_uint(flags),
                                             NULL, memory_nparams, memory_get);
}

static struct ruby_libvirt_typed_param domain_memory_allowed[] = {
    {VIR_DOMAIN_MEMORY_HARD_LIMIT, VIR_TYPED_PARAM_ULLONG},
    {VIR_DOMAIN_MEMORY_SOFT_LIMIT, VIR_TYPED_PARAM_ULLONG},
    {VIR_DOMAIN_MEMORY_MIN_GUARANTEE, VIR_TYPED_PARAM_ULLONG},
    {VIR_DOMAIN_MEMORY_SWAP_HARD_LIMIT, VIR_TYPED_PARAM_ULLONG},
};

/*
 * call-seq:
 *   dom.memory_parameters = Hash,flags=0
 *
 * Call virDomainSetMemoryParameters[https://libvirt.org/html/libvirt-libvirt-domain.html#virDomainSetMemoryParameters]
 * to set the memory parameters for this domain.  The keys and values in
 * the input hash are hypervisor specific.
 */
static VALUE libvirt_domain_memory_parameters_equal(VALUE d, VALUE in)
{
    VALUE hash, flags;

    ruby_libvirt_assign_hash_and_flags(in, &hash, &flags);

    return ruby_libvirt_set_typed_parameters(d, hash, NUM2UINT(flags), NULL,
                                             domain_memory_allowed,
                                             ARRAY_SIZE(domain_memory_allowed),
                                             memory_set);
}

static const char *blkio_nparams(VALUE d, unsigned int flags,
                                 void *RUBY_LIBVIRT_UNUSED(opaque),
                                 int *nparams)
{
    if (virDomainGetBlkioParameters(ruby_libvirt_domain_get(d), NULL, nparams,
                                    flags) < 0) {
        return "virDomainGetBlkioParameters";
    }

    return NULL;
}

static const char *blkio_get(VALUE d, unsigned int flags, void *voidparams,
                             int *nparams, void *RUBY_LIBVIRT_UNUSED(opaque))
{
    virTypedParameterPtr params = (virTypedParameterPtr)voidparams;

    if (virDomainGetBlkioParameters(ruby_libvirt_domain_get(d), params, nparams,
                                    flags) < 0) {
        return "virDomainGetBlkioParameters";
    }

    return NULL;
}

static const char *blkio_set(VALUE d, unsigned int flags,
                             virTypedParameterPtr params, int nparams,
                             void *RUBY_LIBVIRT_UNUSED(opaque))
{
    if (virDomainSetBlkioParameters(ruby_libvirt_domain_get(d), params, nparams,
                                    flags) < 0) {
        return "virDomainSetBlkioParameters";
    }

    return NULL;
}

/*
 * call-seq:
 *   dom.blkio_parameters(flags=0) -> Hash
 *
 * Call virDomainGetBlkioParameters[https://libvirt.org/html/libvirt-libvirt-domain.html#virDomainGetBlkioParameters]
 * to retrieve all of the blkio parameters for this domain.  The keys and
 * values in the hash that is returned are hypervisor specific.
 */
static VALUE libvirt_domain_blkio_parameters(int argc, VALUE *argv, VALUE d)
{
    VALUE flags;

    rb_scan_args(argc, argv, "01", &flags);

    return ruby_libvirt_get_typed_parameters(d,
                                             ruby_libvirt_value_to_uint(flags),
                                             NULL, blkio_nparams, blkio_get);
}

static struct ruby_libvirt_typed_param blkio_allowed[] = {
    {VIR_DOMAIN_BLKIO_WEIGHT, VIR_TYPED_PARAM_UINT},
    {VIR_DOMAIN_BLKIO_DEVICE_WEIGHT, VIR_TYPED_PARAM_STRING},
};

/*
 * call-seq:
 *   dom.blkio_parameters = Hash,flags=0
 *
 * Call virDomainSetBlkioParameters[https://libvirt.org/html/libvirt-libvirt-domain.html#virDomainSetBlkioParameters]
 * to set the blkio parameters for this domain.  The keys and values in
 * the input hash are hypervisor specific.
 */
static VALUE libvirt_domain_blkio_parameters_equal(VALUE d, VALUE in)
{
    VALUE hash, flags;

    ruby_libvirt_assign_hash_and_flags(in, &hash, &flags);

    return ruby_libvirt_set_typed_parameters(d, hash, NUM2UINT(flags), NULL,
                                             blkio_allowed,
                                             ARRAY_SIZE(blkio_allowed),
                                             blkio_set);
}

/*
 * call-seq:
 *   dom.state(flags=0) -> state, reason
 *
 * Call virDomainGetState[https://libvirt.org/html/libvirt-libvirt-domain.html#virDomainGetState]
 * to get the current state of the domain.
 */
static VALUE libvirt_domain_state(int argc, VALUE *argv, VALUE d)
{
    VALUE result, flags;
    int state, reason, retval;

    rb_scan_args(argc, argv, "01", &flags);

    retval = virDomainGetState(ruby_libvirt_domain_get(d), &state, &reason,
                               ruby_libvirt_value_to_uint(flags));
    ruby_libvirt_raise_error_if(retval < 0, e_Error, "virDomainGetState",
                                ruby_libvirt_connect_get(d));

    result = rb_ary_new();

    rb_ary_push(result, INT2NUM(state));
    rb_ary_push(result, INT2NUM(reason));

    return result;
}

/*
 * call-seq:
 *   dom.open_console(device, stream, flags=0) -> nil
 *
 * Call virDomainOpenConsole[https://libvirt.org/html/libvirt-libvirt-domain.html#virDomainOpenConsole]
 * to open up a console to device over stream.
 */
static VALUE libvirt_domain_open_console(int argc, VALUE *argv, VALUE d)
{
    VALUE dev, st, flags;

    rb_scan_args(argc, argv, "21", &dev, &st, &flags);


    ruby_libvirt_generate_call_nil(virDomainOpenConsole,
                                   ruby_libvirt_connect_get(d),
                                   ruby_libvirt_domain_get(d),
                                   StringValueCStr(dev),
                                   ruby_libvirt_stream_get(st), NUM2INT(flags));
}

/*
 * call-seq:
 *   dom.screenshot(stream, screen, flags=0) -> nil
 *
 * Call virDomainScreenshot[https://libvirt.org/html/libvirt-libvirt-domain.html#virDomainScreenshot]
 * to take a screenshot of the domain console as a stream.
 */
static VALUE libvirt_domain_screenshot(int argc, VALUE *argv, VALUE d)
{
    VALUE st, screen, flags;

    rb_scan_args(argc, argv, "21", &st, &screen, &flags);

    ruby_libvirt_generate_call_string(virDomainScreenshot,
                                      ruby_libvirt_connect_get(d), 1,
                                      ruby_libvirt_domain_get(d),
                                      ruby_libvirt_stream_get(st),
                                      NUM2UINT(screen),
                                      ruby_libvirt_value_to_uint(flags));
}

/*
 * call-seq:
 *   dom.inject_nmi(flags=0) -> nil
 *
 * Call virDomainInjectNMI[https://libvirt.org/html/libvirt-libvirt-domain.html#virDomainInjectNMI]
 * to send an NMI to the guest.
 */
static VALUE libvirt_domain_inject_nmi(int argc, VALUE *argv, VALUE d)
{
    VALUE flags;

    rb_scan_args(argc, argv, "01", &flags);

    ruby_libvirt_generate_call_nil(virDomainInjectNMI,
                                   ruby_libvirt_connect_get(d),
                                   ruby_libvirt_domain_get(d),
                                   ruby_libvirt_value_to_uint(flags));
}

/*
 * call-seq:
 *   dom.control_info(flags=0) -> Libvirt::Domain::ControlInfo
 *
 * Call virDomainGetControlInfo[https://libvirt.org/html/libvirt-libvirt-domain.html#virDomainGetControlInfo]
 * to retrieve domain control interface information.
 */
static VALUE libvirt_domain_control_info(int argc, VALUE *argv, VALUE d)
{
    VALUE flags, result;
    virDomainControlInfo info;
    int r;

    rb_scan_args(argc, argv, "01", &flags);

    r = virDomainGetControlInfo(ruby_libvirt_domain_get(d), &info,
                                ruby_libvirt_value_to_uint(flags));
    ruby_libvirt_raise_error_if(r < 0, e_RetrieveError,
                                "virDomainGetControlInfo",
                                ruby_libvirt_connect_get(d));

    result = rb_class_new_instance(0, NULL, c_domain_control_info);
    rb_iv_set(result, "@state", ULONG2NUM(info.state));
    rb_iv_set(result, "@details", ULONG2NUM(info.details));
    rb_iv_set(result, "@stateTime", ULL2NUM(info.stateTime));

    return result;
}

/*
 * call-seq:
 *   dom.send_key(codeset, holdtime, keycodes)
 *
 * Call virDomainSendKey[https://libvirt.org/html/libvirt-libvirt-domain.html#virDomainSendKey]
 * to send key(s) to the domain. Keycodes has to be an array of keys to send.
 */
VALUE libvirt_domain_send_key(VALUE d, VALUE codeset, VALUE holdtime,
                              VALUE keycodes)
{
    unsigned int *codes;
    int i = 0;

    Check_Type(keycodes, T_ARRAY);

    codes = alloca(RARRAY_LEN(keycodes) * sizeof(unsigned int));

    for (i = 0; i < RARRAY_LEN(keycodes); i++) {
        codes[i] = NUM2UINT(rb_ary_entry(keycodes,i));
    }

    ruby_libvirt_generate_call_nil(virDomainSendKey,
                                   ruby_libvirt_connect_get(d),
                                   ruby_libvirt_domain_get(d),
                                   NUM2UINT(codeset), NUM2UINT(holdtime), codes,
                                   RARRAY_LEN(keycodes), 0);
}

/*
 * call-seq:
 *   dom.migrate_max_speed(flags=0) -> Fixnum
 *
 * Call virDomainMigrateGetMaxSpeed[https://libvirt.org/html/libvirt-libvirt-domain.html#virDomainMigrateGetMaxSpeed]
 * to retrieve the maximum speed a migration can use.
 */
static VALUE libvirt_domain_migrate_max_speed(int argc, VALUE *argv, VALUE d)
{
    VALUE flags;
    int r;
    unsigned long bandwidth;

    rb_scan_args(argc, argv, "01", &flags);

    r = virDomainMigrateGetMaxSpeed(ruby_libvirt_domain_get(d), &bandwidth,
                                    ruby_libvirt_value_to_uint(flags));
    ruby_libvirt_raise_error_if(r < 0, e_RetrieveError,
                                "virDomainMigrateGetMaxSpeed",
                                ruby_libvirt_connect_get(d));

    return ULONG2NUM(bandwidth);
}

/*
 * call-seq:
 *   dom.reset(flags=0) -> nil
 *
 * Call virDomainReset[https://libvirt.org/html/libvirt-libvirt-domain.html#virDomainReset]
 * to reset a domain immediately.
 */
static VALUE libvirt_domain_reset(int argc, VALUE *argv, VALUE d)
{
    VALUE flags;

    rb_scan_args(argc, argv, "01", &flags);

    ruby_libvirt_generate_call_nil(virDomainReset, ruby_libvirt_connect_get(d),
                                   ruby_libvirt_domain_get(d),
                                   ruby_libvirt_value_to_uint(flags));
}

/*
 * call-seq:
 *   dom.hostname(flags=0) -> nil
 *
 * Call virDomainGetHostname[https://libvirt.org/html/libvirt-libvirt-domain.html#virDomainGetHostname]
 * to get the hostname from a domain.
 */
static VALUE libvirt_domain_hostname(int argc, VALUE *argv, VALUE d)
{
    VALUE flags;

    rb_scan_args(argc, argv, "01", &flags);

    ruby_libvirt_generate_call_string(virDomainGetHostname,
                                      ruby_libvirt_connect_get(d), 1,
                                      ruby_libvirt_domain_get(d),
                                      ruby_libvirt_value_to_uint(flags));
}

/*
 * call-seq:
 *   dom.metadata(type, uri=nil, flags=0) -> String
 *
 * Call virDomainGetMetadata[https://libvirt.org/html/libvirt-libvirt-domain.html#virDomainGetMetadata]
 * to get the metadata from a domain.
 */
static VALUE libvirt_domain_metadata(int argc, VALUE *argv, VALUE d)
{
    VALUE uri, flags, type;

    rb_scan_args(argc, argv, "12", &type, &uri, &flags);

    ruby_libvirt_generate_call_string(virDomainGetMetadata,
                                      ruby_libvirt_connect_get(d), 1,
                                      ruby_libvirt_domain_get(d), NUM2INT(type),
                                      ruby_libvirt_get_cstring_or_null(uri),
                                      ruby_libvirt_value_to_uint(flags));
}

/*
 * call-seq:
 *   dom.metadata = Fixnum,string/nil,key=nil,uri=nil,flags=0 -> nil
 *
 * Call virDomainSetMetadata[https://libvirt.org/html/libvirt-libvirt-domain.html#virDomainSetMetadata]
 * to set the metadata for a domain.
 */
static VALUE libvirt_domain_metadata_equal(VALUE d, VALUE in)
{
    VALUE type, metadata, key, uri, flags;

    Check_Type(in, T_ARRAY);

    if (RARRAY_LEN(in) < 2 || RARRAY_LEN(in) > 5) {
        rb_raise(rb_eArgError,
                 "wrong number of arguments (%ld for 2, 3, 4, or 5)",
                 RARRAY_LEN(in));
    }

    type = rb_ary_entry(in, 0);
    metadata = rb_ary_entry(in, 1);
    key = Qnil;
    uri = Qnil;
    flags = INT2NUM(0);

    if (RARRAY_LEN(in) >= 3) {
        key = rb_ary_entry(in, 2);
    }
    if (RARRAY_LEN(in) >= 4) {
        uri = rb_ary_entry(in, 3);
    }
    if (RARRAY_LEN(in) == 5) {
        flags = rb_ary_entry(in, 4);
    }

    ruby_libvirt_generate_call_nil(virDomainSetMetadata,
                                   ruby_libvirt_connect_get(d),
                                   ruby_libvirt_domain_get(d), NUM2INT(type),
                                   ruby_libvirt_get_cstring_or_null(metadata),
                                   ruby_libvirt_get_cstring_or_null(key),
                                   ruby_libvirt_get_cstring_or_null(uri),
                                   ruby_libvirt_value_to_uint(flags));
}

/*
 * call-seq:
 *   dom.send_process_signal(pid, signum, flags=0) -> nil
 *
 * Call virDomainSendProcessSignal[https://libvirt.org/html/libvirt-libvirt-domain.html#virDomainSendProcessSignal]
 * to send a signal to a process inside the domain.
 */
static VALUE libvirt_domain_send_process_signal(int argc, VALUE *argv, VALUE d)
{
    VALUE pid, signum, flags;

    rb_scan_args(argc, argv, "21", &pid, &signum, &flags);

    ruby_libvirt_generate_call_nil(virDomainSendProcessSignal,
                                   ruby_libvirt_connect_get(d),
                                   ruby_libvirt_domain_get(d), NUM2LL(pid),
                                   NUM2UINT(signum),
                                   ruby_libvirt_value_to_uint(flags));
}

/*
 * call-seq:
 *   dom.list_all_snapshots(flags=0) -> Array
 *
 * Call virDomainListAllSnapshots[https://libvirt.org/html/libvirt-libvirt-domain.html#virDomainListAllSnapshots]
 * to get an array of snapshot objects for all snapshots.
 */
static VALUE libvirt_domain_list_all_snapshots(int argc, VALUE *argv, VALUE d)
{
    ruby_libvirt_generate_call_list_all(virDomainSnapshotPtr, argc, argv,
                                        virDomainListAllSnapshots,
                                        ruby_libvirt_domain_get(d), d,
                                        domain_snapshot_new,
                                        virDomainSnapshotFree);
}

/*
 * call-seq:
 *   snapshot.num_children(flags=0) -> Fixnum
 *
 * Call virDomainSnapshotNumChildren[https://libvirt.org/html/libvirt-libvirt-domain.html#virDomainSnapshotNumChildren]
 * to get the number of children snapshots of this snapshot.
 */
static VALUE libvirt_domain_snapshot_num_children(int argc, VALUE *argv,
                                                  VALUE s)
{
    VALUE flags;

    rb_scan_args(argc, argv, "01", &flags);

    ruby_libvirt_generate_call_int(virDomainSnapshotNumChildren,
                                   ruby_libvirt_connect_get(s),
                                   domain_snapshot_get(s),
                                   ruby_libvirt_value_to_uint(flags));
}

/*
 * call-seq:
 *   snapshot.list_children_names(flags=0) -> Array
 *
 * Call virDomainSnapshotListChildrenNames[https://libvirt.org/html/libvirt-libvirt-domain.html#virDomainSnapshotListChildrenNames]
 * to get an array of strings representing the children of this snapshot.
 */
static VALUE libvirt_domain_snapshot_list_children_names(int argc, VALUE *argv,
                                                         VALUE s)
{
    VALUE flags, result;
    char **children;
    int num_children, ret, i, j, exception = 0;
    struct ruby_libvirt_str_new2_and_ary_store_arg arg;

    rb_scan_args(argc, argv, "01", &flags);

    num_children = virDomainSnapshotNumChildren(domain_snapshot_get(s),
                                                ruby_libvirt_value_to_uint(flags));
    ruby_libvirt_raise_error_if(num_children < 0, e_RetrieveError,
                                "virDomainSnapshotNumChildren",
                                ruby_libvirt_connect_get(s));

    result = rb_ary_new2(num_children);

    if (num_children == 0) {
        return result;
    }

    children = alloca(num_children * sizeof(char *));

    ret = virDomainSnapshotListChildrenNames(domain_snapshot_get(s), children,
                                             num_children,
                                             ruby_libvirt_value_to_uint(flags));
    ruby_libvirt_raise_error_if(ret < 0, e_RetrieveError,
                                "virDomainSnapshotListChildrenNames",
                                ruby_libvirt_connect_get(s));

    for (i = 0; i < ret; i++) {
        arg.arr = result;
        arg.index = i;
        arg.value = children[i];
        rb_protect(ruby_libvirt_str_new2_and_ary_store_wrap, (VALUE)&arg,
                   &exception);
        if (exception) {
            goto error;
        }
        free(children[i]);
    }

    return result;

error:
    for (j = i; j < ret; j++) {
        free(children[j]);
    }
    rb_jump_tag(exception);

    /* not necessary, just to shut the compiler up */
    return Qnil;
}

/*
 * call-seq:
 *   snapshot.list_all_children(flags=0) -> Array
 *
 * Call virDomainSnapshotListAllChildren[https://libvirt.org/html/libvirt-libvirt-domain.html#virDomainSnapshotListAllChildren]
 * to get an array of snapshot objects that are children of this snapshot.
 */
static VALUE libvirt_domain_snapshot_list_all_children(int argc, VALUE *argv,
                                                       VALUE s)
{
    ruby_libvirt_generate_call_list_all(virDomainSnapshotPtr, argc, argv,
                                        virDomainSnapshotListAllChildren,
                                        domain_snapshot_get(s), s,
                                        domain_snapshot_new,
                                        virDomainSnapshotFree);
}

/*
 * call-seq:
 *   snapshot.parent(flags=0) -> [Libvirt::Domain::Snapshot|nil]
 *
 * Call virDomainSnapshotGetParent[https://libvirt.org/html/libvirt-libvirt-domain.html#virDomainSnapshotGetParent]
 * to get the parent of this snapshot (nil will be returned if this is a root
 * snapshot).
 */
static VALUE libvirt_domain_snapshot_parent(int argc, VALUE *argv, VALUE s)
{
    virDomainSnapshotPtr snap;
    VALUE flags;
    virErrorPtr err;

    rb_scan_args(argc, argv, "01", &flags);

    snap = virDomainSnapshotGetParent(domain_snapshot_get(s),
                                      ruby_libvirt_value_to_uint(flags));
    if (snap == NULL) {
        /* snap may be NULL if there is a root, in which case we want to return
         * nil
         */
        err = virConnGetLastError(ruby_libvirt_connect_get(s));
        if (err->code == VIR_ERR_NO_DOMAIN_SNAPSHOT) {
            return Qnil;
        }

        ruby_libvirt_raise_error_if(snap == NULL, e_RetrieveError,
                                    "virDomainSnapshotGetParent",
                                    ruby_libvirt_connect_get(s));
    }

    return domain_snapshot_new(snap, s);
}

/*
 * call-seq:
 *   snapshot.current?(flags=0) -> [true|false]
 *
 * Call virDomainSnapshotIsCurrent[https://libvirt.org/html/libvirt-libvirt-domain.html#virDomainSnapshotIsCurrent]
 * to determine if the snapshot is the domain's current snapshot.
 */
static VALUE libvirt_domain_snapshot_current_p(int argc, VALUE *argv, VALUE s)
{
    VALUE flags;

    rb_scan_args(argc, argv, "01", &flags);

    ruby_libvirt_generate_call_truefalse(virDomainSnapshotIsCurrent,
                                         ruby_libvirt_connect_get(s),
                                         domain_snapshot_get(s),
                                         ruby_libvirt_value_to_uint(flags));
}

/*
 * call-seq:
 *   snapshot.has_metadata?(flags=0) -> [true|false]
 *
 * Call virDomainSnapshotHasMetadata[https://libvirt.org/html/libvirt-libvirt-domain.html#virDomainSnapshotHasMetadata]
 * to determine if the snapshot is associated with libvirt metadata.
 */
static VALUE libvirt_domain_snapshot_has_metadata_p(int argc, VALUE *argv,
                                                    VALUE s)
{
    VALUE flags;

    rb_scan_args(argc, argv, "01", &flags);

    ruby_libvirt_generate_call_truefalse(virDomainSnapshotHasMetadata,
                                         ruby_libvirt_connect_get(s),
                                         domain_snapshot_get(s),
                                         ruby_libvirt_value_to_uint(flags));
}

/*
 * call-seq:
 *   dom.memory_stats_period = Fixnum,flags=0
 *
 * Call virDomainSetMemoryStatsPeriod[https://libvirt.org/html/libvirt-libvirt-domain.html#virDomainSetMemoryStatsPeriod]
 * to set the memory statistics collection period.
 */
static VALUE libvirt_domain_memory_stats_period(VALUE d, VALUE in)
{
    VALUE period, flags;

    domain_input_to_fixnum_and_flags(in, &period, &flags);

    ruby_libvirt_generate_call_nil(virDomainSetMemoryStatsPeriod,
                                   ruby_libvirt_connect_get(d),
                                   ruby_libvirt_domain_get(d),
                                   NUM2INT(period),
                                   ruby_libvirt_value_to_uint(flags));
}

/*
 * call-seq:
 *   dom.fstrim(mountpoint=nil, minimum=0, flags=0) -> nil
 *
 * Call virDomainFSTrim[https://libvirt.org/html/libvirt-libvirt-domain.html#virDomainFSTrim]
 * to call FITRIM within the guest.
 */
static VALUE libvirt_domain_fstrim(int argc, VALUE *argv, VALUE d)
{
    VALUE mountpoint, minimum, flags;

    rb_scan_args(argc, argv, "03", &mountpoint, &minimum, &flags);

    ruby_libvirt_generate_call_nil(virDomainFSTrim, ruby_libvirt_connect_get(d),
                                   ruby_libvirt_domain_get(d),
                                   ruby_libvirt_get_cstring_or_null(mountpoint),
                                   ruby_libvirt_value_to_ulonglong(minimum),
                                   ruby_libvirt_value_to_uint(flags));
}

/*
 * call-seq:
 *   dom.block_rebase(disk, base=nil, bandwidth=0, flags=0) -> nil
 *
 * Call virDomainBlockRebase[https://libvirt.org/html/libvirt-libvirt-domain.html#virDomainBlockRebase]
 * to populate a disk image with data from its backing image chain.
 */
static VALUE libvirt_domain_block_rebase(int argc, VALUE *argv, VALUE d)
{
    VALUE disk, base, bandwidth, flags;

    rb_scan_args(argc, argv, "13", &disk, &base, &bandwidth, &flags);

    ruby_libvirt_generate_call_nil(virDomainBlockRebase,
                                   ruby_libvirt_connect_get(d),
                                   ruby_libvirt_domain_get(d),
                                   ruby_libvirt_get_cstring_or_null(disk),
                                   ruby_libvirt_get_cstring_or_null(base),
                                   ruby_libvirt_value_to_ulong(bandwidth),
                                   ruby_libvirt_value_to_uint(flags));
}

/*
 * call-seq:
 *   dom.open_channel(name, stream, flags=0) -> nil
 *
 * Call virDomainOpenChannel[https://libvirt.org/html/libvirt-libvirt-domain.html#virDomainOpenChannel]
 * to open a channel on a guest.  Note that name may be nil, in which case the
 * first channel on the guest is opened.
 */
static VALUE libvirt_domain_open_channel(int argc, VALUE *argv, VALUE d)
{
    VALUE name, st, flags;

    rb_scan_args(argc, argv, "21", &name, &st, &flags);

    ruby_libvirt_generate_call_nil(virDomainOpenChannel,
                                   ruby_libvirt_connect_get(d),
                                   ruby_libvirt_domain_get(d),
                                   ruby_libvirt_get_cstring_or_null(name),
                                   ruby_libvirt_stream_get(st),
                                   ruby_libvirt_value_to_uint(flags));
}

/*
 * call-seq:
 *   dom.create_with_files(fds=nil, flags=0) -> nil
 *
 * Call virDomainCreateWithFiles[https://libvirt.org/html/libvirt-libvirt-domain.html#virDomainCreateWithFiles]
 * to launch a defined domain with a set of open file descriptors.
 */
static VALUE libvirt_domain_create_with_files(int argc, VALUE *argv, VALUE d)
{
    VALUE fds, flags;
    int *files;
    unsigned int numfiles, i;

    rb_scan_args(argc, argv, "02", &fds, &flags);

    if (TYPE(fds) == T_NIL) {
        files = NULL;
        numfiles = 0;
    }
    else if (TYPE(fds) == T_ARRAY) {
        numfiles = RARRAY_LEN(fds);
        files = alloca(numfiles * sizeof(int));
        for (i = 0; i < numfiles; i++) {
            files[i] = NUM2INT(rb_ary_entry(fds, i));
        }
    }
    else {
        rb_raise(rb_eTypeError, "wrong argument type (expected Array)");
    }

    ruby_libvirt_generate_call_nil(virDomainCreateWithFiles,
                                   ruby_libvirt_connect_get(d),
                                   ruby_libvirt_domain_get(d),
                                   numfiles, files,
                                   ruby_libvirt_value_to_uint(flags));
}

/*
 * call-seq:
 *   dom.open_graphics(fd, idx=0, flags=0) -> nil
 *
 * Call virDomainOpenGraphics[https://libvirt.org/html/libvirt-libvirt-domain.html#virDomainOpenGraphics]
 * to connect a file descriptor to the graphics backend of the domain.
 */
static VALUE libvirt_domain_open_graphics(int argc, VALUE *argv, VALUE d)
{
    VALUE fd, idx, flags;

    rb_scan_args(argc, argv, "12", &fd, &idx, &flags);

    ruby_libvirt_generate_call_nil(virDomainOpenGraphics,
                                   ruby_libvirt_connect_get(d),
                                   ruby_libvirt_domain_get(d),
                                   ruby_libvirt_value_to_uint(idx), NUM2INT(fd),
                                   ruby_libvirt_value_to_uint(flags));
}

/*
 * call-seq:
 *   dom.pmwakeup(flags=0) -> nil
 *
 * Call virDomainPMWakeup[https://libvirt.org/html/libvirt-libvirt-domain.html#virDomainPMWakeup]
 * to inject a wakeup into the guest.
 */
static VALUE libvirt_domain_pmwakeup(int argc, VALUE *argv, VALUE d)
{
    VALUE flags;

    rb_scan_args(argc, argv, "01", &flags);

    ruby_libvirt_generate_call_nil(virDomainPMWakeup,
                                   ruby_libvirt_connect_get(d),
                                   ruby_libvirt_domain_get(d),
                                   ruby_libvirt_value_to_uint(flags));
}

/*
 * call-seq:
 *   dom.block_resize(disk, size, flags=0) -> nil
 *
 * Call virDomainBlockResize[https://libvirt.org/html/libvirt-libvirt-domain.html#virDomainBlockResize]
 * to resize a block device of domain.
 */
static VALUE libvirt_domain_block_resize(int argc, VALUE *argv, VALUE d)
{
    VALUE disk, size, flags;

    rb_scan_args(argc, argv, "21", &disk, &size, &flags);

    ruby_libvirt_generate_call_nil(virDomainBlockResize,
                                   ruby_libvirt_connect_get(d),
                                   ruby_libvirt_domain_get(d),
                                   StringValueCStr(disk), NUM2ULL(size),
                                   ruby_libvirt_value_to_uint(flags));
}

/*
 * call-seq:
 *   dom.pmsuspend_for_duration(target, duration, flags=0) -> nil
 *
 * Call virDomainPMSuspendForDuration[https://libvirt.org/html/libvirt-libvirt-domain.html#virDomainPMSuspendForDuration]
 * to have the domain enter the target power management suspend level.
 */
static VALUE libvirt_domain_pmsuspend_for_duration(int argc, VALUE *argv,
                                                   VALUE d)
{
    VALUE target, duration, flags;

    rb_scan_args(argc, argv, "21", &target, &duration, &flags);

    ruby_libvirt_generate_call_nil(virDomainPMSuspendForDuration,
                                   ruby_libvirt_connect_get(d),
                                   ruby_libvirt_domain_get(d),
                                   NUM2UINT(target), NUM2ULL(duration),
                                   ruby_libvirt_value_to_uint(flags));
}

/*
 * call-seq:
 *   dom.migrate_compression_cache(flags=0) -> Fixnum
 *
 * Call virDomainMigrateGetCompressionCache[https://libvirt.org/html/libvirt-libvirt-domain.html#virDomainMigrateGetCompressionCache]
 * to get the current size of the migration cache.
 */
static VALUE libvirt_domain_migrate_compression_cache(int argc, VALUE *argv,
                                                      VALUE d)
{
    VALUE flags;
    int ret;
    unsigned long long cachesize;

    rb_scan_args(argc, argv, "01", &flags);

    ret = virDomainMigrateGetCompressionCache(ruby_libvirt_domain_get(d),
                                              &cachesize,
                                              ruby_libvirt_value_to_uint(flags));
    ruby_libvirt_raise_error_if(ret < 0, e_RetrieveError,
                                "virDomainMigrateGetCompressionCache",
                                ruby_libvirt_connect_get(d));

    return ULL2NUM(cachesize);
}

/*
 * call-seq:
 *   dom.migrate_compression_cache = Fixnum,flags=0
 *
 * Call virDomainMigrateSetCompressionCache[https://libvirt.org/html/libvirt-libvirt-domain.html#virDomainMigrateSetCompressionCache]
 * to set the current size of the migration cache.
 */
static VALUE libvirt_domain_migrate_compression_cache_equal(VALUE d, VALUE in)
{
    VALUE cachesize, flags;

    domain_input_to_fixnum_and_flags(in, &cachesize, &flags);

    ruby_libvirt_generate_call_nil(virDomainMigrateSetCompressionCache,
                                   ruby_libvirt_connect_get(d),
                                   ruby_libvirt_domain_get(d),
                                   NUM2ULL(cachesize),
                                   ruby_libvirt_value_to_uint(flags));
}

/*
 * call-seq:
 *   dom.disk_errors(flags=0) -> Hash
 *
 * Call virDomainGetDiskErrors[https://libvirt.org/html/libvirt-libvirt-domain.html#virDomainGetDiskErrors]
 * to get errors on disks in the domain.
 */
static VALUE libvirt_domain_disk_errors(int argc, VALUE *argv, VALUE d)
{
    VALUE flags, hash;
    int maxerr, ret, i;
    virDomainDiskErrorPtr errors;

    rb_scan_args(argc, argv, "01", &flags);

    maxerr = virDomainGetDiskErrors(ruby_libvirt_domain_get(d), NULL, 0,
                                    ruby_libvirt_value_to_uint(flags));
    ruby_libvirt_raise_error_if(maxerr < 0, e_RetrieveError,
                                "virDomainGetDiskErrors",
                                ruby_libvirt_connect_get(d));

    errors = alloca(maxerr * sizeof(virDomainDiskError));

    ret = virDomainGetDiskErrors(ruby_libvirt_domain_get(d), errors, maxerr,
                                 ruby_libvirt_value_to_uint(flags));
    ruby_libvirt_raise_error_if(ret < 0, e_RetrieveError,
                                "virDomainGetDiskErrors",
                                ruby_libvirt_connect_get(d));

    hash = rb_hash_new();

    for (i = 0; i < ret; i++) {
        rb_hash_aset(hash, rb_str_new2(errors[i].disk),
                     INT2NUM(errors[i].error));
    }

    return hash;
}

/*
 * call-seq:
 *   dom.emulator_pin_info(flags=0) -> Array
 *
 * Call virDomainGetEmulatorPinInfo[https://libvirt.org/html/libvirt-libvirt-domain.html#virDomainGetEmulatorPinInfo]
 * to an array representing the mapping of emulator threads to physical CPUs.
 * For each physical CPU in the machine, the array offset corresponding to that
 * CPU is 'true' if an emulator thread is running on that CPU, and 'false'
 * otherwise.
 */
static VALUE libvirt_domain_emulator_pin_info(int argc, VALUE *argv, VALUE d)
{
    int maxcpus, ret, j;
    size_t cpumaplen;
    unsigned char *cpumap;
    VALUE emulator2cpumap, flags;

    rb_scan_args(argc, argv, "01", &flags);

    maxcpus = ruby_libvirt_get_maxcpus(ruby_libvirt_connect_get(d));

    cpumaplen = VIR_CPU_MAPLEN(maxcpus);

    cpumap = alloca(sizeof(unsigned char) * cpumaplen);

    ret = virDomainGetEmulatorPinInfo(ruby_libvirt_domain_get(d), cpumap,
                                      cpumaplen,
                                      ruby_libvirt_value_to_uint(flags));
    ruby_libvirt_raise_error_if(ret < 0, e_RetrieveError,
                                "virDomainGetEmulatorPinInfo",
                                ruby_libvirt_connect_get(d));

    emulator2cpumap = rb_ary_new();

    for (j = 0; j < maxcpus; j++) {
        rb_ary_push(emulator2cpumap, VIR_CPU_USABLE(cpumap, cpumaplen,
                                                    0, j) ? Qtrue : Qfalse);
    }

    return emulator2cpumap;
}

/*
 * call-seq:
 *   dom.pin_emulator(cpulist, flags=0) -> nil
 *
 * Call virDomainPinVcpu[https://libvirt.org/html/libvirt-libvirt-domain.html#virDomainPinVcpu]
 * to pin the emulator to a range of physical processors.  The cpulist should
 * be an array of Fixnums representing the physical processors this domain's
 * emulator should be allowed to be scheduled on.
 */
static VALUE libvirt_domain_pin_emulator(int argc, VALUE *argv, VALUE d)
{
    VALUE cpulist, flags, e;
    int i, maxcpus, cpumaplen;
    unsigned char *cpumap;

    rb_scan_args(argc, argv, "11", &cpulist, &flags);

    Check_Type(cpulist, T_ARRAY);

    maxcpus = ruby_libvirt_get_maxcpus(ruby_libvirt_connect_get(d));

    cpumaplen = VIR_CPU_MAPLEN(maxcpus);

    cpumap = alloca(sizeof(unsigned char) * cpumaplen);
    MEMZERO(cpumap, unsigned char, cpumaplen);

    for (i = 0; i < RARRAY_LEN(cpulist); i++) {
        e = rb_ary_entry(cpulist, i);
        VIR_USE_CPU(cpumap, NUM2UINT(e));
    }

    ruby_libvirt_generate_call_nil(virDomainPinEmulator,
                                   ruby_libvirt_connect_get(d),
                                   ruby_libvirt_domain_get(d), cpumap,
                                   cpumaplen,
                                   ruby_libvirt_value_to_uint(flags));
}

/*
 * call-seq:
 *   dom.security_label_list -> [ Libvirt::Domain::SecurityLabel ]
 *
 * Call virDomainGetSecurityLabelList[https://libvirt.org/html/libvirt-libvirt-domain.html#virDomainGetSecurityLabelList]
 * to retrieve the security labels applied to this domain.
 */
static VALUE libvirt_domain_security_label_list(VALUE d)
{
    virSecurityLabelPtr seclabels;
    int r, i;
    VALUE result, tmp;

    r = virDomainGetSecurityLabelList(ruby_libvirt_domain_get(d), &seclabels);
    ruby_libvirt_raise_error_if(r < 0, e_RetrieveError,
                                "virDomainGetSecurityLabel",
                                ruby_libvirt_connect_get(d));

    result = rb_ary_new2(r);

    for (i = 0; i < r; i++) {
        tmp = rb_class_new_instance(0, NULL, c_domain_security_label);
        rb_iv_set(tmp, "@label", rb_str_new2(seclabels[i].label));
        rb_iv_set(tmp, "@enforcing", INT2NUM(seclabels[i].enforcing));

        rb_ary_store(result, i, tmp);
    }

    return result;
}

struct params_to_hash_arg {
    virTypedParameterPtr params;
    int nparams;
    VALUE result;
};

static VALUE params_to_hash(VALUE in)
{
    struct params_to_hash_arg *args = (struct params_to_hash_arg *)in;
    int i;

    for (i = 0; i < args->nparams; i++) {
        ruby_libvirt_typed_params_to_hash(args->params, i, args->result);
    }

    return Qnil;
}

/*
 * call-seq:
 *   dom.job_stats -> Hash
 *
 * Call virDomainGetJobStats[https://libvirt.org/html/libvirt-libvirt-domain.html#virDomainGetJobStats]
 * to retrieve information about progress of a background job on a domain.
 */
static VALUE libvirt_domain_job_stats(int argc, VALUE *argv, VALUE d)
{
    VALUE flags, result;
    int type, exception = 0, nparams = 0, r;
    virTypedParameterPtr params = NULL;
    struct params_to_hash_arg args;
    struct ruby_libvirt_hash_aset_arg asetargs;

    rb_scan_args(argc, argv, "01", &flags);

    result = rb_hash_new();

    r = virDomainGetJobStats(ruby_libvirt_domain_get(d), &type, &params,
                             &nparams, ruby_libvirt_value_to_uint(flags));
    ruby_libvirt_raise_error_if(r < 0, e_RetrieveError, "virDomainGetJobStats",
                                ruby_libvirt_connect_get(d));

    /* since virDomainGetJobsStats() allocated memory, we need to wrap all
     * calls below to make sure we don't leak memory
     */

    asetargs.hash = result;
    asetargs.name = "type";
    asetargs.val = INT2NUM(type);
    rb_protect(ruby_libvirt_hash_aset_wrap, (VALUE)&asetargs, &exception);
    if (exception) {
        virTypedParamsFree(params, nparams);
        rb_jump_tag(exception);
    }

    args.params = params;
    args.nparams = nparams;
    args.result = result;
    result = rb_protect(params_to_hash, (VALUE)&args, &exception);
    if (exception) {
        virTypedParamsFree(params, nparams);
        rb_jump_tag(exception);
    }

    virTypedParamsFree(params, nparams);

    return result;
}

static const char *iotune_nparams(VALUE d, unsigned int flags, void *opaque,
                                  int *nparams)
{
    VALUE disk = (VALUE)opaque;

    if (virDomainGetBlockIoTune(ruby_libvirt_domain_get(d),
                                ruby_libvirt_get_cstring_or_null(disk), NULL,
                                nparams, flags) < 0) {
        return "virDomainGetBlockIoTune";
    }

    return NULL;
}

static const char *iotune_get(VALUE d, unsigned int flags, void *voidparams,
                              int *nparams, void *opaque)
{
    virTypedParameterPtr params = (virTypedParameterPtr)voidparams;
    VALUE disk = (VALUE)opaque;

    if (virDomainGetBlockIoTune(ruby_libvirt_domain_get(d),
                                ruby_libvirt_get_cstring_or_null(disk), params,
                                nparams, flags) < 0) {
        return "virDomainGetBlockIoTune";
    }
    return NULL;
}

static const char *iotune_set(VALUE d, unsigned int flags,
                              virTypedParameterPtr params, int nparams,
                              void *opaque)
{
    VALUE disk = (VALUE)opaque;

    if (virDomainSetBlockIoTune(ruby_libvirt_domain_get(d),
                                StringValueCStr(disk), params, nparams,
                                flags) < 0) {
        return "virDomainSetBlockIoTune";
    }

    return NULL;
}

/*
 * call-seq:
 *   dom.block_iotune(disk=nil, flags=0) -> Hash
 *
 * Call virDomainGetBlockIoTune[https://libvirt.org/html/libvirt-libvirt-domain.html#virDomainGetBlockIoTune]
 * to retrieve all of the block IO tune parameters for this domain.  The keys
 * and values in the hash that is returned are hypervisor specific.
 */
static VALUE libvirt_domain_block_iotune(int argc, VALUE *argv, VALUE d)
{
    VALUE disk, flags;

    rb_scan_args(argc, argv, "02", &disk, &flags);

    return ruby_libvirt_get_typed_parameters(d,
                                             ruby_libvirt_value_to_uint(flags),
                                             (void *)disk, iotune_nparams,
                                             iotune_get);
}

static struct ruby_libvirt_typed_param iotune_allowed[] = {
    {VIR_DOMAIN_BLOCK_IOTUNE_TOTAL_BYTES_SEC, VIR_TYPED_PARAM_ULLONG},
    {VIR_DOMAIN_BLOCK_IOTUNE_READ_BYTES_SEC, VIR_TYPED_PARAM_ULLONG},
    {VIR_DOMAIN_BLOCK_IOTUNE_WRITE_BYTES_SEC, VIR_TYPED_PARAM_ULLONG},
    {VIR_DOMAIN_BLOCK_IOTUNE_TOTAL_IOPS_SEC, VIR_TYPED_PARAM_ULLONG},
    {VIR_DOMAIN_BLOCK_IOTUNE_READ_IOPS_SEC, VIR_TYPED_PARAM_ULLONG},
    {VIR_DOMAIN_BLOCK_IOTUNE_WRITE_IOPS_SEC, VIR_TYPED_PARAM_ULLONG},
    {VIR_DOMAIN_BLOCK_IOTUNE_SIZE_IOPS_SEC, VIR_TYPED_PARAM_ULLONG},
};

/*
 * call-seq:
 *   dom.block_iotune = disk,Hash,flags=0
 *
 * Call virDomainSetBlockIoTune[https://libvirt.org/html/libvirt-libvirt-domain.html#virDomainSetBlockIoTune]
 * to set the block IO tune parameters for the supplied disk on this domain.
 * The keys and values in the input hash are hypervisor specific.
 */
static VALUE libvirt_domain_block_iotune_equal(VALUE d, VALUE in)
{
    VALUE disk, hash, flags;

    Check_Type(in, T_ARRAY);

    if (RARRAY_LEN(in) == 2) {
        disk = rb_ary_entry(in, 0);
        hash = rb_ary_entry(in, 1);
        flags = INT2NUM(0);
    }
    else if (RARRAY_LEN(in) == 3) {
        disk = rb_ary_entry(in, 0);
        hash = rb_ary_entry(in, 1);
        flags = rb_ary_entry(in, 2);
    }
    else {
        rb_raise(rb_eArgError, "wrong number of arguments (%ld for 2 or 3)",
                 RARRAY_LEN(in));
    }

    return ruby_libvirt_set_typed_parameters(d, hash, NUM2UINT(flags),
                                             (void *)disk, iotune_allowed,
                                             ARRAY_SIZE(iotune_allowed),
                                             iotune_set);
}

/*
 * call-seq:
 *   dom.block_commit(disk, base=nil, top=nil, bandwidth=0, flags=0) -> nil
 *
 * Call virDomainBlockCommit[https://libvirt.org/html/libvirt-libvirt-domain.html#virDomainBlockCommit]
 * to commit changes from a top-level backing file into a lower level base file.
 */
static VALUE libvirt_domain_block_commit(int argc, VALUE *argv, VALUE d)
{
    VALUE disk, base, top, bandwidth, flags;

    rb_scan_args(argc, argv, "14", &disk, &base, &top, &bandwidth, &flags);

    ruby_libvirt_generate_call_nil(virDomainBlockCommit,
                                   ruby_libvirt_connect_get(d),
                                   ruby_libvirt_domain_get(d),
                                   StringValueCStr(disk),
                                   ruby_libvirt_get_cstring_or_null(base),
                                   ruby_libvirt_get_cstring_or_null(top),
                                   ruby_libvirt_value_to_ulong(bandwidth),
                                   ruby_libvirt_value_to_uint(flags));
}

/*
 * call-seq:
 *   dom.block_pull(disk, bandwidth=0, flags=0) -> nil
 *
 * Call virDomainBlockPull[https://libvirt.org/html/libvirt-libvirt-domain.html#virDomainBlockPull]
 * to pull changes from a backing file into a disk image.
 */
static VALUE libvirt_domain_block_pull(int argc, VALUE *argv, VALUE d)
{
    VALUE disk, bandwidth = RUBY_Qnil, flags = RUBY_Qnil;

    rb_scan_args(argc, argv, "12", &disk, &bandwidth, &flags);

    ruby_libvirt_generate_call_nil(virDomainBlockPull,
                                   ruby_libvirt_connect_get(d),
                                   ruby_libvirt_domain_get(d),
                                   StringValueCStr(disk),
                                   ruby_libvirt_value_to_ulong(bandwidth),
                                   ruby_libvirt_value_to_uint(flags));
}

/*
 * call-seq:
 *   dom.block_job_speed = disk,bandwidth=0,flags=0
 *
 * Call virDomainBlockJobSetSpeed[https://libvirt.org/html/libvirt-libvirt-domain.html#virDomainBlockJobSetSpeed]
 * to set the maximum allowable bandwidth a block job may consume.
 */
static VALUE libvirt_domain_block_job_speed_equal(VALUE d, VALUE in)
{
    VALUE disk, bandwidth, flags;

    if (TYPE(in) == T_STRING) {
        disk = in;
        bandwidth = INT2NUM(0);
        flags = INT2NUM(0);
    }
    else if (TYPE(in) == T_ARRAY) {
        if (RARRAY_LEN(in) == 2) {
            disk = rb_ary_entry(in, 0);
            bandwidth = rb_ary_entry(in, 1);
            flags = INT2NUM(0);
        }
        else if (RARRAY_LEN(in) == 3) {
            disk = rb_ary_entry(in, 0);
            bandwidth = rb_ary_entry(in, 1);
            flags = rb_ary_entry(in, 2);
        }
        else {
            rb_raise(rb_eArgError, "wrong number of arguments (%ld for 2 or 3)",
                     RARRAY_LEN(in));
        }
    }
    else {
        rb_raise(rb_eTypeError,
                 "wrong argument type (expected Number or Array)");
    }

    ruby_libvirt_generate_call_nil(virDomainBlockJobSetSpeed,
                                   ruby_libvirt_connect_get(d),
                                   ruby_libvirt_domain_get(d),
                                   StringValueCStr(disk),
                                   NUM2UINT(bandwidth), NUM2UINT(flags));
}

/*
 * call-seq:
 *   dom.block_job_info(disk, flags=0) -> Libvirt::Domain::BlockJobInfo
 *
 * Call virDomainGetBlockJobInfo[https://libvirt.org/html/libvirt-libvirt-domain.html#virDomainGetBlockJobInfo]
 * to get block job information for a given disk.
 */
static VALUE libvirt_domain_block_job_info(int argc, VALUE *argv, VALUE d)
{
    VALUE disk, flags = RUBY_Qnil, result;
    virDomainBlockJobInfo info;
    int r;

    rb_scan_args(argc, argv, "11", &disk, &flags);

    memset(&info, 0, sizeof(virDomainBlockJobInfo));

    r = virDomainGetBlockJobInfo(ruby_libvirt_domain_get(d),
                                 StringValueCStr(disk), &info,
                                 ruby_libvirt_value_to_uint(flags));
    ruby_libvirt_raise_error_if(r < 0, e_RetrieveError,
                                "virDomainGetBlockJobInfo",
                                ruby_libvirt_connect_get(d));

    result = rb_class_new_instance(0, NULL, c_domain_block_job_info);
    rb_iv_set(result, "@type", UINT2NUM(info.type));
    rb_iv_set(result, "@bandwidth", ULONG2NUM(info.bandwidth));
    rb_iv_set(result, "@cur", ULL2NUM(info.cur));
    rb_iv_set(result, "@end", ULL2NUM(info.end));

    return result;
}

/*
 * call-seq:
 *   dom.block_job_abort(disk, flags=0) -> nil
 *
 * Call virDomainBlockJobAbort[https://libvirt.org/html/libvirt-libvirt-domain.html#virDomainBlockJobAbort]
 * to cancel an active block job on the given disk.
 */
static VALUE libvirt_domain_block_job_abort(int argc, VALUE *argv, VALUE d)
{
    VALUE disk, flags = RUBY_Qnil;

    rb_scan_args(argc, argv, "11", &disk, &flags);

    ruby_libvirt_generate_call_nil(virDomainBlockJobAbort,
                                   ruby_libvirt_connect_get(d),
                                   ruby_libvirt_domain_get(d),
                                   StringValueCStr(disk),
                                   ruby_libvirt_value_to_uint(flags));
}

static const char *interface_nparams(VALUE d, unsigned int flags, void *opaque,
                                     int *nparams)
{
    VALUE device = (VALUE)opaque;

    if (virDomainGetInterfaceParameters(ruby_libvirt_domain_get(d),
                                        StringValueCStr(device), NULL, nparams,
                                        flags) < 0) {
        return "virDomainGetInterfaceParameters";
    }

    return NULL;
}

static const char *interface_get(VALUE d, unsigned int flags, void *voidparams,
                                 int *nparams, void *opaque)
{
    virTypedParameterPtr params = (virTypedParameterPtr)voidparams;
    VALUE interface = (VALUE)opaque;

    if (virDomainGetInterfaceParameters(ruby_libvirt_domain_get(d),
                                        StringValueCStr(interface), params,
                                        nparams, flags) < 0) {
        return "virDomainGetInterfaceParameters";
    }
    return NULL;
}

static const char *interface_set(VALUE d, unsigned int flags,
                                 virTypedParameterPtr params, int nparams,
                                 void *opaque)
{
    VALUE device = (VALUE)opaque;

    if (virDomainSetInterfaceParameters(ruby_libvirt_domain_get(d),
                                        StringValueCStr(device), params,
                                        nparams, flags) < 0) {
        return "virDomainSetIntefaceParameters";
    }

    return NULL;
}

/*
 * call-seq:
 *   dom.interface_parameters(interface, flags=0) -> Hash
 *
 * Call virDomainGetInterfaceParameters[https://libvirt.org/html/libvirt-libvirt-domain.html#virDomainGetInterfaceParameters]
 * to retrieve the interface parameters for the given interface on this domain.
 * The keys and values in the hash that is returned are hypervisor specific.
 */
static VALUE libvirt_domain_interface_parameters(int argc, VALUE *argv, VALUE d)
{
    VALUE device = RUBY_Qnil, flags = RUBY_Qnil;

    rb_scan_args(argc, argv, "11", &device, &flags);

    Check_Type(device, T_STRING);

    return ruby_libvirt_get_typed_parameters(d,
                                             ruby_libvirt_value_to_uint(flags),
                                             (void *)device,
                                             interface_nparams, interface_get);
}

static struct ruby_libvirt_typed_param interface_allowed[] = {
    {VIR_DOMAIN_BANDWIDTH_IN_AVERAGE, VIR_TYPED_PARAM_UINT},
    {VIR_DOMAIN_BANDWIDTH_IN_PEAK, VIR_TYPED_PARAM_UINT},
    {VIR_DOMAIN_BANDWIDTH_IN_BURST, VIR_TYPED_PARAM_UINT},
    {VIR_DOMAIN_BANDWIDTH_OUT_AVERAGE, VIR_TYPED_PARAM_UINT},
    {VIR_DOMAIN_BANDWIDTH_OUT_PEAK, VIR_TYPED_PARAM_UINT},
    {VIR_DOMAIN_BANDWIDTH_OUT_BURST, VIR_TYPED_PARAM_UINT},
};

/*
 * call-seq:
 *   dom.interface_parameters = device,Hash,flags=0
 *
 * Call virDomainSetInterfaceParameters[https://libvirt.org/html/libvirt-libvirt-domain.html#virDomainSetInterfaceParameters]
 * to set the interface parameters for the supplied device on this domain.
 * The keys and values in the input hash are hypervisor specific.
 */
static VALUE libvirt_domain_interface_parameters_equal(VALUE d, VALUE in)
{
    VALUE device, hash, flags;

    Check_Type(in, T_ARRAY);

    if (RARRAY_LEN(in) == 2) {
        device = rb_ary_entry(in, 0);
        hash = rb_ary_entry(in, 1);
        flags = INT2NUM(0);
    }
    else if (RARRAY_LEN(in) == 3) {
        device = rb_ary_entry(in, 0);
        hash = rb_ary_entry(in, 1);
        flags = rb_ary_entry(in, 2);
    }
    else {
        rb_raise(rb_eArgError, "wrong number of arguments (%ld for 2 or 3)",
                 RARRAY_LEN(in));
    }

    return ruby_libvirt_set_typed_parameters(d, hash,
                                             ruby_libvirt_value_to_uint(flags),
                                             (void *)device, interface_allowed,
                                             ARRAY_SIZE(interface_allowed),
                                             interface_set);
}

static const char *block_stats_nparams(VALUE d, unsigned int flags,
                                       void *opaque, int *nparams)
{
    VALUE disk = (VALUE)opaque;

    if (virDomainBlockStatsFlags(ruby_libvirt_domain_get(d),
                                 StringValueCStr(disk), NULL, nparams,
                                 flags) < 0) {
        return "virDomainBlockStatsFlags";
    }

    return NULL;
}

static const char *block_stats_get(VALUE d, unsigned int flags,
                                   void *voidparams, int *nparams, void *opaque)
{
    virTypedParameterPtr params = (virTypedParameterPtr)voidparams;
    VALUE disk = (VALUE)opaque;

    if (virDomainBlockStatsFlags(ruby_libvirt_domain_get(d),
                                 StringValueCStr(disk), params, nparams,
                                 flags) < 0) {
        return "virDomainBlockStatsFlags";
    }
    return NULL;
}

/*
 * call-seq:
 *   dom.block_stats_flags(disk, flags=0) -> Hash
 *
 * Call virDomainGetBlockStatsFlags[https://libvirt.org/html/libvirt-libvirt-domain.html#virDomainGetBlockStatsFlags]
 * to retrieve the block statistics for the given disk on this domain.
 * The keys and values in the hash that is returned are hypervisor specific.
 */
static VALUE libvirt_domain_block_stats_flags(int argc, VALUE *argv, VALUE d)
{
    VALUE disk = RUBY_Qnil, flags = RUBY_Qnil;

    rb_scan_args(argc, argv, "11", &disk, &flags);

    Check_Type(disk, T_STRING);

    return ruby_libvirt_get_typed_parameters(d,
                                             ruby_libvirt_value_to_uint(flags),
                                             (void *)disk,
                                             block_stats_nparams,
                                             block_stats_get);
}

static const char *numa_nparams(VALUE d, unsigned int flags,
                                void *RUBY_LIBVIRT_UNUSED(opaque),
                                int *nparams)
{
    if (virDomainGetNumaParameters(ruby_libvirt_domain_get(d), NULL, nparams,
                                   flags) < 0) {
        return "virDomainGetNumaParameters";
    }

    return NULL;
}

static const char *numa_get(VALUE d, unsigned int flags, void *voidparams,
                            int *nparams, void *RUBY_LIBVIRT_UNUSED(opaque))
{
    virTypedParameterPtr params = (virTypedParameterPtr)voidparams;

    if (virDomainGetNumaParameters(ruby_libvirt_domain_get(d), params, nparams,
                                   flags) < 0) {
        return "virDomainGetNumaParameters";
    }
    return NULL;
}

static const char *numa_set(VALUE d, unsigned int flags,
                            virTypedParameterPtr params, int nparams,
                            void *RUBY_LIBVIRT_UNUSED(opaque))
{
    if (virDomainSetNumaParameters(ruby_libvirt_domain_get(d), params,
                                   nparams, flags) < 0) {
        return "virDomainSetNumaParameters";
    }

    return NULL;
}

/*
 * call-seq:
 *   dom.numa_parameters(flags=0) -> Hash
 *
 * Call virDomainGetNumaParameters[https://libvirt.org/html/libvirt-libvirt-domain.html#virDomainGetNumaParameters]
 * to retrieve the numa parameters for this domain.  The keys and values in
 * the hash that is returned are hypervisor specific.
 */
static VALUE libvirt_domain_numa_parameters(int argc, VALUE *argv, VALUE d)
{
    VALUE flags = RUBY_Qnil;

    rb_scan_args(argc, argv, "01", &flags);

    return ruby_libvirt_get_typed_parameters(d,
                                             ruby_libvirt_value_to_uint(flags),
                                             NULL, numa_nparams, numa_get);
}

static struct ruby_libvirt_typed_param numa_allowed[] = {
    {VIR_DOMAIN_NUMA_NODESET, VIR_TYPED_PARAM_STRING},
    {VIR_DOMAIN_NUMA_MODE, VIR_TYPED_PARAM_INT},
};

/*
 * call-seq:
 *   dom.numa_parameters = Hash,flags=0
 *
 * Call virDomainSetNumaParameters[https://libvirt.org/html/libvirt-libvirt-domain.html#virDomainSetNumaParameters]
 * to set the numa parameters for this domain.  The keys and values in the input
 * hash are hypervisor specific.
 */
static VALUE libvirt_domain_numa_parameters_equal(VALUE d, VALUE in)
{
    VALUE hash, flags;

    ruby_libvirt_assign_hash_and_flags(in, &hash, &flags);

    return ruby_libvirt_set_typed_parameters(d, hash,
                                             ruby_libvirt_value_to_uint(flags),
                                             NULL, numa_allowed,
                                             ARRAY_SIZE(numa_allowed),
                                             numa_set);
}

/*
 * call-seq:
 *   dom.lxc_open_namespace(flags=0) -> Array
 *
 * Call virDomainLxcOpenNamespace[https://libvirt.org/html/libvirt-libvirt-domain.html#virDomainLxcOpenNamespace]
 * to open an LXC namespace.  Note that this will only work on connections to
 * the LXC driver.  The call will return an array of open file descriptors;
 * these should be closed when use of them is finished.
 */
static VALUE libvirt_domain_lxc_open_namespace(int argc, VALUE *argv, VALUE d)
{
    VALUE flags = RUBY_Qnil, result;
    int *fdlist = NULL;
    int ret, i, exception = 0;
    struct ruby_libvirt_ary_store_arg args;

    rb_scan_args(argc, argv, "01", &flags);

    ret = virDomainLxcOpenNamespace(ruby_libvirt_domain_get(d),
                                    &fdlist, ruby_libvirt_value_to_uint(flags));
    ruby_libvirt_raise_error_if(ret < 0, e_RetrieveError,
                                "virDomainLxcOpenNamespace",
                                ruby_libvirt_connect_get(d));

    result = rb_protect(ruby_libvirt_ary_new2_wrap, (VALUE)&ret, &exception);
    if (exception) {
        goto error;
    }

    for (i = 0; i < ret; i++) {
        args.arr = result;
        args.index = i;
        /* from reading the ruby sources, INT2NUM can't possibly throw an
         * exception, so this can't leak.
         */
        args.elem = INT2NUM(fdlist[i]);

        rb_protect(ruby_libvirt_ary_store_wrap, (VALUE)&args, &exception);
        if (exception) {
            goto error;
        }
    }

    free(fdlist);

    return result;

error:
    for (i = 0; i < ret; i++) {
        close(fdlist[i]);
    }
    free(fdlist);
    rb_jump_tag(exception);
}

/*
 * call-seq:
 *   dom.qemu_agent_command(command, timeout=0, flags=0) -> String
 *
 * Call virDomainQemuAgentCommand[https://libvirt.org/html/libvirt-libvirt-domain.html#virDomainQemuAgentCommand]
 * to run an arbitrary command on the Qemu Agent.
 */
static VALUE libvirt_domain_qemu_agent_command(int argc, VALUE *argv, VALUE d)
{
    VALUE command, timeout = RUBY_Qnil, flags = RUBY_Qnil, result;
    char *ret;
    int exception = 0;

    rb_scan_args(argc, argv, "12", &command, &timeout, &flags);

    if (NIL_P(timeout)) {
        timeout = INT2NUM(VIR_DOMAIN_QEMU_AGENT_COMMAND_DEFAULT);
    }

    ret = virDomainQemuAgentCommand(ruby_libvirt_domain_get(d),
                                    StringValueCStr(command),
                                    ruby_libvirt_value_to_int(timeout),
                                    ruby_libvirt_value_to_uint(flags));
    ruby_libvirt_raise_error_if(ret == NULL, e_RetrieveError,
                                "virDomainQemuAgentCommand",
                                ruby_libvirt_connect_get(d));

    result = rb_protect(ruby_libvirt_str_new2_wrap, (VALUE)&ret, &exception);
    free(ret);
    if (exception) {
        rb_jump_tag(exception);
    }

    return result;
}

/*
 * call-seq:
 *   dom.lxc_enter_namespace(fds, flags=0) -> Array
 *
 * Call virDomainLxcEnterNamespace[https://libvirt.org/html/libvirt-libvirt-domain.html#virDomainLxcEnterNamespace]
 * to attach the process to the namespaces associated with the file descriptors
 * in the fds array.  Note that this call does not actually enter the namespace;
 * the next call to fork will do that.  Also note that this function will return
 * an array of old file descriptors that can be used to switch back to the
 * current namespace later.
 */
static VALUE libvirt_domain_lxc_enter_namespace(int argc, VALUE *argv, VALUE d)
{
    VALUE fds = RUBY_Qnil, flags = RUBY_Qnil, result;
    int *fdlist;
    int ret, exception = 0;
    int *oldfdlist;
    unsigned int noldfdlist, i;
    struct ruby_libvirt_ary_store_arg args;

    rb_scan_args(argc, argv, "11", &fds, &flags);

    Check_Type(fds, T_ARRAY);

    fdlist = alloca(sizeof(int) * RARRAY_LEN(fds));
    for (i = 0; i < RARRAY_LEN(fds); i++) {
        fdlist[i] = NUM2INT(rb_ary_entry(fds, i));
    }

    ret = virDomainLxcEnterNamespace(ruby_libvirt_domain_get(d),
                                     RARRAY_LEN(fds), fdlist, &noldfdlist,
                                     &oldfdlist,
                                     ruby_libvirt_value_to_uint(flags));
    ruby_libvirt_raise_error_if(ret < 0, e_RetrieveError,
                                "virDomainLxcEnterNamespace",
                                ruby_libvirt_connect_get(d));

    result = rb_protect(ruby_libvirt_ary_new2_wrap, (VALUE)&noldfdlist,
                        &exception);
    if (exception) {
        free(oldfdlist);
        rb_jump_tag(exception);
    }

    for (i = 0; i < noldfdlist; i++) {
        args.arr = result;
        args.index = i;
        /* from reading the ruby sources, INT2NUM can't possibly throw an
         * exception, so this can't leak.
         */
        args.elem = INT2NUM(oldfdlist[i]);

        rb_protect(ruby_libvirt_ary_store_wrap, (VALUE)&args, &exception);
        if (exception) {
            free(oldfdlist);
            rb_jump_tag(exception);
        }
    }

    free(oldfdlist);

    return result;
}

static struct ruby_libvirt_typed_param migrate3_allowed[] = {
    {VIR_MIGRATE_PARAM_URI, VIR_TYPED_PARAM_STRING},
    {VIR_MIGRATE_PARAM_DEST_NAME, VIR_TYPED_PARAM_STRING},
    {VIR_MIGRATE_PARAM_DEST_XML, VIR_TYPED_PARAM_STRING},
    {VIR_MIGRATE_PARAM_BANDWIDTH, VIR_TYPED_PARAM_ULLONG},
    {VIR_MIGRATE_PARAM_GRAPHICS_URI, VIR_TYPED_PARAM_STRING},
    {VIR_MIGRATE_PARAM_LISTEN_ADDRESS, VIR_TYPED_PARAM_STRING},
};

/*
 * call-seq:
 *   dom.migrate3(dconn, Hash=nil, flags=0) -> Libvirt::Domain
 *
 * Call virDomainMigrate3[https://libvirt.org/html/libvirt-libvirt-domain.html#virDomainMigrate3]
 * to migrate a domain from the host on this connection to the connection
 * referenced in dconn.
 */
static VALUE libvirt_domain_migrate3(int argc, VALUE *argv, VALUE d)
{
    VALUE dconn = RUBY_Qnil, hash = RUBY_Qnil, flags = RUBY_Qnil;
    virDomainPtr ddom = NULL;
    struct ruby_libvirt_parameter_assign_args args;
    unsigned long hashsize;

    rb_scan_args(argc, argv, "12", &dconn, &hash, &flags);

    Check_Type(hash, T_HASH);

    hashsize = RHASH_SIZE(hash);

    memset(&args, 0, sizeof(struct ruby_libvirt_parameter_assign_args));

    if (hashsize > 0) {
        args.allowed = migrate3_allowed;
        args.num_allowed = ARRAY_SIZE(migrate3_allowed);

        args.params = alloca(sizeof(virTypedParameter) * hashsize);
        args.i = 0;

        rb_hash_foreach(hash, ruby_libvirt_typed_parameter_assign,
                        (VALUE)&args);
    }

    ddom = virDomainMigrate3(ruby_libvirt_domain_get(d),
                             ruby_libvirt_connect_get(dconn), args.params,
                             args.i, ruby_libvirt_value_to_uint(flags));

    ruby_libvirt_raise_error_if(ddom == NULL, e_Error, "virDomainMigrate3",
                                ruby_libvirt_connect_get(d));

    return ruby_libvirt_domain_new(ddom, dconn);
}

/*
 * call-seq:
 *   dom.migrate_to_uri3(duri=nil, Hash=nil, flags=0) -> nil
 *
 * Call virDomainMigrateToURI3[https://libvirt.org/html/libvirt-libvirt-domain.html#virDomainMigrateToURI3]
 * to migrate a domain from the host on this connection to the host whose
 * libvirt URI is duri.
 */
static VALUE libvirt_domain_migrate_to_uri3(int argc, VALUE *argv, VALUE d)
{
    VALUE duri = RUBY_Qnil, hash = RUBY_Qnil, flags = RUBY_Qnil;
    struct ruby_libvirt_parameter_assign_args args;
    unsigned long hashsize;

    rb_scan_args(argc, argv, "03", &duri, &hash, &flags);

    Check_Type(hash, T_HASH);

    hashsize = RHASH_SIZE(hash);

    memset(&args, 0, sizeof(struct ruby_libvirt_parameter_assign_args));

    if (hashsize > 0) {
        args.allowed = migrate3_allowed;
        args.num_allowed = ARRAY_SIZE(migrate3_allowed);

        args.params = alloca(sizeof(virTypedParameter) * hashsize);
        args.i = 0;

        rb_hash_foreach(hash, ruby_libvirt_typed_parameter_assign,
                        (VALUE)&args);
    }

    ruby_libvirt_generate_call_nil(virDomainMigrateToURI3,
                                   ruby_libvirt_connect_get(d),
                                   ruby_libvirt_domain_get(d),
                                   ruby_libvirt_get_cstring_or_null(duri),
                                   args.params, args.i,
                                   ruby_libvirt_value_to_ulong(flags));
}

/*
 * call-seq:
 *   dom.cpu_stats(start_cpu=-1, numcpus=1, flags=0) -> Hash
 *
 * Call virDomainGetCPUStats[https://libvirt.org/html/libvirt-libvirt-domain.html#virDomainGetCPUStats]
 * to get statistics about CPU usage attributable to a single domain.  If
 * start_cpu is -1, then numcpus must be 1 and statistics attributable to the
 * entire domain is returned.  If start_cpu is any positive number, then it
 * represents which CPU to start with and numcpus represents how many
 * consecutive processors to query.
 */
static VALUE libvirt_domain_cpu_stats(int argc, VALUE *argv, VALUE d)
{
    VALUE start_cpu = RUBY_Qnil, numcpus = RUBY_Qnil, flags = RUBY_Qnil, result, tmp;
    int ret, nparams, j;
    unsigned int i;
    virTypedParameterPtr params;

    rb_scan_args(argc, argv, "03", &start_cpu, &numcpus, &flags);

    if (NIL_P(start_cpu)) {
        start_cpu = INT2NUM(-1);
    }

    if (NIL_P(numcpus)) {
        numcpus = INT2NUM(1);
    }

    if (NIL_P(flags)) {
        flags = INT2NUM(0);
    }

    if (NUM2INT(start_cpu) == -1) {
        nparams = virDomainGetCPUStats(ruby_libvirt_domain_get(d), NULL, 0,
                                       NUM2INT(start_cpu), NUM2UINT(numcpus),
                                       NUM2UINT(flags));
        ruby_libvirt_raise_error_if(nparams < 0, e_RetrieveError,
                                    "virDomainGetCPUStats",
                                    ruby_libvirt_connect_get(d));

        params = alloca(nparams * sizeof(virTypedParameter));

        ret = virDomainGetCPUStats(ruby_libvirt_domain_get(d), params, nparams,
                                   NUM2INT(start_cpu), NUM2UINT(numcpus),
                                   NUM2UINT(flags));
        ruby_libvirt_raise_error_if(ret < 0, e_RetrieveError,
                                    "virDomainGetCPUStats",
                                    ruby_libvirt_connect_get(d));

        result = rb_hash_new();
        tmp = rb_hash_new();
        for (j = 0; j < nparams; j++) {
            ruby_libvirt_typed_params_to_hash(params, j, tmp);
        }

        rb_hash_aset(result, rb_str_new2("all"), tmp);
    }
    else {
        nparams = virDomainGetCPUStats(ruby_libvirt_domain_get(d), NULL, 0, 0,
                                       1, NUM2UINT(flags));
        ruby_libvirt_raise_error_if(nparams < 0, e_RetrieveError,
                                    "virDomainGetCPUStats",
                                    ruby_libvirt_connect_get(d));

        params = alloca(nparams * NUM2UINT(numcpus) * sizeof(virTypedParameter));

        ret = virDomainGetCPUStats(ruby_libvirt_domain_get(d), params, nparams,
                                   NUM2INT(start_cpu), NUM2UINT(numcpus),
                                   NUM2UINT(flags));
        ruby_libvirt_raise_error_if(ret < 0, e_RetrieveError,
                                    "virDomainGetCPUStats",
                                    ruby_libvirt_connect_get(d));

        result = rb_hash_new();
        for (i = 0; i < NUM2UINT(numcpus); i++) {
            if (params[i * nparams].type == 0) {
                /* cpu is not in the map */
                continue;
            }
            tmp = rb_hash_new();
            for (j = 0; j < nparams; j++) {
                ruby_libvirt_typed_params_to_hash(params, j, tmp);
            }

            rb_hash_aset(result, INT2NUM(NUM2UINT(start_cpu) + i), tmp);
        }
    }

    return result;
}

/*
 * call-seq:
 *   dom.time(flags=0) -> Hash
 * Call virDomainGetTime[https://libvirt.org/html/libvirt-libvirt-domain.html#virDomainGetTime]
 * to get information about the guest time.
 */
static VALUE libvirt_domain_get_time(int argc, VALUE *argv, VALUE d)
{
    VALUE flags = RUBY_Qnil, result;
    long long seconds;
    unsigned int nseconds;
    int ret;

    rb_scan_args(argc, argv, "01", &flags);

    ret = virDomainGetTime(ruby_libvirt_domain_get(d), &seconds, &nseconds,
                           ruby_libvirt_value_to_uint(flags));
    ruby_libvirt_raise_error_if(ret < 0, e_Error, "virDomainGetTime",
                                ruby_libvirt_connect_get(d));

    result = rb_hash_new();
    rb_hash_aset(result, rb_str_new2("seconds"), LL2NUM(seconds));
    rb_hash_aset(result, rb_str_new2("nseconds"), UINT2NUM(nseconds));

    return result;
}

/*
 * call-seq:
 *   dom.time = Hash,flags=0
 * Call virDomainSetTime[https://libvirt.org/html/libvirt-libvirt-domain.html#virDomainSetTime]
 * to set guest time.
 */
static VALUE libvirt_domain_time_equal(VALUE d, VALUE in)
{
    VALUE hash, flags, seconds, nseconds;

    ruby_libvirt_assign_hash_and_flags(in, &hash, &flags);

    seconds = rb_hash_aref(hash, rb_str_new2("seconds"));
    nseconds = rb_hash_aref(hash, rb_str_new2("nseconds"));

    ruby_libvirt_generate_call_nil(virDomainSetTime,
                                   ruby_libvirt_connect_get(d),
                                   ruby_libvirt_domain_get(d),
                                   NUM2LL(seconds), NUM2UINT(nseconds),
                                   NUM2UINT(flags));
}

/*
 * call-seq:
 *   dom.core_dump_with_format(filename, dumpformat, flags=0) -> nil
 *
 * Call virDomainCoreDumpWithFormat[https://libvirt.org/html/libvirt-libvirt-domain.html#virDomainCoreDump]
 * to do a full memory dump of the domain to filename.
 */
static VALUE libvirt_domain_core_dump_with_format(int argc, VALUE *argv, VALUE d)
{
    VALUE to, dumpformat = RUBY_Qnil, flags = RUBY_Qnil;

    rb_scan_args(argc, argv, "21", &to, &dumpformat, &flags);

    ruby_libvirt_generate_call_nil(virDomainCoreDumpWithFormat,
                                   ruby_libvirt_connect_get(d),
                                   ruby_libvirt_domain_get(d),
                                   StringValueCStr(to),
                                   NUM2UINT(dumpformat),
                                   ruby_libvirt_value_to_uint(flags));
}

/*
 * call-seq:
 *   dom.fs_freeze(mountpoints=nil, flags=0) -> Fixnum
 *
 * Call virDomainFSFreeze[https://libvirt.org/html/libvirt-libvirt-domain.html#virDomainFSFreeze]
 * to freeze the specified filesystems within the guest.
 */
static VALUE libvirt_domain_fs_freeze(int argc, VALUE *argv, VALUE d)
{
    VALUE mountpoints = RUBY_Qnil, flags = RUBY_Qnil, entry;
    const char **mnt;
    unsigned int nmountpoints;
    int i;

    rb_scan_args(argc, argv, "02", &mountpoints, &flags);

    if (NIL_P(mountpoints)) {
        mnt = NULL;
        nmountpoints = 0;
    }
    else {
        Check_Type(mountpoints, T_ARRAY);

        nmountpoints = RARRAY_LEN(mountpoints);
        mnt = alloca(nmountpoints * sizeof(char *));

        for (i = 0; i < nmountpoints; i++) {
            entry = rb_ary_entry(mountpoints, i);
            mnt[i] = StringValueCStr(entry);
        }
    }

    ruby_libvirt_generate_call_int(virDomainFSFreeze,
                                   ruby_libvirt_connect_get(d),
                                   ruby_libvirt_domain_get(d),
                                   mnt, nmountpoints,
                                   ruby_libvirt_value_to_uint(flags));
}

/*
 * call-seq:
 *   dom.fs_thaw(mountpoints=nil, flags=0) -> Fixnum
 *
 * Call virDomainFSThaw[https://libvirt.org/html/libvirt-libvirt-domain.html#virDomainFSThaw]
 * to thaw the specified filesystems within the guest.
 */
static VALUE libvirt_domain_fs_thaw(int argc, VALUE *argv, VALUE d)
{
    VALUE mountpoints = RUBY_Qnil, flags = RUBY_Qnil, entry;
    const char **mnt;
    unsigned int nmountpoints;
    int i;

    rb_scan_args(argc, argv, "02", &mountpoints, &flags);

    if (NIL_P(mountpoints)) {
        mnt = NULL;
        nmountpoints = 0;
    }
    else {
        Check_Type(mountpoints, T_ARRAY);

        nmountpoints = RARRAY_LEN(mountpoints);
        mnt = alloca(nmountpoints * sizeof(char *));

        for (i = 0; i < nmountpoints; i++) {
            entry = rb_ary_entry(mountpoints, i);
            mnt[i] = StringValueCStr(entry);
        }
    }

    ruby_libvirt_generate_call_int(virDomainFSThaw,
                                   ruby_libvirt_connect_get(d),
                                   ruby_libvirt_domain_get(d),
                                   mnt, nmountpoints,
                                   ruby_libvirt_value_to_uint(flags));
}

struct fs_info_arg {
    virDomainFSInfoPtr *info;
    int ninfo;
};

static VALUE fs_info_wrap(VALUE arg)
{
    struct fs_info_arg *e = (struct fs_info_arg *)arg;
    VALUE aliases, entry, result;
    int i, j;

    result = rb_ary_new2(e->ninfo);

    for (i = 0; i < e->ninfo; i++) {
        aliases = rb_ary_new2(e->info[i]->ndevAlias);
        for (j = 0; j < e->info[i]->ndevAlias; j++) {
            rb_ary_store(aliases, j, rb_str_new2(e->info[i]->devAlias[j]));
        }

        entry = rb_hash_new();
        rb_hash_aset(entry, rb_str_new2("mountpoint"),
                     rb_str_new2(e->info[i]->mountpoint));
        rb_hash_aset(entry, rb_str_new2("name"),
                     rb_str_new2(e->info[i]->name));
        rb_hash_aset(entry, rb_str_new2("fstype"),
                     rb_str_new2(e->info[i]->fstype));
        rb_hash_aset(entry, rb_str_new2("aliases"), aliases);

        rb_ary_store(result, i, entry);
    }

    return result;
}

/*
 * call-seq:
 *   dom.fs_info(flags=0) -> [Hash]
 *
 * Call virDomainGetFSInfo[https://libvirt.org/html/libvirt-libvirt-domain.html#virDomainGetFSInfo]
 * to get information about the guest filesystems.
 */
static VALUE libvirt_domain_fs_info(int argc, VALUE *argv, VALUE d)
{
    VALUE flags = RUBY_Qnil, result;
    virDomainFSInfoPtr *info;
    int ret, i = 0, exception;
    struct fs_info_arg args;

    rb_scan_args(argc, argv, "01", &flags);

    ret = virDomainGetFSInfo(ruby_libvirt_domain_get(d), &info,
                             ruby_libvirt_value_to_uint(flags));
    ruby_libvirt_raise_error_if(ret < 0, e_Error, "virDomainGetFSInfo",
                                ruby_libvirt_connect_get(d));

    args.info = info;
    args.ninfo = ret;
    result = rb_protect(fs_info_wrap, (VALUE)&args, &exception);

    for (i = 0; i < ret; i++) {
        virDomainFSInfoFree(info[i]);
    }
    free(info);

    if (exception) {
        rb_jump_tag(exception);
    }

    return result;
}

/*
 * call-seq:
 *   dom.rename(name, flags=0) -> nil
 *
 * Call virDomainRename[https://libvirt.org/html/libvirt-libvirt-domain.html#virDomainRename]
 * to rename a domain.
 */
static VALUE libvirt_domain_rename(int argc, VALUE *argv, VALUE d)
{
    VALUE flags = RUBY_Qnil, name;

    rb_scan_args(argc, argv, "11", &name, &flags);

    ruby_libvirt_generate_call_nil(virDomainRename,
                                   ruby_libvirt_connect_get(d),
                                   ruby_libvirt_domain_get(d),
                                   StringValueCStr(name),
                                   ruby_libvirt_value_to_uint(flags));
}

/*
 * call-seq:
 *   dom.user_password = user,password,flags=0 -> nil
 *
 * Call virDomainSetUserPassword[https://libvirt.org/html/libvirt-libvirt-domain.html#virDomainSetUserPassword]
 * to set the user password on a domain.
 */
static VALUE libvirt_domain_user_password_equal(VALUE d, VALUE in)
{
    VALUE user, password, flags;

    Check_Type(in, T_ARRAY);

    if (RARRAY_LEN(in) == 2) {
        user = rb_ary_entry(in, 0);
        password = rb_ary_entry(in, 1);
        flags = INT2NUM(0);
    }
    else if (RARRAY_LEN(in) == 3) {
        user = rb_ary_entry(in, 0);
        password = rb_ary_entry(in, 1);
        flags = rb_ary_entry(in, 2);
    }
    else {
        rb_raise(rb_eArgError, "wrong number of arguments (%ld for 2 or 3)",
                 RARRAY_LEN(in));
    }

    ruby_libvirt_generate_call_nil(virDomainSetUserPassword,
                                   ruby_libvirt_connect_get(d),
                                   ruby_libvirt_domain_get(d),
                                   StringValueCStr(user),
                                   StringValueCStr(password),
                                   ruby_libvirt_value_to_uint(flags));
}

/*
 * Class Libvirt::Domain
 */
void ruby_libvirt_domain_init(void)
{
    c_domain = rb_define_class_under(m_libvirt, "Domain", rb_cObject);
    rb_undef_alloc_func(c_domain);
    rb_define_singleton_method(c_domain, "new",
                               ruby_libvirt_new_not_allowed, -1);

    rb_define_const(c_domain, "NOSTATE", INT2NUM(VIR_DOMAIN_NOSTATE));
    rb_define_const(c_domain, "RUNNING", INT2NUM(VIR_DOMAIN_RUNNING));
    rb_define_const(c_domain, "BLOCKED", INT2NUM(VIR_DOMAIN_BLOCKED));
    rb_define_const(c_domain, "PAUSED", INT2NUM(VIR_DOMAIN_PAUSED));
    rb_define_const(c_domain, "SHUTDOWN", INT2NUM(VIR_DOMAIN_SHUTDOWN));
    rb_define_const(c_domain, "SHUTOFF", INT2NUM(VIR_DOMAIN_SHUTOFF));
    rb_define_const(c_domain, "CRASHED", INT2NUM(VIR_DOMAIN_CRASHED));
    rb_define_const(c_domain, "PMSUSPENDED", INT2NUM(VIR_DOMAIN_PMSUSPENDED));

    /* virDomainMigrateFlags */
    rb_define_const(c_domain, "MIGRATE_LIVE", INT2NUM(VIR_MIGRATE_LIVE));
    rb_define_const(c_domain, "MIGRATE_PEER2PEER",
                    INT2NUM(VIR_MIGRATE_PEER2PEER));
    rb_define_const(c_domain, "MIGRATE_TUNNELLED",
                    INT2NUM(VIR_MIGRATE_TUNNELLED));
    rb_define_const(c_domain, "MIGRATE_PERSIST_DEST",
                    INT2NUM(VIR_MIGRATE_PERSIST_DEST));
    rb_define_const(c_domain, "MIGRATE_UNDEFINE_SOURCE",
                    INT2NUM(VIR_MIGRATE_UNDEFINE_SOURCE));
    rb_define_const(c_domain, "MIGRATE_PAUSED", INT2NUM(VIR_MIGRATE_PAUSED));
    rb_define_const(c_domain, "MIGRATE_NON_SHARED_DISK",
                    INT2NUM(VIR_MIGRATE_NON_SHARED_DISK));
    rb_define_const(c_domain, "MIGRATE_NON_SHARED_INC",
                    INT2NUM(VIR_MIGRATE_NON_SHARED_INC));
    rb_define_const(c_domain, "MIGRATE_CHANGE_PROTECTION",
                    INT2NUM(VIR_MIGRATE_CHANGE_PROTECTION));
    rb_define_const(c_domain, "MIGRATE_UNSAFE", INT2NUM(VIR_MIGRATE_UNSAFE));
    rb_define_const(c_domain, "MIGRATE_OFFLINE", INT2NUM(VIR_MIGRATE_OFFLINE));
    rb_define_const(c_domain, "MIGRATE_COMPRESSED",
                    INT2NUM(VIR_MIGRATE_COMPRESSED));
    rb_define_const(c_domain, "MIGRATE_ABORT_ON_ERROR",
                    INT2NUM(VIR_MIGRATE_ABORT_ON_ERROR));
    rb_define_const(c_domain, "MIGRATE_AUTO_CONVERGE",
                    INT2NUM(VIR_MIGRATE_AUTO_CONVERGE));
    rb_define_const(c_domain, "MIGRATE_RDMA_PIN_ALL",
                    INT2NUM(VIR_MIGRATE_RDMA_PIN_ALL));

    /* Ideally we would just have the "XML_SECURE" constant.  Unfortunately
     * we screwed up long ago, and we have to leave "DOMAIN_XML_SECURE" for
     * backwards compatibility.
     */
    rb_define_const(c_domain, "XML_SECURE", INT2NUM(VIR_DOMAIN_XML_SECURE));
    rb_define_const(c_domain, "DOMAIN_XML_SECURE",
                    INT2NUM(VIR_DOMAIN_XML_SECURE));
    /* Ideally we would just have the "XML_INACTIVE" constant.  Unfortunately
     * we screwed up long ago, and we have to leave "DOMAIN_XML_INACTIVE" for
     * backwards compatibility.
     */
    rb_define_const(c_domain, "XML_INACTIVE", INT2NUM(VIR_DOMAIN_XML_INACTIVE));
    rb_define_const(c_domain, "DOMAIN_XML_INACTIVE",
                    INT2NUM(VIR_DOMAIN_XML_INACTIVE));
    /* Ideally we would just have the "XML_UPDATE_CPU" constant.  Unfortunately
     * we screwed up long ago, and we have to leave "DOMAIN_XML_UPDATE_CPU" for
     * backwards compatibility.
     */
    rb_define_const(c_domain, "XML_UPDATE_CPU",
                    INT2NUM(VIR_DOMAIN_XML_UPDATE_CPU));
    rb_define_const(c_domain, "DOMAIN_XML_UPDATE_CPU",
                    INT2NUM(VIR_DOMAIN_XML_UPDATE_CPU));
    rb_define_const(c_domain, "XML_MIGRATABLE",
                    INT2NUM(VIR_DOMAIN_XML_MIGRATABLE));
    rb_define_const(c_domain, "MEMORY_VIRTUAL", INT2NUM(VIR_MEMORY_VIRTUAL));
    rb_define_const(c_domain, "MEMORY_PHYSICAL", INT2NUM(VIR_MEMORY_PHYSICAL));

    rb_define_const(c_domain, "START_PAUSED", INT2NUM(VIR_DOMAIN_START_PAUSED));

    rb_define_const(c_domain, "START_AUTODESTROY",
                    INT2NUM(VIR_DOMAIN_START_AUTODESTROY));
    rb_define_const(c_domain, "START_BYPASS_CACHE",
                    INT2NUM(VIR_DOMAIN_START_BYPASS_CACHE));
    rb_define_const(c_domain, "START_FORCE_BOOT",
                    INT2NUM(VIR_DOMAIN_START_FORCE_BOOT));

    rb_define_const(c_domain, "DUMP_CRASH", INT2NUM(VIR_DUMP_CRASH));
    rb_define_const(c_domain, "DUMP_LIVE", INT2NUM(VIR_DUMP_LIVE));
    rb_define_const(c_domain, "BYPASS_CACHE", INT2NUM(VIR_DUMP_BYPASS_CACHE));
    rb_define_const(c_domain, "RESET", INT2NUM(VIR_DUMP_RESET));
    rb_define_const(c_domain, "MEMORY_ONLY", INT2NUM(VIR_DUMP_MEMORY_ONLY));

    rb_define_const(c_domain, "VCPU_LIVE", INT2NUM(VIR_DOMAIN_VCPU_LIVE));
    rb_define_const(c_domain, "VCPU_CONFIG", INT2NUM(VIR_DOMAIN_VCPU_CONFIG));
    rb_define_const(c_domain, "VCPU_MAXIMUM", INT2NUM(VIR_DOMAIN_VCPU_MAXIMUM));
    rb_define_const(c_domain, "VCPU_CURRENT", INT2NUM(VIR_DOMAIN_VCPU_CURRENT));
    rb_define_const(c_domain, "VCPU_GUEST", INT2NUM(VIR_DOMAIN_VCPU_GUEST));

    rb_define_method(c_domain, "migrate", libvirt_domain_migrate, -1);
    rb_define_method(c_domain, "migrate_to_uri",
                     libvirt_domain_migrate_to_uri, -1);
    rb_define_method(c_domain, "migrate_set_max_downtime",
                     libvirt_domain_migrate_set_max_downtime, -1);
    rb_define_method(c_domain, "migrate_max_downtime=",
                     libvirt_domain_migrate_max_downtime_equal, 1);
    rb_define_method(c_domain, "migrate2", libvirt_domain_migrate2, -1);
    rb_define_method(c_domain, "migrate_to_uri2",
                     libvirt_domain_migrate_to_uri2, -1);
    rb_define_method(c_domain, "migrate_set_max_speed",
                     libvirt_domain_migrate_set_max_speed, -1);
    rb_define_method(c_domain, "migrate_max_speed=",
                     libvirt_domain_migrate_max_speed_equal, 1);

    rb_define_const(c_domain, "SAVE_BYPASS_CACHE",
                    INT2NUM(VIR_DOMAIN_SAVE_BYPASS_CACHE));
    rb_define_const(c_domain, "SAVE_RUNNING", INT2NUM(VIR_DOMAIN_SAVE_RUNNING));
    rb_define_const(c_domain, "SAVE_PAUSED", INT2NUM(VIR_DOMAIN_SAVE_PAUSED));

    rb_define_const(c_domain, "UNDEFINE_MANAGED_SAVE",
                    INT2NUM(VIR_DOMAIN_UNDEFINE_MANAGED_SAVE));
    rb_define_const(c_domain, "UNDEFINE_SNAPSHOTS_METADATA",
                    INT2NUM(VIR_DOMAIN_UNDEFINE_SNAPSHOTS_METADATA));
    rb_define_const(c_domain, "UNDEFINE_NVRAM",
                    INT2NUM(VIR_DOMAIN_UNDEFINE_NVRAM));
#if LIBVIR_CHECK_VERSION(2, 3, 0)
    rb_define_const(c_domain, "UNDEFINE_KEEP_NVRAM",
                    INT2NUM(VIR_DOMAIN_UNDEFINE_KEEP_NVRAM));
#endif
#if LIBVIR_CHECK_VERSION(5, 6, 0)
    rb_define_const(c_domain, "UNDEFINE_CHECKPOINTS_METADATA",
                    INT2NUM(VIR_DOMAIN_UNDEFINE_CHECKPOINTS_METADATA));
#endif
    rb_define_attr(c_domain, "connection", 1, 0);

    rb_define_const(c_domain, "SHUTDOWN_DEFAULT",
                    INT2NUM(VIR_DOMAIN_SHUTDOWN_DEFAULT));
    rb_define_const(c_domain, "SHUTDOWN_ACPI_POWER_BTN",
                    INT2NUM(VIR_DOMAIN_SHUTDOWN_ACPI_POWER_BTN));
    rb_define_const(c_domain, "SHUTDOWN_GUEST_AGENT",
                    INT2NUM(VIR_DOMAIN_SHUTDOWN_GUEST_AGENT));
    rb_define_const(c_domain, "SHUTDOWN_INITCTL",
                    INT2NUM(VIR_DOMAIN_SHUTDOWN_INITCTL));
    rb_define_const(c_domain, "SHUTDOWN_SIGNAL",
                    INT2NUM(VIR_DOMAIN_SHUTDOWN_SIGNAL));
    rb_define_const(c_domain, "SHUTDOWN_PARAVIRT",
                    INT2NUM(VIR_DOMAIN_SHUTDOWN_PARAVIRT));
    rb_define_method(c_domain, "shutdown", libvirt_domain_shutdown, -1);

    rb_define_const(c_domain, "REBOOT_DEFAULT",
                    INT2NUM(VIR_DOMAIN_REBOOT_DEFAULT));
    rb_define_const(c_domain, "REBOOT_ACPI_POWER_BTN",
                    INT2NUM(VIR_DOMAIN_REBOOT_ACPI_POWER_BTN));
    rb_define_const(c_domain, "REBOOT_GUEST_AGENT",
                    INT2NUM(VIR_DOMAIN_REBOOT_GUEST_AGENT));
    rb_define_const(c_domain, "REBOOT_INITCTL",
                    INT2NUM(VIR_DOMAIN_REBOOT_INITCTL));
    rb_define_const(c_domain, "REBOOT_SIGNAL",
                    INT2NUM(VIR_DOMAIN_REBOOT_SIGNAL));
    rb_define_const(c_domain, "REBOOT_PARAVIRT",
                    INT2NUM(VIR_DOMAIN_REBOOT_PARAVIRT));
    rb_define_method(c_domain, "reboot", libvirt_domain_reboot, -1);

    rb_define_const(c_domain, "DESTROY_DEFAULT",
                    INT2NUM(VIR_DOMAIN_DESTROY_DEFAULT));
    rb_define_const(c_domain, "DESTROY_GRACEFUL",
                    INT2NUM(VIR_DOMAIN_DESTROY_GRACEFUL));
    rb_define_method(c_domain, "destroy", libvirt_domain_destroy, -1);
    rb_define_method(c_domain, "suspend", libvirt_domain_suspend, 0);
    rb_define_method(c_domain, "resume", libvirt_domain_resume, 0);
    rb_define_method(c_domain, "save", libvirt_domain_save, -1);
    rb_define_singleton_method(c_domain, "restore", libvirt_domain_s_restore,
                               2);
    rb_define_method(c_domain, "core_dump", libvirt_domain_core_dump, -1);
    rb_define_method(c_domain, "info", libvirt_domain_info, 0);
    rb_define_method(c_domain, "ifinfo", libvirt_domain_if_stats, 1);
    rb_define_method(c_domain, "name", libvirt_domain_name, 0);
    rb_define_method(c_domain, "id", libvirt_domain_id, 0);
    rb_define_method(c_domain, "uuid", libvirt_domain_uuid, 0);
    rb_define_method(c_domain, "os_type", libvirt_domain_os_type, 0);
    rb_define_method(c_domain, "max_memory", libvirt_domain_max_memory, 0);
    rb_define_method(c_domain, "max_memory=", libvirt_domain_max_memory_equal,
                     1);
    rb_define_method(c_domain, "memory=", libvirt_domain_memory_equal, 1);
    rb_define_method(c_domain, "max_vcpus", libvirt_domain_max_vcpus, 0);
    rb_define_method(c_domain, "vcpus=", libvirt_domain_vcpus_equal, 1);
    rb_define_method(c_domain, "vcpus_flags=", libvirt_domain_vcpus_flags_equal,
                     1);
    rb_define_method(c_domain, "pin_vcpu", libvirt_domain_pin_vcpu, -1);
    rb_define_method(c_domain, "xml_desc", libvirt_domain_xml_desc, -1);
    rb_define_method(c_domain, "undefine", libvirt_domain_undefine, -1);
    rb_define_method(c_domain, "create", libvirt_domain_create, -1);
    rb_define_method(c_domain, "autostart", libvirt_domain_autostart, 0);
    rb_define_method(c_domain, "autostart?", libvirt_domain_autostart, 0);
    rb_define_method(c_domain, "autostart=", libvirt_domain_autostart_equal, 1);
    rb_define_method(c_domain, "free", libvirt_domain_free, 0);

    rb_define_const(c_domain, "DEVICE_MODIFY_CURRENT",
                    INT2NUM(VIR_DOMAIN_DEVICE_MODIFY_CURRENT));
    rb_define_const(c_domain, "DEVICE_MODIFY_LIVE",
                    INT2NUM(VIR_DOMAIN_DEVICE_MODIFY_LIVE));
    rb_define_const(c_domain, "DEVICE_MODIFY_CONFIG",
                    INT2NUM(VIR_DOMAIN_DEVICE_MODIFY_CONFIG));
    rb_define_const(c_domain, "DEVICE_MODIFY_FORCE",
                    INT2NUM(VIR_DOMAIN_DEVICE_MODIFY_FORCE));

    rb_define_method(c_domain, "attach_device", libvirt_domain_attach_device,
                     -1);
    rb_define_method(c_domain, "detach_device", libvirt_domain_detach_device,
                     -1);
    rb_define_method(c_domain, "update_device", libvirt_domain_update_device,
                     -1);

    rb_define_method(c_domain, "scheduler_type", libvirt_domain_scheduler_type,
                     0);

    rb_define_method(c_domain, "managed_save", libvirt_domain_managed_save, -1);
    rb_define_method(c_domain, "has_managed_save?",
                     libvirt_domain_has_managed_save, -1);
    rb_define_method(c_domain, "managed_save_remove",
                     libvirt_domain_managed_save_remove, -1);
    rb_define_method(c_domain, "security_label",
                     libvirt_domain_security_label, 0);
    rb_define_method(c_domain, "block_stats", libvirt_domain_block_stats, 1);
    rb_define_method(c_domain, "memory_stats", libvirt_domain_memory_stats, -1);
    rb_define_method(c_domain, "block_peek", libvirt_domain_block_peek, -1);
    rb_define_method(c_domain, "blockinfo", libvirt_domain_block_info, -1);
    rb_define_method(c_domain, "memory_peek", libvirt_domain_memory_peek, -1);
    rb_define_method(c_domain, "vcpus", libvirt_domain_vcpus, 0);
    rb_define_alias(c_domain, "get_vcpus", "vcpus");
    rb_define_method(c_domain, "active?", libvirt_domain_active_p, 0);
    rb_define_method(c_domain, "persistent?", libvirt_domain_persistent_p, 0);
    rb_define_method(c_domain, "snapshot_create_xml",
                     libvirt_domain_snapshot_create_xml, -1);
    rb_define_method(c_domain, "num_of_snapshots",
                     libvirt_domain_num_of_snapshots, -1);
    rb_define_method(c_domain, "list_snapshots",
                     libvirt_domain_list_snapshots, -1);
    rb_define_method(c_domain, "lookup_snapshot_by_name",
                     libvirt_domain_lookup_snapshot_by_name, -1);
    rb_define_method(c_domain, "has_current_snapshot?",
                     libvirt_domain_has_current_snapshot_p, -1);
    rb_define_method(c_domain, "revert_to_snapshot",
                     libvirt_domain_revert_to_snapshot, -1);
    rb_define_method(c_domain, "current_snapshot",
                     libvirt_domain_current_snapshot, -1);

    /*
     * Class Libvirt::Domain::Info
     */
    c_domain_info = rb_define_class_under(c_domain, "Info", rb_cObject);
    rb_define_attr(c_domain_info, "state", 1, 0);
    rb_define_attr(c_domain_info, "max_mem", 1, 0);
    rb_define_attr(c_domain_info, "memory", 1, 0);
    rb_define_attr(c_domain_info, "nr_virt_cpu", 1, 0);
    rb_define_attr(c_domain_info, "cpu_time", 1, 0);

    /*
     * Class Libvirt::Domain::InterfaceInfo
     */
    c_domain_ifinfo = rb_define_class_under(c_domain, "InterfaceInfo",
                                            rb_cObject);
    rb_define_attr(c_domain_ifinfo, "rx_bytes", 1, 0);
    rb_define_attr(c_domain_ifinfo, "rx_packets", 1, 0);
    rb_define_attr(c_domain_ifinfo, "rx_errs", 1, 0);
    rb_define_attr(c_domain_ifinfo, "rx_drop", 1, 0);
    rb_define_attr(c_domain_ifinfo, "tx_bytes", 1, 0);
    rb_define_attr(c_domain_ifinfo, "tx_packets", 1, 0);
    rb_define_attr(c_domain_ifinfo, "tx_errs", 1, 0);
    rb_define_attr(c_domain_ifinfo, "tx_drop", 1, 0);

    /*
     * Class Libvirt::Domain::SecurityLabel
     */
    c_domain_security_label = rb_define_class_under(c_domain, "SecurityLabel",
                                                    rb_cObject);
    rb_define_attr(c_domain_security_label, "label", 1, 0);
    rb_define_attr(c_domain_security_label, "enforcing", 1, 0);

    /*
     * Class Libvirt::Domain::BlockStats
     */
    c_domain_block_stats = rb_define_class_under(c_domain, "BlockStats",
                                                 rb_cObject);
    rb_define_attr(c_domain_block_stats, "rd_req", 1, 0);
    rb_define_attr(c_domain_block_stats, "rd_bytes", 1, 0);
    rb_define_attr(c_domain_block_stats, "wr_req", 1, 0);
    rb_define_attr(c_domain_block_stats, "wr_bytes", 1, 0);
    rb_define_attr(c_domain_block_stats, "errs", 1, 0);

    /*
     * Class Libvirt::Domain::BlockJobInfo
     */
    c_domain_block_job_info = rb_define_class_under(c_domain, "BlockJobInfo",
                                                    rb_cObject);
    rb_define_attr(c_domain_block_job_info, "type", 1, 0);
    rb_define_attr(c_domain_block_job_info, "bandwidth", 1, 0);
    rb_define_attr(c_domain_block_job_info, "cur", 1, 0);
    rb_define_attr(c_domain_block_job_info, "end", 1, 0);

    /*
     * Class Libvirt::Domain::MemoryStats
     */
    c_domain_memory_stats = rb_define_class_under(c_domain, "MemoryStats",
                                                  rb_cObject);
    rb_define_attr(c_domain_memory_stats, "tag", 1, 0);
    rb_define_attr(c_domain_memory_stats, "value", 1, 0);

    rb_define_const(c_domain_memory_stats, "SWAP_IN",
                    INT2NUM(VIR_DOMAIN_MEMORY_STAT_SWAP_IN));
    rb_define_const(c_domain_memory_stats, "SWAP_OUT",
                    INT2NUM(VIR_DOMAIN_MEMORY_STAT_SWAP_OUT));
    rb_define_const(c_domain_memory_stats, "MAJOR_FAULT",
                    INT2NUM(VIR_DOMAIN_MEMORY_STAT_MAJOR_FAULT));
    rb_define_const(c_domain_memory_stats, "MINOR_FAULT",
                    INT2NUM(VIR_DOMAIN_MEMORY_STAT_MINOR_FAULT));
    rb_define_const(c_domain_memory_stats, "UNUSED",
                    INT2NUM(VIR_DOMAIN_MEMORY_STAT_UNUSED));
    rb_define_const(c_domain_memory_stats, "AVAILABLE",
                    INT2NUM(VIR_DOMAIN_MEMORY_STAT_AVAILABLE));
    rb_define_const(c_domain_memory_stats, "ACTUAL_BALLOON",
                    INT2NUM(VIR_DOMAIN_MEMORY_STAT_ACTUAL_BALLOON));
    rb_define_const(c_domain_memory_stats, "RSS",
                    INT2NUM(VIR_DOMAIN_MEMORY_STAT_RSS));

    /*
     * Class Libvirt::Domain::BlockInfo
     */
    c_domain_block_info = rb_define_class_under(c_domain, "BlockInfo",
                                                rb_cObject);
    rb_define_attr(c_domain_block_info, "capacity", 1, 0);
    rb_define_attr(c_domain_block_info, "allocation", 1, 0);
    rb_define_attr(c_domain_block_info, "physical", 1, 0);

    /*
     * Class Libvirt::Domain::Snapshot
     */
    c_domain_snapshot = rb_define_class_under(c_domain, "Snapshot", rb_cObject);
    rb_undef_alloc_func(c_domain_snapshot);
    rb_define_singleton_method(c_domain_snapshot, "new",
                               ruby_libvirt_new_not_allowed, -1);

    rb_define_const(c_domain_snapshot, "DELETE_CHILDREN",
                    INT2NUM(VIR_DOMAIN_SNAPSHOT_DELETE_CHILDREN));
    rb_define_method(c_domain_snapshot, "xml_desc",
                     libvirt_domain_snapshot_xml_desc, -1);
    rb_define_method(c_domain_snapshot, "delete",
                     libvirt_domain_snapshot_delete, -1);
    rb_define_method(c_domain_snapshot, "free", libvirt_domain_snapshot_free,
                     0);
    rb_define_const(c_domain_snapshot, "DELETE_METADATA_ONLY",
                    INT2NUM(VIR_DOMAIN_SNAPSHOT_DELETE_METADATA_ONLY));
    rb_define_const(c_domain_snapshot, "DELETE_CHILDREN_ONLY",
                    INT2NUM(VIR_DOMAIN_SNAPSHOT_DELETE_CHILDREN_ONLY));

    rb_define_method(c_domain_snapshot, "name", libvirt_domain_snapshot_name,
                     0);

    /*
     * Class Libvirt::Domain::VCPUInfo
     */
    c_domain_vcpuinfo = rb_define_class_under(c_domain, "VCPUInfo", rb_cObject);
    rb_define_const(c_domain_vcpuinfo, "OFFLINE", VIR_VCPU_OFFLINE);
    rb_define_const(c_domain_vcpuinfo, "RUNNING", VIR_VCPU_RUNNING);
    rb_define_const(c_domain_vcpuinfo, "BLOCKED", VIR_VCPU_BLOCKED);
    rb_define_attr(c_domain_vcpuinfo, "number", 1, 0);
    rb_define_attr(c_domain_vcpuinfo, "state", 1, 0);
    rb_define_attr(c_domain_vcpuinfo, "cpu_time", 1, 0);
    rb_define_attr(c_domain_vcpuinfo, "cpu", 1, 0);
    rb_define_attr(c_domain_vcpuinfo, "cpumap", 1, 0);

    /*
     * Class Libvirt::Domain::JobInfo
     */
    c_domain_job_info = rb_define_class_under(c_domain, "JobInfo", rb_cObject);
    rb_define_const(c_domain_job_info, "NONE", INT2NUM(VIR_DOMAIN_JOB_NONE));
    rb_define_const(c_domain_job_info, "BOUNDED",
                    INT2NUM(VIR_DOMAIN_JOB_BOUNDED));
    rb_define_const(c_domain_job_info, "UNBOUNDED",
                    INT2NUM(VIR_DOMAIN_JOB_UNBOUNDED));
    rb_define_const(c_domain_job_info, "COMPLETED",
                    INT2NUM(VIR_DOMAIN_JOB_COMPLETED));
    rb_define_const(c_domain_job_info, "FAILED",
                    INT2NUM(VIR_DOMAIN_JOB_FAILED));
    rb_define_const(c_domain_job_info, "CANCELLED",
                    INT2NUM(VIR_DOMAIN_JOB_CANCELLED));
    rb_define_attr(c_domain_job_info, "type", 1, 0);
    rb_define_attr(c_domain_job_info, "time_elapsed", 1, 0);
    rb_define_attr(c_domain_job_info, "time_remaining", 1, 0);
    rb_define_attr(c_domain_job_info, "data_total", 1, 0);
    rb_define_attr(c_domain_job_info, "data_processed", 1, 0);
    rb_define_attr(c_domain_job_info, "data_remaining", 1, 0);
    rb_define_attr(c_domain_job_info, "mem_total", 1, 0);
    rb_define_attr(c_domain_job_info, "mem_processed", 1, 0);
    rb_define_attr(c_domain_job_info, "mem_remaining", 1, 0);
    rb_define_attr(c_domain_job_info, "file_total", 1, 0);
    rb_define_attr(c_domain_job_info, "file_processed", 1, 0);
    rb_define_attr(c_domain_job_info, "file_remaining", 1, 0);

    rb_define_method(c_domain, "job_info", libvirt_domain_job_info, 0);
    rb_define_method(c_domain, "abort_job", libvirt_domain_abort_job, 0);

    rb_define_method(c_domain, "qemu_monitor_command",
                     libvirt_domain_qemu_monitor_command, -1);

    rb_define_method(c_domain, "num_vcpus", libvirt_domain_num_vcpus, 1);

    rb_define_method(c_domain, "updated?", libvirt_domain_is_updated, 0);

    rb_define_const(c_domain, "MEMORY_PARAM_UNLIMITED",
                    LL2NUM(VIR_DOMAIN_MEMORY_PARAM_UNLIMITED));

    /* Ideally we would just have the "MEM_LIVE" constant.  Unfortunately
     * we screwed up long ago, and we have to leave "DOMAIN_MEM_LIVE" for
     * backwards compatibility.
     */
    rb_define_const(c_domain, "MEM_LIVE", INT2NUM(VIR_DOMAIN_MEM_LIVE));
    rb_define_const(c_domain, "DOMAIN_MEM_LIVE", INT2NUM(VIR_DOMAIN_MEM_LIVE));
    /* Ideally we would just have the "MEM_CONFIG" constant.  Unfortunately
     * we screwed up long ago, and we have to leave "DOMAIN_MEM_CONFIG" for
     * backwards compatibility.
     */
    rb_define_const(c_domain, "MEM_CONFIG", INT2NUM(VIR_DOMAIN_MEM_CONFIG));
    rb_define_const(c_domain, "DOMAIN_MEM_CONFIG",
                    INT2NUM(VIR_DOMAIN_MEM_CONFIG));

    /* Ideally we would just have the "MEM_CURRENT" constant.  Unfortunately
     * we screwed up long ago, and we have to leave "DOMAIN_MEM_CURRENT" for
     * backwards compatibility.
     */
    rb_define_const(c_domain,"MEM_CURRENT", INT2NUM(VIR_DOMAIN_MEM_CURRENT));
    rb_define_const(c_domain, "DOMAIN_MEM_CURRENT",
                    INT2NUM(VIR_DOMAIN_MEM_CURRENT));
    /* Ideally we would just have the "MEM_MAXIMUM" constant.  Unfortunately
     * we screwed up long ago, and we have to leave "DOMAIN_MEM_MAXIMUM" for
     * backwards compatibility.
     */
    rb_define_const(c_domain, "MEM_MAXIMUM", INT2NUM(VIR_DOMAIN_MEM_MAXIMUM));
    rb_define_const(c_domain, "DOMAIN_MEM_MAXIMUM",
                    INT2NUM(VIR_DOMAIN_MEM_MAXIMUM));

    rb_define_method(c_domain, "scheduler_parameters",
                     libvirt_domain_scheduler_parameters, -1);
    rb_define_method(c_domain, "scheduler_parameters=",
                     libvirt_domain_scheduler_parameters_equal, 1);

    rb_define_method(c_domain, "memory_parameters",
                     libvirt_domain_memory_parameters, -1);
    rb_define_method(c_domain, "memory_parameters=",
                     libvirt_domain_memory_parameters_equal, 1);

    rb_define_method(c_domain, "blkio_parameters",
                     libvirt_domain_blkio_parameters, -1);
    rb_define_method(c_domain, "blkio_parameters=",
                     libvirt_domain_blkio_parameters_equal, 1);

    /* Ideally we would just have the "RUNNING_UNKNOWN" constant.  Unfortunately
     * we screwed up long ago, and we have to leave "DOMAIN_RUNNING_UNKNOWN"
     * for backwards compatibility.
     */
    rb_define_const(c_domain, "RUNNING_UNKNOWN",
                    INT2NUM(VIR_DOMAIN_RUNNING_UNKNOWN));
    rb_define_const(c_domain, "DOMAIN_RUNNING_UNKNOWN",
                    INT2NUM(VIR_DOMAIN_RUNNING_UNKNOWN));
    /* Ideally we would just have the "RUNNING_BOOTED" constant.  Unfortunately
     * we screwed up long ago, and we have to leave "DOMAIN_RUNNING_BOOTED"
     * for backwards compatibility.
     */
    rb_define_const(c_domain, "RUNNING_BOOTED",
                    INT2NUM(VIR_DOMAIN_RUNNING_BOOTED));
    rb_define_const(c_domain, "DOMAIN_RUNNING_BOOTED",
                    INT2NUM(VIR_DOMAIN_RUNNING_BOOTED));
    /* Ideally we would just have the "RUNNING_MIGRATED" constant.
     * Unfortunately we screwed up long ago, and we have to leave
     * "DOMAIN_RUNNING_MIGRATED" for backwards compatibility.
     */
    rb_define_const(c_domain, "RUNNING_MIGRATED",
                    INT2NUM(VIR_DOMAIN_RUNNING_MIGRATED));
    rb_define_const(c_domain, "DOMAIN_RUNNING_MIGRATED",
                    INT2NUM(VIR_DOMAIN_RUNNING_MIGRATED));
    /* Ideally we would just have the "RUNNING_RESTORED" constant.
     * Unfortunately we screwed up long ago, and we have to leave
     * "DOMAIN_RUNNING_RESTORED" for backwards compatibility.
     */
    rb_define_const(c_domain, "RUNNING_RESTORED",
                    INT2NUM(VIR_DOMAIN_RUNNING_RESTORED));
    rb_define_const(c_domain, "DOMAIN_RUNNING_RESTORED",
                    INT2NUM(VIR_DOMAIN_RUNNING_RESTORED));
    /* Ideally we would just have the "RUNNING_FROM_SNAPSHOT" constant.
     * Unfortunately we screwed up long ago, and we have to leave
     * "DOMAIN_RUNNING_FROM_SNAPSHOT" for backwards compatibility.
     */
    rb_define_const(c_domain, "RUNNING_FROM_SNAPSHOT",
                    INT2NUM(VIR_DOMAIN_RUNNING_FROM_SNAPSHOT));
    rb_define_const(c_domain, "DOMAIN_RUNNING_FROM_SNAPSHOT",
                    INT2NUM(VIR_DOMAIN_RUNNING_FROM_SNAPSHOT));
    /* Ideally we would just have the "RUNNING_UNPAUSED" constant.
     * Unfortunately we screwed up long ago, and we have to leave
     * "DOMAIN_RUNNING_UNPAUSED" for backwards compatibility.
     */
    rb_define_const(c_domain, "RUNNING_UNPAUSED",
                    INT2NUM(VIR_DOMAIN_RUNNING_UNPAUSED));
    rb_define_const(c_domain, "DOMAIN_RUNNING_UNPAUSED",
                    INT2NUM(VIR_DOMAIN_RUNNING_UNPAUSED));
    /* Ideally we would just have the "RUNNING_MIGRATION_CANCELED" constant.
     * Unfortunately we screwed up long ago, and we have to leave
     * "DOMAIN_RUNNING_MIGRATION_CANCELED" for backwards compatibility.
     */
    rb_define_const(c_domain, "RUNNING_MIGRATION_CANCELED",
                    INT2NUM(VIR_DOMAIN_RUNNING_MIGRATION_CANCELED));
    rb_define_const(c_domain, "DOMAIN_RUNNING_MIGRATION_CANCELED",
                    INT2NUM(VIR_DOMAIN_RUNNING_MIGRATION_CANCELED));
    /* Ideally we would just have the "RUNNING_SAVE_CANCELED" constant.
     * Unfortunately we screwed up long ago, and we have to leave
     * "DOMAIN_RUNNING_SAVE_CANCELED" for backwards compatibility.
     */
    rb_define_const(c_domain, "RUNNING_SAVE_CANCELED",
                    INT2NUM(VIR_DOMAIN_RUNNING_SAVE_CANCELED));
    rb_define_const(c_domain, "DOMAIN_RUNNING_SAVE_CANCELED",
                    INT2NUM(VIR_DOMAIN_RUNNING_SAVE_CANCELED));
    /* Ideally we would just have the "RUNNING_WAKEUP" constant.  Unfortunately
     * we screwed up long ago, and we have to leave "DOMAIN_RUNNING_WAKEUP"
     * for backwards compatibility.
     */
    rb_define_const(c_domain, "RUNNING_WAKEUP",
                    INT2NUM(VIR_DOMAIN_RUNNING_WAKEUP));
    rb_define_const(c_domain, "DOMAIN_RUNNING_WAKEUP",
                    INT2NUM(VIR_DOMAIN_RUNNING_WAKEUP));
    /* Ideally we would just have the "BLOCKED_UNKNOWN" constant.  Unfortunately
     * we screwed up long ago, and we have to leave "DOMAIN_BLOCKED_UNKNOWN"
     * for backwards compatibility.
     */
    rb_define_const(c_domain, "BLOCKED_UNKNOWN",
                    INT2NUM(VIR_DOMAIN_BLOCKED_UNKNOWN));
    rb_define_const(c_domain, "DOMAIN_BLOCKED_UNKNOWN",
                    INT2NUM(VIR_DOMAIN_BLOCKED_UNKNOWN));
    /* Ideally we would just have the "PAUSED_UNKNOWN" constant.  Unfortunately
     * we screwed up long ago, and we have to leave "DOMAIN_PAUSED_UNKNOWN"
     * for backwards compatibility.
     */
    rb_define_const(c_domain, "PAUSED_UNKNOWN",
                    INT2NUM(VIR_DOMAIN_PAUSED_UNKNOWN));
    rb_define_const(c_domain, "DOMAIN_PAUSED_UNKNOWN",
                    INT2NUM(VIR_DOMAIN_PAUSED_UNKNOWN));
    /* Ideally we would just have the "PAUSED_USER" constant.  Unfortunately
     * we screwed up long ago, and we have to leave "DOMAIN_PAUSED_USER"
     * for backwards compatibility.
     */
    rb_define_const(c_domain, "PAUSED_USER",
                    INT2NUM(VIR_DOMAIN_PAUSED_USER));
    rb_define_const(c_domain, "DOMAIN_PAUSED_USER",
                    INT2NUM(VIR_DOMAIN_PAUSED_USER));
    /* Ideally we would just have the "PAUSED_MIGRATION" constant.
     * Unfortunately we screwed up long ago, and we have to leave
     * "DOMAIN_PAUSED_MIGRATION" for backwards compatibility.
     */
    rb_define_const(c_domain, "PAUSED_MIGRATION",
                    INT2NUM(VIR_DOMAIN_PAUSED_MIGRATION));
    rb_define_const(c_domain, "DOMAIN_PAUSED_MIGRATION",
                    INT2NUM(VIR_DOMAIN_PAUSED_MIGRATION));
    /* Ideally we would just have the "PAUSED_SAVE" constant.  Unfortunately
     * we screwed up long ago, and we have to leave "DOMAIN_PAUSED_SAVE"
     * for backwards compatibility.
     */
    rb_define_const(c_domain, "PAUSED_SAVE",
                    INT2NUM(VIR_DOMAIN_PAUSED_SAVE));
    rb_define_const(c_domain, "DOMAIN_PAUSED_SAVE",
                    INT2NUM(VIR_DOMAIN_PAUSED_SAVE));
    /* Ideally we would just have the "PAUSED_DUMP" constant.  Unfortunately
     * we screwed up long ago, and we have to leave "DOMAIN_PAUSED_DUMP"
     * for backwards compatibility.
     */
    rb_define_const(c_domain, "PAUSED_DUMP",
                    INT2NUM(VIR_DOMAIN_PAUSED_DUMP));
    rb_define_const(c_domain, "DOMAIN_PAUSED_DUMP",
                    INT2NUM(VIR_DOMAIN_PAUSED_DUMP));
    /* Ideally we would just have the "PAUSED_IOERROR" constant.  Unfortunately
     * we screwed up long ago, and we have to leave "DOMAIN_PAUSED_IOERROR"
     * for backwards compatibility.
     */
    rb_define_const(c_domain, "PAUSED_IOERROR",
                    INT2NUM(VIR_DOMAIN_PAUSED_IOERROR));
    rb_define_const(c_domain, "DOMAIN_PAUSED_IOERROR",
                    INT2NUM(VIR_DOMAIN_PAUSED_IOERROR));
    /* Ideally we would just have the "PAUSED_WATCHDOG" constant.  Unfortunately
     * we screwed up long ago, and we have to leave "DOMAIN_PAUSED_WATCHDOG"
     * for backwards compatibility.
     */
    rb_define_const(c_domain, "PAUSED_WATCHDOG",
                    INT2NUM(VIR_DOMAIN_PAUSED_WATCHDOG));
    rb_define_const(c_domain, "DOMAIN_PAUSED_WATCHDOG",
                    INT2NUM(VIR_DOMAIN_PAUSED_WATCHDOG));
    /* Ideally we would just have the "PAUSED_FROM_SNAPSHOT" constant.
     * Unfortunately we screwed up long ago, and we have to leave
     * "DOMAIN_PAUSED_FROM_SNAPSHOT" for backwards compatibility.
     */
    rb_define_const(c_domain, "PAUSED_FROM_SNAPSHOT",
                    INT2NUM(VIR_DOMAIN_PAUSED_FROM_SNAPSHOT));
    rb_define_const(c_domain, "DOMAIN_PAUSED_FROM_SNAPSHOT",
                    INT2NUM(VIR_DOMAIN_PAUSED_FROM_SNAPSHOT));
    /* Ideally we would just have the "PAUSED_SHUTTING_DOWN" constant.
     * Unfortunately we screwed up long ago, and we have to leave
     * "DOMAIN_PAUSED_SHUTTING_DOWN" for backwards compatibility.
     */
    rb_define_const(c_domain, "PAUSED_SHUTTING_DOWN",
                    INT2NUM(VIR_DOMAIN_PAUSED_SHUTTING_DOWN));
    rb_define_const(c_domain, "DOMAIN_PAUSED_SHUTTING_DOWN",
                    INT2NUM(VIR_DOMAIN_PAUSED_SHUTTING_DOWN));
    /* Ideally we would just have the "PAUSED_SNAPSHOT" constant.  Unfortunately
     * we screwed up long ago, and we have to leave "DOMAIN_PAUSED_SNAPSHOT"
     * for backwards compatibility.
     */
    rb_define_const(c_domain, "PAUSED_SNAPSHOT",
                    INT2NUM(VIR_DOMAIN_PAUSED_SNAPSHOT));
    rb_define_const(c_domain, "DOMAIN_PAUSED_SNAPSHOT",
                    INT2NUM(VIR_DOMAIN_PAUSED_SNAPSHOT));
    /* Ideally we would just have the "SHUTDOWN_UNKNOWN" constant.
     * Unfortunately we screwed up long ago, and we have to leave
     * "DOMAIN_SHUTDOWN_UNKNOWN" for backwards compatibility.
     */
    rb_define_const(c_domain, "SHUTDOWN_UNKNOWN",
                    INT2NUM(VIR_DOMAIN_SHUTDOWN_UNKNOWN));
    rb_define_const(c_domain, "DOMAIN_SHUTDOWN_UNKNOWN",
                    INT2NUM(VIR_DOMAIN_SHUTDOWN_UNKNOWN));
    /* Ideally we would just have the "SHUTDOWN_USER" constant.  Unfortunately
     * we screwed up long ago, and we have to leave "DOMAIN_SHUTDOWN_USER"
     * for backwards compatibility.
     */
    rb_define_const(c_domain, "SHUTDOWN_USER",
                    INT2NUM(VIR_DOMAIN_SHUTDOWN_USER));
    rb_define_const(c_domain, "DOMAIN_SHUTDOWN_USER",
                    INT2NUM(VIR_DOMAIN_SHUTDOWN_USER));
    /* Ideally we would just have the "SHUTOFF_UNKNOWN" constant.  Unfortunately
     * we screwed up long ago, and we have to leave "DOMAIN_SHUTOFF_UNKNOWN"
     * for backwards compatibility.
     */
    rb_define_const(c_domain, "SHUTOFF_UNKNOWN",
                    INT2NUM(VIR_DOMAIN_SHUTOFF_UNKNOWN));
    rb_define_const(c_domain, "DOMAIN_SHUTOFF_UNKNOWN",
                    INT2NUM(VIR_DOMAIN_SHUTOFF_UNKNOWN));
    /* Ideally we would just have the "SHUTOFF_SHUTDOWN" constant.
     * Unfortunately we screwed up long ago, and we have to leave
     * "DOMAIN_SHUTOFF_SHUTDOWN" for backwards compatibility.
     */
    rb_define_const(c_domain, "SHUTOFF_SHUTDOWN",
                    INT2NUM(VIR_DOMAIN_SHUTOFF_SHUTDOWN));
    rb_define_const(c_domain, "DOMAIN_SHUTOFF_SHUTDOWN",
                    INT2NUM(VIR_DOMAIN_SHUTOFF_SHUTDOWN));
    /* Ideally we would just have the "SHUTOFF_DESTROYED" constant.
     * Unfortunately we screwed up long ago, and we have to leave
     * "DOMAIN_SHUTOFF_DESTROYED" for backwards compatibility.
     */
    rb_define_const(c_domain, "SHUTOFF_DESTROYED",
                    INT2NUM(VIR_DOMAIN_SHUTOFF_DESTROYED));
    rb_define_const(c_domain, "DOMAIN_SHUTOFF_DESTROYED",
                    INT2NUM(VIR_DOMAIN_SHUTOFF_DESTROYED));
    /* Ideally we would just have the "SHUTOFF_CRASHED" constant.  Unfortunately
     * we screwed up long ago, and we have to leave "DOMAIN_SHUTOFF_CRASHED"
     * for backwards compatibility.
     */
    rb_define_const(c_domain, "SHUTOFF_CRASHED",
                    INT2NUM(VIR_DOMAIN_SHUTOFF_CRASHED));
    rb_define_const(c_domain, "DOMAIN_SHUTOFF_CRASHED",
                    INT2NUM(VIR_DOMAIN_SHUTOFF_CRASHED));
    /* Ideally we would just have the "SHUTOFF_MIGRATED" constant.
     * Unfortunately we screwed up long ago, and we have to leave
     * "DOMAIN_SHUTOFF_MIGRATED" for backwards compatibility.
     */
    rb_define_const(c_domain, "SHUTOFF_MIGRATED",
                    INT2NUM(VIR_DOMAIN_SHUTOFF_MIGRATED));
    rb_define_const(c_domain, "DOMAIN_SHUTOFF_MIGRATED",
                    INT2NUM(VIR_DOMAIN_SHUTOFF_MIGRATED));
    /* Ideally we would just have the "SHUTOFF_SAVED" constant.  Unfortunately
     * we screwed up long ago, and we have to leave "DOMAIN_SHUTOFF_SAVED"
     * for backwards compatibility.
     */
    rb_define_const(c_domain, "SHUTOFF_SAVED",
                    INT2NUM(VIR_DOMAIN_SHUTOFF_SAVED));
    rb_define_const(c_domain, "DOMAIN_SHUTOFF_SAVED",
                    INT2NUM(VIR_DOMAIN_SHUTOFF_SAVED));
    /* Ideally we would just have the "SHUTOFF_FAILED" constant.  Unfortunately
     * we screwed up long ago, and we have to leave "DOMAIN_SHUTOFF_FAILED"
     * for backwards compatibility.
     */
    rb_define_const(c_domain, "SHUTOFF_FAILED",
                    INT2NUM(VIR_DOMAIN_SHUTOFF_FAILED));
    rb_define_const(c_domain, "DOMAIN_SHUTOFF_FAILED",
                    INT2NUM(VIR_DOMAIN_SHUTOFF_FAILED));
    /* Ideally we would just have the "SHUTOFF_FROM_SNAPSHOT" constant.
     * Unfortunately we screwed up long ago, and we have to leave
     * "DOMAIN_SHUTOFF_FROM_SNAPSHOT" for backwards compatibility.
     */
    rb_define_const(c_domain, "SHUTOFF_FROM_SNAPSHOT",
                    INT2NUM(VIR_DOMAIN_SHUTOFF_FROM_SNAPSHOT));
    rb_define_const(c_domain, "DOMAIN_SHUTOFF_FROM_SNAPSHOT",
                    INT2NUM(VIR_DOMAIN_SHUTOFF_FROM_SNAPSHOT));
    /* Ideally we would just have the "CRASHED_UNKNOWN" constant.  Unfortunately
     * we screwed up long ago, and we have to leave "DOMAIN_CRASHED_UNKNOWN"
     * for backwards compatibility.
     */
    rb_define_const(c_domain, "CRASHED_UNKNOWN",
                    INT2NUM(VIR_DOMAIN_CRASHED_UNKNOWN));
    rb_define_const(c_domain, "DOMAIN_CRASHED_UNKNOWN",
                    INT2NUM(VIR_DOMAIN_CRASHED_UNKNOWN));
    /* Ideally we would just have the "PMSUSPENDED_UNKNOWN" constant.
     * Unfortunately we screwed up long ago, and we have to leave
     * "DOMAIN_PMSUSPENDED_UNKNOWN" for backwards compatibility.
     */
    rb_define_const(c_domain, "PMSUSPENDED_UNKNOWN",
                    INT2NUM(VIR_DOMAIN_PMSUSPENDED_UNKNOWN));
    rb_define_const(c_domain, "DOMAIN_PMSUSPENDED_UNKNOWN",
                    INT2NUM(VIR_DOMAIN_PMSUSPENDED_UNKNOWN));
    /* Ideally we would just have the "PMSUSPENDED_DISK_UNKNOWN" constant.
     * Unfortunately we screwed up long ago, and we have to leave
     * "DOMAIN_PMSUSPENDED_DISK_UNKNOWN" for backwards compatibility.
     */
    rb_define_const(c_domain, "PMSUSPENDED_DISK_UNKNOWN",
                    INT2NUM(VIR_DOMAIN_PMSUSPENDED_DISK_UNKNOWN));
    rb_define_const(c_domain, "DOMAIN_PMSUSPENDED_DISK_UNKNOWN",
                    INT2NUM(VIR_DOMAIN_PMSUSPENDED_DISK_UNKNOWN));
    rb_define_const(c_domain, "RUNNING_CRASHED",
                    INT2NUM(VIR_DOMAIN_RUNNING_CRASHED));
    rb_define_const(c_domain, "NOSTATE_UNKNOWN",
                    INT2NUM(VIR_DOMAIN_NOSTATE_UNKNOWN));
    rb_define_const(c_domain, "PAUSED_CRASHED",
                    INT2NUM(VIR_DOMAIN_PAUSED_CRASHED));
    rb_define_const(c_domain, "CRASHED_PANICKED",
                    INT2NUM(VIR_DOMAIN_CRASHED_PANICKED));

    rb_define_method(c_domain, "state", libvirt_domain_state, -1);

    /* Ideally we would just have the "AFFECT_CURRENT" constant.  Unfortunately
     * we screwed up long ago, and we have to leave "DOMAIN_AFFECT_CURRENT" for
     * backwards compatibility.
     */
    rb_define_const(c_domain, "AFFECT_CURRENT",
                    INT2NUM(VIR_DOMAIN_AFFECT_CURRENT));
    rb_define_const(c_domain, "DOMAIN_AFFECT_CURRENT",
                    INT2NUM(VIR_DOMAIN_AFFECT_CURRENT));
    /* Ideally we would just have the "AFFECT_LIVE" constant.  Unfortunately
     * we screwed up long ago, and we have to leave "DOMAIN_AFFECT_LIVE" for
     * backwards compatibility.
     */
    rb_define_const(c_domain, "AFFECT_LIVE",
                    INT2NUM(VIR_DOMAIN_AFFECT_LIVE));
    rb_define_const(c_domain, "DOMAIN_AFFECT_LIVE",
                    INT2NUM(VIR_DOMAIN_AFFECT_LIVE));
    /* Ideally we would just have the "AFFECT_CONFIG" constant.  Unfortunately
     * we screwed up long ago, and we have to leave "DOMAIN_AFFECT_CONFIG" for
     * backwards compatibility.
     */
    rb_define_const(c_domain, "AFFECT_CONFIG",
                    INT2NUM(VIR_DOMAIN_AFFECT_CONFIG));
    rb_define_const(c_domain, "DOMAIN_AFFECT_CONFIG",
                    INT2NUM(VIR_DOMAIN_AFFECT_CONFIG));

    rb_define_const(c_domain, "CONSOLE_FORCE",
                    INT2NUM(VIR_DOMAIN_CONSOLE_FORCE));
    rb_define_const(c_domain, "CONSOLE_SAFE", INT2NUM(VIR_DOMAIN_CONSOLE_SAFE));

    rb_define_method(c_domain, "open_console", libvirt_domain_open_console, -1);

    rb_define_method(c_domain, "screenshot", libvirt_domain_screenshot, -1);

    rb_define_method(c_domain, "inject_nmi", libvirt_domain_inject_nmi, -1);

    /*
     * Class Libvirt::Domain::ControlInfo
     */
    c_domain_control_info = rb_define_class_under(c_domain, "ControlInfo",
                                                  rb_cObject);
    rb_define_attr(c_domain_control_info, "state", 1, 0);
    rb_define_attr(c_domain_control_info, "details", 1, 0);
    rb_define_attr(c_domain_control_info, "stateTime", 1, 0);

    rb_define_const(c_domain_control_info, "CONTROL_OK",
                    INT2NUM(VIR_DOMAIN_CONTROL_OK));
    rb_define_const(c_domain_control_info, "CONTROL_JOB",
                    INT2NUM(VIR_DOMAIN_CONTROL_JOB));
    rb_define_const(c_domain_control_info, "CONTROL_OCCUPIED",
                    INT2NUM(VIR_DOMAIN_CONTROL_OCCUPIED));
    rb_define_const(c_domain_control_info, "CONTROL_ERROR",
                    INT2NUM(VIR_DOMAIN_CONTROL_ERROR));

    rb_define_method(c_domain, "control_info", libvirt_domain_control_info, -1);

    rb_define_method(c_domain, "migrate_max_speed",
                     libvirt_domain_migrate_max_speed, -1);
    rb_define_method(c_domain, "send_key", libvirt_domain_send_key, 3);
    rb_define_method(c_domain, "reset", libvirt_domain_reset, -1);
    rb_define_method(c_domain, "hostname", libvirt_domain_hostname, -1);
    rb_define_const(c_domain, "METADATA_DESCRIPTION",
                    INT2NUM(VIR_DOMAIN_METADATA_DESCRIPTION));
    rb_define_const(c_domain, "METADATA_TITLE",
                    INT2NUM(VIR_DOMAIN_METADATA_TITLE));
    rb_define_const(c_domain, "METADATA_ELEMENT",
                    INT2NUM(VIR_DOMAIN_METADATA_ELEMENT));
    rb_define_method(c_domain, "metadata", libvirt_domain_metadata, -1);
    rb_define_method(c_domain, "metadata=", libvirt_domain_metadata_equal, 1);
    rb_define_const(c_domain, "PROCESS_SIGNAL_NOP",
                    INT2NUM(VIR_DOMAIN_PROCESS_SIGNAL_NOP));
    rb_define_const(c_domain, "PROCESS_SIGNAL_HUP",
                    INT2NUM(VIR_DOMAIN_PROCESS_SIGNAL_HUP));
    rb_define_const(c_domain, "PROCESS_SIGNAL_INT",
                    INT2NUM(VIR_DOMAIN_PROCESS_SIGNAL_INT));
    rb_define_const(c_domain, "PROCESS_SIGNAL_QUIT",
                    INT2NUM(VIR_DOMAIN_PROCESS_SIGNAL_QUIT));
    rb_define_const(c_domain, "PROCESS_SIGNAL_ILL",
                    INT2NUM(VIR_DOMAIN_PROCESS_SIGNAL_ILL));
    rb_define_const(c_domain, "PROCESS_SIGNAL_TRAP",
                    INT2NUM(VIR_DOMAIN_PROCESS_SIGNAL_TRAP));
    rb_define_const(c_domain, "PROCESS_SIGNAL_ABRT",
                    INT2NUM(VIR_DOMAIN_PROCESS_SIGNAL_ABRT));
    rb_define_const(c_domain, "PROCESS_SIGNAL_BUS",
                    INT2NUM(VIR_DOMAIN_PROCESS_SIGNAL_BUS));
    rb_define_const(c_domain, "PROCESS_SIGNAL_FPE",
                    INT2NUM(VIR_DOMAIN_PROCESS_SIGNAL_FPE));
    rb_define_const(c_domain, "PROCESS_SIGNAL_KILL",
                    INT2NUM(VIR_DOMAIN_PROCESS_SIGNAL_KILL));
    rb_define_const(c_domain, "PROCESS_SIGNAL_USR1",
                    INT2NUM(VIR_DOMAIN_PROCESS_SIGNAL_USR1));
    rb_define_const(c_domain, "PROCESS_SIGNAL_SEGV",
                    INT2NUM(VIR_DOMAIN_PROCESS_SIGNAL_SEGV));
    rb_define_const(c_domain, "PROCESS_SIGNAL_USR2",
                    INT2NUM(VIR_DOMAIN_PROCESS_SIGNAL_USR2));
    rb_define_const(c_domain, "PROCESS_SIGNAL_PIPE",
                    INT2NUM(VIR_DOMAIN_PROCESS_SIGNAL_PIPE));
    rb_define_const(c_domain, "PROCESS_SIGNAL_ALRM",
                    INT2NUM(VIR_DOMAIN_PROCESS_SIGNAL_ALRM));
    rb_define_const(c_domain, "PROCESS_SIGNAL_TERM",
                    INT2NUM(VIR_DOMAIN_PROCESS_SIGNAL_TERM));
    rb_define_const(c_domain, "PROCESS_SIGNAL_STKFLT",
                    INT2NUM(VIR_DOMAIN_PROCESS_SIGNAL_STKFLT));
    rb_define_const(c_domain, "PROCESS_SIGNAL_CHLD",
                    INT2NUM(VIR_DOMAIN_PROCESS_SIGNAL_CHLD));
    rb_define_const(c_domain, "PROCESS_SIGNAL_CONT",
                    INT2NUM(VIR_DOMAIN_PROCESS_SIGNAL_CONT));
    rb_define_const(c_domain, "PROCESS_SIGNAL_STOP",
                    INT2NUM(VIR_DOMAIN_PROCESS_SIGNAL_STOP));
    rb_define_const(c_domain, "PROCESS_SIGNAL_TSTP",
                    INT2NUM(VIR_DOMAIN_PROCESS_SIGNAL_TSTP));
    rb_define_const(c_domain, "PROCESS_SIGNAL_TTIN",
                    INT2NUM(VIR_DOMAIN_PROCESS_SIGNAL_TTIN));
    rb_define_const(c_domain, "PROCESS_SIGNAL_TTOU",
                    INT2NUM(VIR_DOMAIN_PROCESS_SIGNAL_TTOU));
    rb_define_const(c_domain, "PROCESS_SIGNAL_URG",
                    INT2NUM(VIR_DOMAIN_PROCESS_SIGNAL_URG));
    rb_define_const(c_domain, "PROCESS_SIGNAL_XCPU",
                    INT2NUM(VIR_DOMAIN_PROCESS_SIGNAL_XCPU));
    rb_define_const(c_domain, "PROCESS_SIGNAL_XFSZ",
                    INT2NUM(VIR_DOMAIN_PROCESS_SIGNAL_XFSZ));
    rb_define_const(c_domain, "PROCESS_SIGNAL_VTALRM",
                    INT2NUM(VIR_DOMAIN_PROCESS_SIGNAL_VTALRM));
    rb_define_const(c_domain, "PROCESS_SIGNAL_PROF",
                    INT2NUM(VIR_DOMAIN_PROCESS_SIGNAL_PROF));
    rb_define_const(c_domain, "PROCESS_SIGNAL_WINCH",
                    INT2NUM(VIR_DOMAIN_PROCESS_SIGNAL_WINCH));
    rb_define_const(c_domain, "PROCESS_SIGNAL_POLL",
                    INT2NUM(VIR_DOMAIN_PROCESS_SIGNAL_POLL));
    rb_define_const(c_domain, "PROCESS_SIGNAL_PWR",
                    INT2NUM(VIR_DOMAIN_PROCESS_SIGNAL_PWR));
    rb_define_const(c_domain, "PROCESS_SIGNAL_SYS",
                    INT2NUM(VIR_DOMAIN_PROCESS_SIGNAL_SYS));
    rb_define_const(c_domain, "PROCESS_SIGNAL_RT0",
                    INT2NUM(VIR_DOMAIN_PROCESS_SIGNAL_RT0));
    rb_define_const(c_domain, "PROCESS_SIGNAL_RT1",
                    INT2NUM(VIR_DOMAIN_PROCESS_SIGNAL_RT1));
    rb_define_const(c_domain, "PROCESS_SIGNAL_RT2",
                    INT2NUM(VIR_DOMAIN_PROCESS_SIGNAL_RT2));
    rb_define_const(c_domain, "PROCESS_SIGNAL_RT3",
                    INT2NUM(VIR_DOMAIN_PROCESS_SIGNAL_RT3));
    rb_define_const(c_domain, "PROCESS_SIGNAL_RT4",
                    INT2NUM(VIR_DOMAIN_PROCESS_SIGNAL_RT4));
    rb_define_const(c_domain, "PROCESS_SIGNAL_RT5",
                    INT2NUM(VIR_DOMAIN_PROCESS_SIGNAL_RT5));
    rb_define_const(c_domain, "PROCESS_SIGNAL_RT6",
                    INT2NUM(VIR_DOMAIN_PROCESS_SIGNAL_RT6));
    rb_define_const(c_domain, "PROCESS_SIGNAL_RT7",
                    INT2NUM(VIR_DOMAIN_PROCESS_SIGNAL_RT7));
    rb_define_const(c_domain, "PROCESS_SIGNAL_RT8",
                    INT2NUM(VIR_DOMAIN_PROCESS_SIGNAL_RT8));
    rb_define_const(c_domain, "PROCESS_SIGNAL_RT9",
                    INT2NUM(VIR_DOMAIN_PROCESS_SIGNAL_RT9));
    rb_define_const(c_domain, "PROCESS_SIGNAL_RT10",
                    INT2NUM(VIR_DOMAIN_PROCESS_SIGNAL_RT10));
    rb_define_const(c_domain, "PROCESS_SIGNAL_RT11",
                    INT2NUM(VIR_DOMAIN_PROCESS_SIGNAL_RT11));
    rb_define_const(c_domain, "PROCESS_SIGNAL_RT12",
                    INT2NUM(VIR_DOMAIN_PROCESS_SIGNAL_RT12));
    rb_define_const(c_domain, "PROCESS_SIGNAL_RT13",
                    INT2NUM(VIR_DOMAIN_PROCESS_SIGNAL_RT13));
    rb_define_const(c_domain, "PROCESS_SIGNAL_RT14",
                    INT2NUM(VIR_DOMAIN_PROCESS_SIGNAL_RT14));
    rb_define_const(c_domain, "PROCESS_SIGNAL_RT15",
                    INT2NUM(VIR_DOMAIN_PROCESS_SIGNAL_RT15));
    rb_define_const(c_domain, "PROCESS_SIGNAL_RT16",
                    INT2NUM(VIR_DOMAIN_PROCESS_SIGNAL_RT16));
    rb_define_const(c_domain, "PROCESS_SIGNAL_RT17",
                    INT2NUM(VIR_DOMAIN_PROCESS_SIGNAL_RT17));
    rb_define_const(c_domain, "PROCESS_SIGNAL_RT18",
                    INT2NUM(VIR_DOMAIN_PROCESS_SIGNAL_RT18));
    rb_define_const(c_domain, "PROCESS_SIGNAL_RT19",
                    INT2NUM(VIR_DOMAIN_PROCESS_SIGNAL_RT19));
    rb_define_const(c_domain, "PROCESS_SIGNAL_RT20",
                    INT2NUM(VIR_DOMAIN_PROCESS_SIGNAL_RT20));
    rb_define_const(c_domain, "PROCESS_SIGNAL_RT21",
                    INT2NUM(VIR_DOMAIN_PROCESS_SIGNAL_RT21));
    rb_define_const(c_domain, "PROCESS_SIGNAL_RT22",
                    INT2NUM(VIR_DOMAIN_PROCESS_SIGNAL_RT22));
    rb_define_const(c_domain, "PROCESS_SIGNAL_RT23",
                    INT2NUM(VIR_DOMAIN_PROCESS_SIGNAL_RT23));
    rb_define_const(c_domain, "PROCESS_SIGNAL_RT24",
                    INT2NUM(VIR_DOMAIN_PROCESS_SIGNAL_RT24));
    rb_define_const(c_domain, "PROCESS_SIGNAL_RT25",
                    INT2NUM(VIR_DOMAIN_PROCESS_SIGNAL_RT25));
    rb_define_const(c_domain, "PROCESS_SIGNAL_RT26",
                    INT2NUM(VIR_DOMAIN_PROCESS_SIGNAL_RT26));
    rb_define_const(c_domain, "PROCESS_SIGNAL_RT27",
                    INT2NUM(VIR_DOMAIN_PROCESS_SIGNAL_RT27));
    rb_define_const(c_domain, "PROCESS_SIGNAL_RT28",
                    INT2NUM(VIR_DOMAIN_PROCESS_SIGNAL_RT28));
    rb_define_const(c_domain, "PROCESS_SIGNAL_RT29",
                    INT2NUM(VIR_DOMAIN_PROCESS_SIGNAL_RT29));
    rb_define_const(c_domain, "PROCESS_SIGNAL_RT30",
                    INT2NUM(VIR_DOMAIN_PROCESS_SIGNAL_RT30));
    rb_define_const(c_domain, "PROCESS_SIGNAL_RT31",
                    INT2NUM(VIR_DOMAIN_PROCESS_SIGNAL_RT31));
    rb_define_const(c_domain, "PROCESS_SIGNAL_RT32",
                    INT2NUM(VIR_DOMAIN_PROCESS_SIGNAL_RT32));
    rb_define_method(c_domain, "send_process_signal",
                     libvirt_domain_send_process_signal, -1);
    rb_define_const(c_domain_snapshot, "LIST_ROOTS",
                    INT2NUM(VIR_DOMAIN_SNAPSHOT_LIST_ROOTS));
    rb_define_const(c_domain_snapshot, "LIST_DESCENDANTS",
                    INT2NUM(VIR_DOMAIN_SNAPSHOT_LIST_DESCENDANTS));
    rb_define_const(c_domain_snapshot, "LIST_LEAVES",
                    INT2NUM(VIR_DOMAIN_SNAPSHOT_LIST_LEAVES));
    rb_define_const(c_domain_snapshot, "LIST_NO_LEAVES",
                    INT2NUM(VIR_DOMAIN_SNAPSHOT_LIST_NO_LEAVES));
    rb_define_const(c_domain_snapshot, "LIST_METADATA",
                    INT2NUM(VIR_DOMAIN_SNAPSHOT_LIST_METADATA));
    rb_define_const(c_domain_snapshot, "LIST_NO_METADATA",
                    INT2NUM(VIR_DOMAIN_SNAPSHOT_LIST_NO_METADATA));
    rb_define_const(c_domain_snapshot, "LIST_INACTIVE",
                    INT2NUM(VIR_DOMAIN_SNAPSHOT_LIST_INACTIVE));
    rb_define_const(c_domain_snapshot, "LIST_ACTIVE",
                    INT2NUM(VIR_DOMAIN_SNAPSHOT_LIST_ACTIVE));
    rb_define_const(c_domain_snapshot, "LIST_DISK_ONLY",
                    INT2NUM(VIR_DOMAIN_SNAPSHOT_LIST_DISK_ONLY));
    rb_define_const(c_domain_snapshot, "LIST_INTERNAL",
                    INT2NUM(VIR_DOMAIN_SNAPSHOT_LIST_INTERNAL));
    rb_define_const(c_domain_snapshot, "LIST_EXTERNAL",
                    INT2NUM(VIR_DOMAIN_SNAPSHOT_LIST_EXTERNAL));
    rb_define_method(c_domain, "list_all_snapshots",
                     libvirt_domain_list_all_snapshots, -1);

    rb_define_const(c_domain_snapshot, "CREATE_REDEFINE",
                    INT2NUM(VIR_DOMAIN_SNAPSHOT_CREATE_REDEFINE));
    rb_define_const(c_domain_snapshot, "CREATE_CURRENT",
                    INT2NUM(VIR_DOMAIN_SNAPSHOT_CREATE_CURRENT));
    rb_define_const(c_domain_snapshot, "CREATE_NO_METADATA",
                    INT2NUM(VIR_DOMAIN_SNAPSHOT_CREATE_NO_METADATA));
    rb_define_const(c_domain_snapshot, "CREATE_HALT",
                    INT2NUM(VIR_DOMAIN_SNAPSHOT_CREATE_HALT));
    rb_define_const(c_domain_snapshot, "CREATE_DISK_ONLY",
                    INT2NUM(VIR_DOMAIN_SNAPSHOT_CREATE_DISK_ONLY));
    rb_define_const(c_domain_snapshot, "CREATE_REUSE_EXT",
                    INT2NUM(VIR_DOMAIN_SNAPSHOT_CREATE_REUSE_EXT));
    rb_define_const(c_domain_snapshot, "CREATE_QUIESCE",
                    INT2NUM(VIR_DOMAIN_SNAPSHOT_CREATE_QUIESCE));
    rb_define_const(c_domain_snapshot, "CREATE_ATOMIC",
                    INT2NUM(VIR_DOMAIN_SNAPSHOT_CREATE_ATOMIC));
    rb_define_const(c_domain_snapshot, "CREATE_LIVE",
                    INT2NUM(VIR_DOMAIN_SNAPSHOT_CREATE_LIVE));
    rb_define_method(c_domain_snapshot, "num_children",
                     libvirt_domain_snapshot_num_children, -1);
    rb_define_method(c_domain_snapshot, "list_children_names",
                     libvirt_domain_snapshot_list_children_names, -1);
    rb_define_method(c_domain_snapshot, "list_all_children",
                     libvirt_domain_snapshot_list_all_children, -1);
    rb_define_method(c_domain_snapshot, "parent",
                     libvirt_domain_snapshot_parent, -1);
    rb_define_method(c_domain_snapshot, "current?",
                     libvirt_domain_snapshot_current_p, -1);
    rb_define_method(c_domain_snapshot, "has_metadata?",
                     libvirt_domain_snapshot_has_metadata_p, -1);
    rb_define_method(c_domain, "memory_stats_period=",
                     libvirt_domain_memory_stats_period, 1);
    rb_define_method(c_domain, "fstrim", libvirt_domain_fstrim, -1);
    rb_define_const(c_domain, "BLOCK_REBASE_SHALLOW",
                    INT2NUM(VIR_DOMAIN_BLOCK_REBASE_SHALLOW));
    rb_define_const(c_domain, "BLOCK_REBASE_REUSE_EXT",
                    INT2NUM(VIR_DOMAIN_BLOCK_REBASE_REUSE_EXT));
    rb_define_const(c_domain, "BLOCK_REBASE_COPY_RAW",
                    INT2NUM(VIR_DOMAIN_BLOCK_REBASE_COPY_RAW));
    rb_define_const(c_domain, "BLOCK_REBASE_COPY",
                    INT2NUM(VIR_DOMAIN_BLOCK_REBASE_COPY));

    rb_define_method(c_domain, "block_rebase", libvirt_domain_block_rebase, -1);
    rb_define_const(c_domain, "CHANNEL_FORCE",
                    INT2NUM(VIR_DOMAIN_CHANNEL_FORCE));
    rb_define_method(c_domain, "open_channel", libvirt_domain_open_channel, -1);
    rb_define_method(c_domain, "create_with_files",
                     libvirt_domain_create_with_files, -1);
    rb_define_const(c_domain, "OPEN_GRAPHICS_SKIPAUTH",
                    INT2NUM(VIR_DOMAIN_OPEN_GRAPHICS_SKIPAUTH));
    rb_define_method(c_domain, "open_graphics",
                     libvirt_domain_open_graphics, -1);
    rb_define_method(c_domain, "pmwakeup", libvirt_domain_pmwakeup, -1);
    rb_define_method(c_domain, "block_resize", libvirt_domain_block_resize, -1);
    rb_define_const(c_domain, "BLOCK_RESIZE_BYTES",
                    INT2NUM(VIR_DOMAIN_BLOCK_RESIZE_BYTES));
    rb_define_const(c_domain_snapshot, "REVERT_RUNNING",
                    INT2NUM(VIR_DOMAIN_SNAPSHOT_REVERT_RUNNING));
    rb_define_const(c_domain_snapshot, "REVERT_PAUSED",
                    INT2NUM(VIR_DOMAIN_SNAPSHOT_REVERT_PAUSED));
    rb_define_const(c_domain_snapshot, "REVERT_FORCE",
                    INT2NUM(VIR_DOMAIN_SNAPSHOT_REVERT_FORCE));
    rb_define_method(c_domain, "pmsuspend_for_duration",
                     libvirt_domain_pmsuspend_for_duration, -1);
    rb_define_method(c_domain, "migrate_compression_cache",
                     libvirt_domain_migrate_compression_cache, -1);
    rb_define_method(c_domain, "migrate_compression_cache=",
                     libvirt_domain_migrate_compression_cache_equal, 1);
    rb_define_const(c_domain, "DISK_ERROR_NONE",
                    INT2NUM(VIR_DOMAIN_DISK_ERROR_NONE));
    rb_define_const(c_domain, "DISK_ERROR_UNSPEC",
                    INT2NUM(VIR_DOMAIN_DISK_ERROR_UNSPEC));
    rb_define_const(c_domain, "DISK_ERROR_NO_SPACE",
                    INT2NUM(VIR_DOMAIN_DISK_ERROR_NO_SPACE));
    rb_define_method(c_domain, "disk_errors", libvirt_domain_disk_errors, -1);
    rb_define_method(c_domain, "emulator_pin_info",
                     libvirt_domain_emulator_pin_info, -1);
    rb_define_method(c_domain, "pin_emulator", libvirt_domain_pin_emulator, -1);
    rb_define_method(c_domain, "security_label_list",
                     libvirt_domain_security_label_list, 0);

    rb_define_const(c_domain, "KEYCODE_SET_LINUX",
                    INT2NUM(VIR_KEYCODE_SET_LINUX));
    rb_define_const(c_domain, "KEYCODE_SET_XT",
                    INT2NUM(VIR_KEYCODE_SET_XT));
    rb_define_const(c_domain, "KEYCODE_SET_ATSET1",
                    INT2NUM(VIR_KEYCODE_SET_ATSET1));
    rb_define_const(c_domain, "KEYCODE_SET_ATSET2",
                    INT2NUM(VIR_KEYCODE_SET_ATSET2));
    rb_define_const(c_domain, "KEYCODE_SET_ATSET3",
                    INT2NUM(VIR_KEYCODE_SET_ATSET3));
    rb_define_const(c_domain, "KEYCODE_SET_OSX",
                    INT2NUM(VIR_KEYCODE_SET_OSX));
    rb_define_const(c_domain, "KEYCODE_SET_XT_KBD",
                    INT2NUM(VIR_KEYCODE_SET_XT_KBD));
    rb_define_const(c_domain, "KEYCODE_SET_USB",
                    INT2NUM(VIR_KEYCODE_SET_USB));
    rb_define_const(c_domain, "KEYCODE_SET_WIN32",
                    INT2NUM(VIR_KEYCODE_SET_WIN32));
    rb_define_const(c_domain, "KEYCODE_SET_RFB", INT2NUM(VIR_KEYCODE_SET_RFB));

    rb_define_method(c_domain, "job_stats", libvirt_domain_job_stats, -1);
    rb_define_method(c_domain, "block_iotune",
                     libvirt_domain_block_iotune, -1);
    rb_define_method(c_domain, "block_iotune=",
                     libvirt_domain_block_iotune_equal, 1);
    rb_define_method(c_domain, "block_commit", libvirt_domain_block_commit, -1);
    rb_define_method(c_domain, "block_pull", libvirt_domain_block_pull, -1);
    rb_define_method(c_domain, "block_job_speed=",
                     libvirt_domain_block_job_speed_equal, 1);
    rb_define_const(c_domain, "BLOCK_JOB_SPEED_BANDWIDTH_BYTES",
                    INT2NUM(VIR_DOMAIN_BLOCK_JOB_SPEED_BANDWIDTH_BYTES));
    rb_define_method(c_domain, "block_job_info", libvirt_domain_block_job_info,
                     -1);
    rb_define_const(c_domain, "BLOCK_JOB_INFO_BANDWIDTH_BYTES",
                    INT2NUM(VIR_DOMAIN_BLOCK_JOB_INFO_BANDWIDTH_BYTES));

    rb_define_method(c_domain, "block_job_abort",
                     libvirt_domain_block_job_abort, -1);
    rb_define_method(c_domain, "interface_parameters",
                     libvirt_domain_interface_parameters, -1);
    rb_define_method(c_domain, "interface_parameters=",
                     libvirt_domain_interface_parameters_equal, 1);
    rb_define_method(c_domain, "block_stats_flags",
                     libvirt_domain_block_stats_flags, -1);
    rb_define_method(c_domain, "numa_parameters",
                     libvirt_domain_numa_parameters, -1);
    rb_define_method(c_domain, "numa_parameters=",
                     libvirt_domain_numa_parameters_equal, 1);
    rb_define_method(c_domain, "lxc_open_namespace",
                     libvirt_domain_lxc_open_namespace, -1);
    rb_define_method(c_domain, "qemu_agent_command",
                     libvirt_domain_qemu_agent_command, -1);
    rb_define_const(c_domain, "QEMU_AGENT_COMMAND_BLOCK",
                    INT2NUM(VIR_DOMAIN_QEMU_AGENT_COMMAND_BLOCK));
    rb_define_const(c_domain, "QEMU_AGENT_COMMAND_DEFAULT",
                    INT2NUM(VIR_DOMAIN_QEMU_AGENT_COMMAND_DEFAULT));
    rb_define_const(c_domain, "QEMU_AGENT_COMMAND_NOWAIT",
                    INT2NUM(VIR_DOMAIN_QEMU_AGENT_COMMAND_NOWAIT));
    rb_define_const(c_domain, "QEMU_AGENT_COMMAND_SHUTDOWN",
                    INT2NUM(VIR_DOMAIN_QEMU_AGENT_COMMAND_SHUTDOWN));
    rb_define_const(c_domain, "QEMU_MONITOR_COMMAND_DEFAULT",
                    INT2NUM(VIR_DOMAIN_QEMU_MONITOR_COMMAND_DEFAULT));
    rb_define_const(c_domain, "QEMU_MONITOR_COMMAND_HMP",
                    INT2NUM(VIR_DOMAIN_QEMU_MONITOR_COMMAND_HMP));
    rb_define_method(c_domain, "lxc_enter_namespace",
                     libvirt_domain_lxc_enter_namespace, -1);
    rb_define_method(c_domain, "migrate3", libvirt_domain_migrate3, -1);
    rb_define_method(c_domain, "migrate_to_uri3",
                     libvirt_domain_migrate_to_uri3, -1);
    rb_define_const(c_domain, "BLOCK_COMMIT_SHALLOW",
                    INT2NUM(VIR_DOMAIN_BLOCK_COMMIT_SHALLOW));
    rb_define_const(c_domain, "BLOCK_COMMIT_DELETE",
                    INT2NUM(VIR_DOMAIN_BLOCK_COMMIT_DELETE));
    rb_define_const(c_domain, "BLOCK_COMMIT_ACTIVE",
                    INT2NUM(VIR_DOMAIN_BLOCK_COMMIT_ACTIVE));
    rb_define_const(c_domain, "BLOCK_COMMIT_RELATIVE",
                    INT2NUM(VIR_DOMAIN_BLOCK_COMMIT_RELATIVE));
    rb_define_const(c_domain, "BLOCK_COMMIT_BANDWIDTH_BYTES",
                    INT2NUM(VIR_DOMAIN_BLOCK_COMMIT_BANDWIDTH_BYTES));
    rb_define_const(c_domain, "BLOCK_JOB_TYPE_UNKNOWN",
                    INT2NUM(VIR_DOMAIN_BLOCK_JOB_TYPE_UNKNOWN));
    rb_define_const(c_domain, "BLOCK_JOB_TYPE_PULL",
                    INT2NUM(VIR_DOMAIN_BLOCK_JOB_TYPE_PULL));
    rb_define_const(c_domain, "BLOCK_JOB_TYPE_COPY",
                    INT2NUM(VIR_DOMAIN_BLOCK_JOB_TYPE_COPY));
    rb_define_const(c_domain, "BLOCK_JOB_TYPE_COMMIT",
                    INT2NUM(VIR_DOMAIN_BLOCK_JOB_TYPE_COMMIT));
    rb_define_const(c_domain, "BLOCK_JOB_TYPE_ACTIVE_COMMIT",
                    INT2NUM(VIR_DOMAIN_BLOCK_JOB_TYPE_ACTIVE_COMMIT));
    rb_define_const(c_domain, "BLOCK_JOB_ABORT_ASYNC",
                    INT2NUM(VIR_DOMAIN_BLOCK_JOB_ABORT_ASYNC));
    rb_define_const(c_domain, "BLOCK_JOB_ABORT_PIVOT",
                    INT2NUM(VIR_DOMAIN_BLOCK_JOB_ABORT_PIVOT));
    rb_define_const(c_domain, "BLOCK_JOB_COMPLETED",
                    INT2NUM(VIR_DOMAIN_BLOCK_JOB_COMPLETED));
    rb_define_const(c_domain, "BLOCK_JOB_FAILED",
                    INT2NUM(VIR_DOMAIN_BLOCK_JOB_FAILED));
    rb_define_const(c_domain, "BLOCK_JOB_CANCELED",
                    INT2NUM(VIR_DOMAIN_BLOCK_JOB_CANCELED));
    rb_define_const(c_domain, "BLOCK_JOB_READY",
                    INT2NUM(VIR_DOMAIN_BLOCK_JOB_READY));
    rb_define_method(c_domain, "cpu_stats", libvirt_domain_cpu_stats, -1);
    rb_define_const(c_domain, "CORE_DUMP_FORMAT_RAW",
                    INT2NUM(VIR_DOMAIN_CORE_DUMP_FORMAT_RAW));
    rb_define_const(c_domain, "CORE_DUMP_FORMAT_KDUMP_ZLIB",
                    INT2NUM(VIR_DOMAIN_CORE_DUMP_FORMAT_KDUMP_ZLIB));
    rb_define_const(c_domain, "CORE_DUMP_FORMAT_KDUMP_LZO",
                    INT2NUM(VIR_DOMAIN_CORE_DUMP_FORMAT_KDUMP_LZO));
    rb_define_const(c_domain, "CORE_DUMP_FORMAT_KDUMP_SNAPPY",
                    INT2NUM(VIR_DOMAIN_CORE_DUMP_FORMAT_KDUMP_SNAPPY));
    rb_define_method(c_domain, "time", libvirt_domain_get_time, -1);
    rb_define_method(c_domain, "time=", libvirt_domain_time_equal, 1);
    rb_define_method(c_domain, "core_dump_with_format",
                     libvirt_domain_core_dump_with_format, -1);
    rb_define_method(c_domain, "fs_freeze", libvirt_domain_fs_freeze, -1);
    rb_define_method(c_domain, "fs_thaw", libvirt_domain_fs_thaw, -1);
    rb_define_method(c_domain, "fs_info", libvirt_domain_fs_info, -1);
    rb_define_method(c_domain, "rename", libvirt_domain_rename, -1);
    rb_define_method(c_domain, "user_password=", libvirt_domain_user_password_equal, 1);
    rb_define_const(c_domain, "PASSWORD_ENCRYPTED",
                    INT2NUM(VIR_DOMAIN_PASSWORD_ENCRYPTED));
    rb_define_const(c_domain, "TIME_SYNC", INT2NUM(VIR_DOMAIN_TIME_SYNC));
}
