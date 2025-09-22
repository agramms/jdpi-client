require 'test_helper'

class TestTokenStorageRedis < Minitest::Test
  def setup
    @config = JDPIClient::Config.new
    @config.token_storage_url = 'redis://localhost:6379/15'
    @config.token_encryption_key = 'test_encryption_key_32_characters'

    @token = {
      'access_token' => 'test_token_123',
      'token_type' => 'Bearer',
      'expires_in' => 3600,
      'scope' => 'read write'
    }

    # Check if redis gem is available
    begin
      require 'redis'
      @redis_available = true

      # Mock Redis to avoid requiring actual Redis connection
      @mock_redis = Minitest::Mock.new
      Redis.stub :new, @mock_redis do
        @storage = JDPIClient::TokenStorage::Redis.new(@config)
      end
    rescue LoadError
      @redis_available = false
    end
  end

  def test_initialization_with_url
    skip 'redis gem not available' unless @redis_available

    Redis.stub :new, @mock_redis do
      storage = JDPIClient::TokenStorage::Redis.new(@config)
      assert_instance_of JDPIClient::TokenStorage::Redis, storage
    end
  end

  def test_initialization_with_options
    skip 'redis gem not available' unless @redis_available

    @config.token_storage_url = nil
    @config.token_storage_options = { host: 'localhost', port: 6379, db: 15 }

    Redis.stub :new, @mock_redis do
      storage = JDPIClient::TokenStorage::Redis.new(@config)
      assert_instance_of JDPIClient::TokenStorage::Redis, storage
    end
  end

  def test_store_encrypts_and_sets_with_expiration
    skip 'redis gem not available' unless @redis_available
    key = 'test_key'
    encrypted_data = 'encrypted_token_data'

    JDPIClient::TokenStorage::Encryption.stub :encrypt, encrypted_data do
      @mock_redis.expect :setex, 'OK', [key, 3600, encrypted_data]

      Redis.stub :new, @mock_redis do
        storage = JDPIClient::TokenStorage::Redis.new(@config)
        storage.store(key, @token, 3600)
      end
    end

    @mock_redis.verify
  end

  def test_retrieve_gets_and_decrypts
    skip 'redis gem not available' unless @redis_available

    key = 'test_key'
    encrypted_data = 'encrypted_token_data'

    @mock_redis.expect :get, encrypted_data, [key]

    JDPIClient::TokenStorage::Encryption.stub :decrypt, @token do
      Redis.stub :new, @mock_redis do
        storage = JDPIClient::TokenStorage::Redis.new(@config)
        result = storage.retrieve(key)
        assert_equal @token, result
      end
    end

    @mock_redis.verify
  end

  def test_retrieve_returns_nil_for_missing_key
    skip 'redis gem not available' unless @redis_available

    key = 'missing_key'
    @mock_redis.expect :get, nil, [key]

    Redis.stub :new, @mock_redis do
      storage = JDPIClient::TokenStorage::Redis.new(@config)
      result = storage.retrieve(key)
      assert_nil result
    end

    @mock_redis.verify
  end

  def test_exists_checks_key_existence
    skip 'redis gem not available' unless @redis_available

    key = 'test_key'
    @mock_redis.expect :exists?, true, [key]

    Redis.stub :new, @mock_redis do
      storage = JDPIClient::TokenStorage::Redis.new(@config)
      result = storage.exists?(key)
      assert result
    end

    @mock_redis.verify
  end

  def test_delete_removes_key
    skip 'redis gem not available' unless @redis_available

    key = 'test_key'
    @mock_redis.expect :del, 1, [key]

    Redis.stub :new, @mock_redis do
      storage = JDPIClient::TokenStorage::Redis.new(@config)
      storage.delete(key)
    end

    @mock_redis.verify
  end

  def test_clear_all_removes_matching_keys
    skip 'redis gem not available' unless @redis_available

    pattern = 'jdpi_client:*'
    keys = ['jdpi_client:key1', 'jdpi_client:key2']

    @mock_redis.expect :keys, keys, [pattern]
    @mock_redis.expect :del, 2, [keys]

    Redis.stub :new, @mock_redis do
      storage = JDPIClient::TokenStorage::Redis.new(@config)
      storage.clear_all
    end

    @mock_redis.verify
  end

  def test_healthy_checks_connection
    skip 'redis gem not available' unless @redis_available

    @mock_redis.expect :ping, 'PONG'

    Redis.stub :new, @mock_redis do
      storage = JDPIClient::TokenStorage::Redis.new(@config)
      result = storage.healthy?
      assert result
    end

    @mock_redis.verify
  end

  def test_healthy_returns_false_on_error
    skip 'redis gem not available' unless @redis_available

    @mock_redis.expect :ping, -> { raise Redis::ConnectionError }

    Redis.stub :new, @mock_redis do
      storage = JDPIClient::TokenStorage::Redis.new(@config)
      result = storage.healthy?
      refute result
    end

    @mock_redis.verify
  end

  def test_acquire_lock_sets_with_nx_and_ex
    skip 'redis gem not available' unless @redis_available

    lock_key = 'lock:test_key'
    @mock_redis.expect :set, 'OK', [lock_key, '1', { nx: true, ex: 60 }]

    Redis.stub :new, @mock_redis do
      storage = JDPIClient::TokenStorage::Redis.new(@config)
      result = storage.send(:acquire_lock, 'test_key')
      assert result
    end

    @mock_redis.verify
  end

  def test_acquire_lock_returns_false_when_exists
    skip 'redis gem not available' unless @redis_available

    lock_key = 'lock:test_key'
    @mock_redis.expect :set, nil, [lock_key, '1', { nx: true, ex: 60 }]

    Redis.stub :new, @mock_redis do
      storage = JDPIClient::TokenStorage::Redis.new(@config)
      result = storage.send(:acquire_lock, 'test_key')
      refute result
    end

    @mock_redis.verify
  end

  def test_release_lock_deletes_key
    skip 'redis gem not available' unless @redis_available

    lock_key = 'lock:test_key'
    @mock_redis.expect :del, 1, [lock_key]

    Redis.stub :new, @mock_redis do
      storage = JDPIClient::TokenStorage::Redis.new(@config)
      storage.send(:release_lock, 'test_key')
    end

    @mock_redis.verify
  end

  def test_missing_redis_gem_raises_error
    skip 'redis gem not available' unless @redis_available

    # Simulate missing redis gem by stubbing require to raise LoadError
    original_require = Kernel.method(:require)
    Kernel.define_method(:require) do |name|
      if name == 'redis'
        raise LoadError, 'cannot load such file -- redis'
      else
        original_require.call(name)
      end
    end

    error = assert_raises(JDPIClient::Error) do
      JDPIClient::TokenStorage::Redis.new(@config)
    end

    assert_includes error.message, 'Redis gem is required'

    # Restore original require method
    Kernel.define_method(:require, original_require)
  end
end