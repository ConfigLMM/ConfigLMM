=====================
ruby-libvirt releases
=====================


0.8.4 (2024-08-01)
==================

* Explicitly disallow use of ``new`` for wrapper classes


0.8.3 (2024-05-13)
==================

* Fix runtime warnings with Ruby >= 3.2
* Improve build system
* Improve website


0.8.2 (2024-02-09)
==================

* Fix ``StoragePool#list_all_volumes``
* Fix regression in ``Domain#attach_device`` and ``Domain#detach_device``


0.8.1 (2024-02-08)
==================

* Add missing ``virDomainUndefineFlagsValues`` constants
* Require libvirt 2.0.0
* Always use pkg-config for detecting libvirt
* Drop most compile-time feature checks


0.8.0 (2021-11-15)
==================

* Fix default values for ``node_cpu_stats`` and ``node_memory_stats``
* Fix cpumap allocation for ``virDomainGetVcpus``
* Enforce UTF8 for strings and exceptions
* Drop local ``have_const``
* Use sensible default for ``libvirt_domain_qemu_agent_command``


0.7.1 (2018-02-18)
==================

* Fix a bad bug in block_resize (Marius Rieder)
* Fix up some problems pointed out by clang
* Fix up the tests for small semantic differences in how libvirt works


0.7.0 (2016-09-22)
==================

* Fix network lease API to allow arguments that libvirt allows
* Implement ``VIRT_STORAGE_POOL_CREATE`` flags
* Implement more ``VIR_STORAGE_VOL`` flags
* Implement ``VIR_DOMAIN_QEMU_AGENT_COMMAND_SHUTDOWN``
* Implement ``virDomainDefineXMLFlags``
* Implement ``virDomainRename``
* Implement ``virDomainSetUserPassword``
* Implement ``VIR_DOMAIN_TIME_SYNC``
* Fix the return value from ``virStreamSourceFunc`` so volume upload works


0.6.0 (2015-11-20)
==================

* Fix possible buffer overflow
* Fix storage volume creation error messages
* Add additional storage pool defines
* Implement ``Network#dhcp_leases`` method
* Implement ``Connect#node_alloc_pages`` method
* Implement ``Domain#time`` method
* Implement ``Connect#domain_capabilities`` method
* Implement ``Domain#core_dump_with_format`` method
* Implement ``Domain#fs_freeze`` method
* Implement ``Domain#fs_info`` method
* Implement ``Connect#node_free_pages`` method


0.5.2 (2014-01-08)
==================

* Fix to make sure we don't free more entires than retrieved


0.5.1 (2013-12-15)
==================

* Fixes to compile against older libvirt
* Fixes to compile against ruby 1.8


0.5.0 (2013-12-09)
==================

* Updated ``Network`` class, implementing almost all libvirt APIs
* Updated ``Domain`` class, implementing almost all libvirt APIs
* Updated ``Connection`` class, implementing almost all libvirt APIs
* Updated ``DomainSnapshot`` class, implementing almost all libvirt APIs
* Updated ``NodeDevice`` class, implementing almost all libvirt APIs
* Updated ``Storage`` class, implementing almost all libvirt APIs
* Add constants for almost all libvirt defines
* Improved performance in the library by using alloca


0.4.0 (2011-07-27)
==================

* Updated ``Domain`` class, implementing ``dom.memory_parameters=``,
  ``dom.memory_parameters``, ``dom.updated?``, ``dom.migrate2``,
  ``dom.migrate_to_uri2``, ``dom.migrate_set_max_speed``,
  ``dom.qemu_monitor_command``, ``dom.blkio_parameters``,
  ``dom.blkio_parameters=``, ``dom.state``, ``dom.open_console``,
  ``dom.screenshot`` and ``dom.inject_nmi``
* Implementation of the ``Stream`` class, which covers the libvirt
  ``virStream`` APIs
* Add the ability to build against non-system libvirt libraries
* Updated ``Error`` object, which now includes the libvirt code, component and
  level of the error, as well as all of the error constants from ``libvirt.h``
* Updated ``Connect`` class, implementing ``conn.sys_info``, ``conn.stream``,
  ``conn.interface_change_begin``, ``conn.interface_change_commit`` and
  ``conn.interface_change_rollback``
* Updated ``StorageVol`` class, implementing ``vol.download`` and
  ``vol.upload``
