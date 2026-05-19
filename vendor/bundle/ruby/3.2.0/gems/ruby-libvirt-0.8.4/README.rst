============
ruby-libvirt
============

Ruby bindings for `libvirt <https://libvirt.org/>`__.


Usage
=====

Add ``require 'libvirt'`` to your program, then call
``Libvirt::open`` or ``Libvirt::open_read_only`` to obtain a
connection.

See ``examples/*.rb`` and ``tests/*.rb`` for more examples.


Hacking
=======

On a Fedora machine, run

::

    $ yum install libvirt-devel ruby-devel rubygem-rake

followed by

::

    $ rake build

To run code against the bindings without having to install them
first, ``$RUBYLIB`` needs to be set appropriately. For example:

::

    $ export RUBYLIB="lib:ext/libvirt"
    $ ruby -rlibvirt -e 'puts Libvirt::version[0]'


Contributing
============

See `CONTRIBUTING.rst <CONTRIBUTING.rst>`__.
