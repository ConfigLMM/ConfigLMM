# -*- ruby -*-
# Rakefile: build ruby libvirt bindings
#
# Copyright (C) 2007,2010 Red Hat, Inc.
# Copyright (C) 2013,2014 Chris Lalancette <clalancette@gmail.com>
#
# Distributed under the GNU Lesser General Public License v2.1 or later.
# See COPYING for details
#
# David Lutterkort <dlutter@redhat.com>

# Rakefile for ruby-rpm -*- ruby -*-
require 'rake/clean'
require 'rake/testtask'
require 'rdoc/task'
require 'rubygems/package_task'

PKG_NAME='ruby-libvirt'
PKG_VERSION='0.8.4'

EXT_DIR = "ext/libvirt"
EXTCONF = "#{EXT_DIR}/extconf.rb"
MAKEFILE = "#{EXT_DIR}/Makefile"
LIBVIRT_MODULE = "#{EXT_DIR}/_libvirt.so"
SPEC_FILE = "#{PKG_NAME}.spec"
SRC_FILES = FileList[
    "#{EXT_DIR}/_libvirt.c",
    "#{EXT_DIR}/common.c",
    "#{EXT_DIR}/common.h",
    "#{EXT_DIR}/connect.c",
    "#{EXT_DIR}/connect.h",
    "#{EXT_DIR}/domain.c",
    "#{EXT_DIR}/domain.h",
    "#{EXT_DIR}/interface.c",
    "#{EXT_DIR}/interface.h",
    "#{EXT_DIR}/network.c",
    "#{EXT_DIR}/network.h",
    "#{EXT_DIR}/nodedevice.c",
    "#{EXT_DIR}/nodedevice.h",
    "#{EXT_DIR}/nwfilter.c",
    "#{EXT_DIR}/nwfilter.h",
    "#{EXT_DIR}/secret.c",
    "#{EXT_DIR}/secret.h",
    "#{EXT_DIR}/storage.c",
    "#{EXT_DIR}/storage.h",
    "#{EXT_DIR}/stream.c",
    "#{EXT_DIR}/stream.h",
]
LIB_FILES = FileList[
    "lib/libvirt.rb",
]
GEN_FILES = FileList[
    MAKEFILE,
    "#{EXT_DIR}/extconf.h",
]

#
# Additional files for clean/clobber
#

CLEAN.include [ "#{EXT_DIR}/*.o", LIBVIRT_MODULE ]
CLOBBER.include [ "#{EXT_DIR}/mkmf.log" ] + GEN_FILES

#
# Build locally
#

task :default => :build

file MAKEFILE => EXTCONF do |t|
    Dir::chdir(File::dirname(EXTCONF)) do
        sh "ruby #{File::basename(EXTCONF)}"
    end
end
file LIBVIRT_MODULE => SRC_FILES + [ MAKEFILE ] do |t|
    Dir::chdir(File::dirname(EXTCONF)) do
        sh "make"
    end
end
desc "Build the native library"
task :build => LIBVIRT_MODULE

#
# Test tasks
#

TEST_FILES = FileList[
    "tests/test_conn.rb",
    "tests/test_domain.rb",
    "tests/test_interface.rb",
    "tests/test_network.rb",
    "tests/test_nodedevice.rb",
    "tests/test_nwfilter.rb",
    "tests/test_open.rb",
    "tests/test_secret.rb",
    "tests/test_storage.rb",
    "tests/test_stream.rb",
    "tests/test_utils.rb",
]

Rake::TestTask.new(:test) do |t|
    t.test_files = TEST_FILES
    t.libs << EXT_DIR
end
task :test => :build

#
# Documentation tasks
#

RDOC_MAIN = "doc/main.rdoc"
RDOC_FILES = FileList[ RDOC_MAIN ] + SRC_FILES + LIB_FILES

RDoc::Task.new do |rd|
    rd.main = RDOC_MAIN
    rd.rdoc_dir = "doc/site/api"
    rd.rdoc_files.include(RDOC_FILES)
end

RDoc::Task.new(:ri) do |rd|
    rd.main = RDOC_MAIN
    rd.rdoc_dir = "doc/ri"
    rd.options << "--ri-system"
    rd.rdoc_files.include(RDOC_FILES)
end

#
# Package tasks
#

PKG_FILES = FileList[
    "Rakefile",
    "COPYING",
    "README.rst",
    "NEWS.rst",
    EXTCONF,
    RDOC_MAIN,
] + SRC_FILES + LIB_FILES + TEST_FILES

SPEC = Gem::Specification.new do |s|
    s.name = PKG_NAME
    s.version = PKG_VERSION
    s.files = PKG_FILES
    s.extensions = EXTCONF
    s.required_ruby_version = ">= 1.8.1"
    s.summary = "Ruby bindings for libvirt"
    s.description = <<~EOF
        ruby-libvirt allows applications written in Ruby to use the
        libvirt API.
    EOF
    s.authors = ["David Lutterkort", "Chris Lalancette"]
    s.license = "LGPL-2.1-or-later"
    s.email = "devel@lists.libvirt.org"
    s.homepage = "https://ruby.libvirt.org/"
    s.metadata = {
        "source_code_uri" => "https://gitlab.com/libvirt/libvirt-ruby",
        "bug_tracker_uri" => "https://gitlab.com/libvirt/libvirt-ruby/-/issues",
        "documentation_uri" => "https://ruby.libvirt.org/api/index.html",
    }
end

Gem::PackageTask.new(SPEC) do |pkg|
    pkg.need_tar = true
    pkg.need_zip = true
end

desc "Build (S)RPM for #{PKG_NAME}"
task :rpm => [ :package ] do |t|
    pkg_dir = File::expand_path("pkg")
    sed = [
        "sed",
        "-e", "'s/@VERSION@/#{PKG_VERSION}/'",
        "#{SPEC_FILE}.in", ">#{pkg_dir}/#{SPEC_FILE}",
    ]
    sh sed.join(" ")
    rpmbuild = [
        "rpmbuild",
        "--clean",
        "--define", "'_topdir #{pkg_dir}'",
        "--define", "'_sourcedir #{pkg_dir}'",
        "--define", "'_srcrpmdir #{pkg_dir}'",
        "--define", "'_rpmdir #{pkg_dir}'",
        "--define", "'_builddir #{pkg_dir}'",
        "-ba", "#{pkg_dir}/#{SPEC_FILE}",
    ]
    sh rpmbuild.join(" ")
end