* Various bugfixes


0.3.0 (2010-12-12)
==================

* Implementation of ``Libvirt::open_auth``, ``Libvirt::event_register_impl``
* Updated ``Connect`` class, implementing ``conn.compare_cpu``,
  ``conn.baseline_cpu``, ``conn.domain_event_register_any``,
  ``conn.domain_event_deregister_any``, ``conn.domain_event_register``,
  ``conn.domain_event_deregister`` and ``conn.create_domain_xml``
* Updated ``Domain`` class, implementing ``dom.get_vcpus``,
  ``dom.update_device``, ``dom.scheduler_type``, ``dom.scheduler_parameters``,
  ``dom.scheduler_parameters=``, ``dom.num_vcpus``, ``dom.vcpus_flags=`` and
  ``dom.qemu_monitor_command``
* Updated ``Interface`` class, implementing ``interface.free``
* Many potential memory leaks have been fixed
* Many bugfixes
* Documentation update of many methods, including all of the lookup methods
  that were missing before


0.2.0 (2010-07-01)
==================

* Updated ``Storage`` class, implementing ``pool.active?``,
  ``pool.persistent?`` and ``pool.vol_create_xml_from``
* Updated ``Connect`` class, implementing ``conn.node_free_memory``,
  ``conn.node_cells_free_memory``, ``conn.node_get_security_model``,
  ``conn.encrypted?``, ``conn.libversion`` and ``conn.secure?``
* Updated ``Network`` class, implementing ``net.active?`` and
  ``net.persistent?``
* Update ``Domain`` class, implementing ``conn.domain_xml_from_native``,
  ``conn.domain_xml_to_native``, ``dom.migrate_to_uri``,
  ``dom.migrate_set_max_downtime``, ``dom.managed_save``,
  ``dom.has_managed_save?``, ``dom.managed_save_remove``,
  ``dom.security_label``, ``dom.block_stats``, ``dom.memory_stats``,
  ``dom.blockinfo``, ``dom.block_peek``, ``dom.memory_peek``, ``dom.active?``,
  ``dom.persistent?``, ``dom.snapshot_create_xml``, ``dom.num_of_snapshots``,
  ``dom.list_snapshots``, ``dom.lookup_snapshot_by_name``,
  ``dom.has_current_snapshot?``, ``dom.revert_to_snapshot``,
  ``dom.current_snapshot``, ``snapshot.xml_desc``, ``snapshot.delete``,
  ``dom.job_info`` and ``dom.abort_job``
* Implementation of the ``NodeDevice`` class
* Implementation of the ``Secret`` class
* Implementation of the ``NWFilter`` class
* Implementation of the ``Interface`` class
* Conversion of the development tree to git
* New maintainer (Chris Lalancette). David Lutterkort has agreed to transfer
  maintainership since he is not actively involved in their development
  anymore


0.1.0 (2008-11-18)
==================

* Add binding for ``virConnectFindStoragePoolSources`` (Chris Lalancette)
* Fix ``dom_migrate`` (Chris Lalancette)
* Add the ``MIGRATE_LIVE`` (``enum virDomainMigrateFlags``) flag
* Slight improvements of the unit tests


0.0.7 (2008-04-15)
==================

* Binding for ``virDomainMigrate``
* Fix crash caused by using ``virResetError``
* More sensible message included in exceptions


0.0.6 (2008-04-02)
==================

* Fix test failure exposed by the Fedora builders


0.0.5 (2008-04-02)
==================

* Explicit free methods for various objects (based on a patch by Vadim Zaliva)
* Make the FLAGS argument for various calls optional, and default it to 0
  (Chris Lalancette)
* More finegrained exceptions on errors, containing libvirt error message
  (Mohammed Morsi)


0.0.4 (2008-04-01)
==================

* Bindings for the libvirt storage API (requires libvirt 0.4.1)
* Suppress some bindings if the underlying libvirt doesn't support it
* Bindings for ``virDomainSetMemory``, ``virDomainPinVcpu`` and
  ``virDomainSetVcpus`` (Vadim Zaliva)


0.0.2 (2007-12-06)
==================

* Add ``virNodeGetInfo`` binding
* Convert Ruby API from StudlyCaps to under_score_separation, since that's
  the Ruby convention


0.0.1 (2007-11-19)
==================

* Initial release
