require 'test_helper'

class UserDataIsoTest < Minitest::Test
  def setup
    @compute = Fog::Compute[:libvirt]
    @server = @compute.servers.new(:name => "test")
    @test_data = "test data"
  end

  def test_contains_meta_data_file
    @server.stubs(:system).returns(true)
    in_a_temp_dir do |d|
      @server.generate_config_iso_in_dir(d, @test_data) {|iso| assert File.exist?(File.join(d, 'meta-data')) }
    end
  end

  def test_contains_user_data_file
    @server.stubs(:system).returns(true)
    in_a_temp_dir do |d|
      @server.generate_config_iso_in_dir(d, @test_data) do |iso|
        assert File.exist?(File.join(d, 'user-data'))
        assert_equal @test_data,  File.read(File.join(d, 'user-data'))
      end
    end
  end

  def test_iso_is_generated
    in_a_temp_dir do |d|
      @server.expects(:system).with { |command, *_args| command == 'xorrisofs' }.returns(true)
      @server.generate_config_iso_in_dir(d, @test_data) {|iso| }
    end
  end

  def test_volume_is_created_during_user_data_iso_generation
    @server.stubs(:system).returns(true)
    Fog::Libvirt::Compute::Volumes.any_instance.expects(:create).
        with(has_entries(:name => @server.cloud_init_volume_name)).
        returns(@compute.volumes.new)
    Fog::Libvirt::Compute::Volume.any_instance.stubs(:upload_image)

    @server.create_user_data_iso
  end

  def test_volume_is_uploaded_during_user_data_iso_generation
    @server.stubs(:system).returns(true)
    Fog::Libvirt::Compute::Volumes.any_instance.stubs(:create).returns(@compute.volumes.new)
    Fog::Libvirt::Compute::Volume.any_instance.expects(:upload_image).returns(true)

    @server.create_user_data_iso
  end

  def test_iso_file_is_set_during_user_data_iso_generation
    @server.stubs(:system).returns(true)
    Fog::Libvirt::Compute::Volumes.any_instance.stubs(:create).returns(@compute.volumes.new)
    Fog::Libvirt::Compute::Volume.any_instance.stubs(:upload_image)

    @server.create_user_data_iso
    assert_equal @server.cloud_init_volume_name, @server.iso_file
  end

  def test_iso_dir_is_set_during_user_data_iso_generation
    @server.stubs(:system).returns(true)
    volume = @compute.volumes.new
    volume.stubs(:path).returns("/srv/libvirt/#{@server.cloud_init_volume_name}")
    Fog::Libvirt::Compute::Volumes.any_instance.stubs(:create).returns(volume)
    Fog::Libvirt::Compute::Volume.any_instance.stubs(:upload_image)

    @server.create_user_data_iso
    assert_equal '/srv/libvirt', @server.iso_dir
  end

  def in_a_temp_dir
    Dir.mktmpdir('test-dir') do |d|
      yield d
    end
  end
end
