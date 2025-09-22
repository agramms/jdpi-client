# frozen_string_literal: true

source "https://rubygems.org"

gemspec

gem "rake", ">= 13.0"

# Ruby 3.0 compatibility constraints for all development dependencies
gem "activesupport", "< 7.1"          # Rails 7.1+ requires Ruby >= 3.1
gem "aws-sdk-dynamodb", "< 1.110"     # Conservative constraint for AWS SDK
gem "pg", "< 1.6"                     # Constrain to stable version for Ruby 3.0
gem "redis", "< 5.3"                  # Newer versions may have Ruby 3.1+ requirements
gem "rubocop", "< 1.70"               # Newer versions may require Ruby 3.1+
gem "securerandom", "< 0.4"           # 0.4+ requires Ruby >= 3.1
gem "sqlite3", "< 2.0"                # 2.0+ requires Ruby >= 3.1
