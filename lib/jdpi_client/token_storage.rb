# frozen_string_literal: true

# Token storage components for distributed token caching
module JDPIClient
  module TokenStorage
    autoload :Base, "jdpi_client/token_storage/base"
    autoload :Memory, "jdpi_client/token_storage/memory"
    autoload :Redis, "jdpi_client/token_storage/redis"
    autoload :DynamoDB, "jdpi_client/token_storage/dynamodb"
    autoload :Database, "jdpi_client/token_storage/database"
    autoload :Encryption, "jdpi_client/token_storage/encryption"
    autoload :Factory, "jdpi_client/token_storage/factory"
  end
end