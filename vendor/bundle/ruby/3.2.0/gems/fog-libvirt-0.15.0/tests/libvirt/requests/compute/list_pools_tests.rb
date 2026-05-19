class FakePool < Fog::Model
  # Fake pool object to allow exercising the internal parsing of pools
  # returned by the client queries
  identity :uuid

  attribute :persistent
  attribute :autostart
  attribute :active
  attribute :name
  attribute :num_of_volumes
  attr_reader :info

  class FakeInfo < Fog::Model
    attribute :allocation
    attribute :capacity
    attribute :state
  end

  def initialize(attributes = {})
    @info = FakeInfo.new(attributes.dup.delete(:info))
    super(attributes)
  end

  def active?
    active
  end

  def autostart?
    autostart
  end

  def persistent?
    persistent
  end
end

Shindo.tests("Fog::Compute[:libvirt] | list_pools request", 'libvirt') do

  compute = Fog::Compute[:libvirt]

  tests("Lists Pools") do
    response = compute.list_pools
    test("should be an array") { response.kind_of? Array }
    test("should have two pools") { response.length == 1 }
  end

  tests("Handle Inactive Pools") do
    inactive_pool = {
      :uuid => 'pool.uuid',
      :persistent => true,
      :autostart => true,
      :active => false,
      :name => 'inactive_pool1',
      :info => {
        :allocation => 123456789,
        :capacity => 123456789,
        :state => 2 # running
      },
      :num_of_volumes => 3
    }

    response = compute.send(:pool_to_attributes, FakePool.new(inactive_pool), true)

    test("should be hash of attributes") { response.kind_of? Hash }

    response = compute.send(:pool_to_attributes, FakePool.new(inactive_pool))

    test("should be nil") { response.nil? }

  end
end
