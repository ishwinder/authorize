require 'test_helper'

class ResourcePoolTest < ActiveSupport::TestCase

  def setup
    @resources = Array.new(10){|i| "resource #{i}"}
    @factory = lambda{@resources.pop}
  end

  test 'create' do
    @factory.expects(:call).never
    pool = Authorize::ResourcePool.new(5, @factory)
    assert_equal 0, pool.size
    assert_equal 5, pool.available
    assert !pool.empty?
  end

  test 'checkout calls factory for inventory' do
    @factory.expects(:call).once.returns(@resources[0])
    pool = Authorize::ResourcePool.new(5, @factory)
    assert_same @resources[0], pool.checkout
  end

  test 'checkout waits until one available' do
    begin
      @factory.expects(:call).once.returns(@resources[0])
      pool = Authorize::ResourcePool.new(1, @factory)
      pool.checkout # claim the only resource
      t = Thread.new(pool) {|p| p.checkout}
      t.run
      assert_equal 'sleep', t.status
      assert_equal 1, pool.num_waiting
    ensure
      t.exit
    end
  end

  test 'checkouts return distinct resources' do
    pool = Authorize::ResourcePool.new(5, @factory)
    resources = []
    5.times {resources << pool.checkout}
    assert_equal 5, resources.uniq.size
  end

  test 'checkin releases previously checked out resource' do
    pool = Authorize::ResourcePool.new(10, @factory)
    res = pool.checkout
    pool.checkin(res)
    assert pool.include?(res)
    assert_equal 10, pool.available
  end

  test 'checkin signals when one available' do
    begin
      @factory.expects(:call).once.returns(@resources[0])
      pool = Authorize::ResourcePool.new(1, @factory)
      res = pool.checkout # claim the only resource
      t = Thread.new(pool) {|p| p.checkout}
      t.run
      assert_equal 'sleep', t.status
      assert_equal 1, pool.num_waiting
      pool.checkin(res)
      t.join(2)
      assert_equal false, t.status
    ensure
      t.exit
    end
  end

  test 'expire removes resource from pool' do
    pool = Authorize::ResourcePool.new(3, @factory)
    resources = []
    3.times {resources << pool.checkout}
    marked_for_expiration = resources.first
    not_marked_for_expiration = resources.last
    3.times {pool.checkin(resources.pop)}
    pool.expire {|obj| obj == marked_for_expiration}
    assert !pool.include?(marked_for_expiration)
    assert pool.include?(not_marked_for_expiration)
  end

  test 'freshen never removes resource from pool' do
    pool = Authorize::ResourcePool.new(3, @factory)
    resources = []
    3.times {resources << pool.checkout}
    marked = resources.first
    not_marked = resources.last
    3.times {pool.checkin(resources.pop)}
    pool.freshen {|obj| obj == marked}
    assert pool.include?(marked)
    assert pool.include?(not_marked)
  end
end