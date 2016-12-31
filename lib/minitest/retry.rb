require "minitest/retry/version"

module Minitest
  module Retry
    def self.use!(retry_count: 3, io: $stdout, verbose: true, exceptions_to_retry: [])
      @retry_count, @io, @verbose, @exceptions_to_retry = retry_count, io, verbose, exceptions_to_retry
      @failure_callback = nil
      Minitest.prepend(self)
    end

    def self.on_failure(&block)
      return unless block_given?
      @failure_callback = block
    end

    def self.retry_count
      @retry_count
    end

    def self.io
      @io
    end

    def self.verbose
      @verbose
    end

    def self.exceptions_to_retry
      @exceptions_to_retry
    end

    def self.failure_callback
      @failure_callback
    end

    def self.failure_to_retry?(failures = [])
      return false if failures.empty?
      return true if Minitest::Retry.exceptions_to_retry.empty?
      errors = failures.map(&:error).map(&:class)
      (errors & Minitest::Retry.exceptions_to_retry).any?
    end

    module ClassMethods
      def run_one_method(klass, method_name)
        result = super(klass, method_name)
        return result unless Minitest::Retry.failure_to_retry?(result.failures)
        if !result.skipped?
          Minitest::Retry.failure_callback.call if Minitest::Retry.failure_callback
          Minitest::Retry.retry_count.times do |count|
            if Minitest::Retry.verbose && Minitest::Retry.io
              msg = "[MinitestRetry] retry '%s' count: %s,  msg: %s\n" %
                [method_name, count + 1, result.failures.map(&:message).join(",")]
              Minitest::Retry.io.puts(msg)
            end

            result = super(klass, method_name)
            break if result.failures.empty?
          end
        end
        result
      end
    end

    def self.prepended(base)
      class << base
        prepend ClassMethods
      end
    end
  end
end
