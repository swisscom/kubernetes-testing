# frozen_string_literal: true

require 'open3'

module CommandRunner
  class CommandFailedError < StandardError; end

  class Runner
    def initialize(environment: ENV)
      @environment = environment
    end

    def run(command, allow_failure: false)
      stdout_and_stderr, status = Open3.capture2e(environment, "#{command}")

      if !allow_failure && !status.success?
        message = "command failed! - #{command}\n\n#{stdout_and_stderr}\n\nexit status: #{status.exitstatus}"
        fail CommandFailedError, message
      end

      stdout_and_stderr
    rescue => e
      raise CommandFailedError, e
    end

    private
    attr_reader :environment
  end
end
