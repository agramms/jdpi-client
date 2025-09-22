require 'test_helper'
require 'logger'

class TestTokenStorageMemory < Minitest::Test
  def setup
    @config = JDPIClient::Config.new
    @config.warn_on_local_tokens = false
    @storage = JDPIClient::TokenStorage::Memory.new(@config)
    @token = {
      'access_token' => 'test_token_123',
      'token_type' => 'Bearer',
      'expires_in' => 3600,
      'scope' => 'read write'
    }
  end

  def test_store_and_retrieve_token
    key = 'test_key'
    @storage.store(key, @token, 3600)

    retrieved = @storage.retrieve(key)
    assert_equal @token, retrieved
  end

  def test_exists_returns_true_for_stored_token
    key = 'test_key'
    @storage.store(key, @token, 3600)

    assert @storage.exists?(key)
  end

  def test_exists_returns_false_for_missing_token
    refute @storage.exists?('missing_key')
  end

  def test_delete_removes_token
    key = 'test_key'
    @storage.store(key, @token, 3600)

    @storage.delete(key)
    refute @storage.exists?(key)
    assert_nil @storage.retrieve(key)
  end

  def test_clear_all_removes_all_tokens
    @storage.store('key1', @token, 3600)
    @storage.store('key2', @token, 3600)

    @storage.clear_all
    refute @storage.exists?('key1')
    refute @storage.exists?('key2')
  end

  def test_healthy_returns_true
    assert @storage.healthy?
  end

  def test_token_expiration
    key = 'test_key'
    @storage.store(key, @token, 0.1) # 0.1 second TTL

    assert @storage.exists?(key)
    sleep(0.2)
    refute @storage.exists?(key)
    assert_nil @storage.retrieve(key)
  end

  def test_thread_safety
    key = 'test_key'
    threads = []
    results = {}

    10.times do |i|
      threads << Thread.new do
        token = @token.merge('access_token' => "token_#{i}")
        @storage.store("#{key}_#{i}", token, 3600)
        results[i] = @storage.retrieve("#{key}_#{i}")
      end
    end

    threads.each(&:join)

    10.times do |i|
      expected_token = @token.merge('access_token' => "token_#{i}")
      assert_equal expected_token, results[i]
    end
  end

  def test_warning_when_enabled
    @config.warn_on_local_tokens = true
    log_output = StringIO.new
    logger = Logger.new(log_output)
    @config.logger = logger

    @storage.store('test_key', @token, 3600)

    log_content = log_output.string
    assert_includes log_content, 'WARN'
    assert_includes log_content, 'in-memory storage'
  end

  def test_no_warning_when_disabled
    @config.warn_on_local_tokens = false
    log_output = StringIO.new
    logger = Logger.new(log_output)
    @config.logger = logger

    @storage.store('test_key', @token, 3600)

    log_content = log_output.string
    refute_includes log_content, 'WARN'
  end
end