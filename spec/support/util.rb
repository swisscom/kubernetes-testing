# frozen_string_literal: true

require 'rspec'
require 'yaml'

require_relative 'config'

module UtilHelpers

  def random_name(base_name)
    suffix = (0...8).map { ('a'..'z').to_a[rand(26)] }.join
    base_name + '-' + suffix
  end

  def write_yaml(data, filename)
    File.open(filename, 'w') do |out|
      YAML.dump(data, out)
    end
  end

  def load_yaml(filename)
    YAML.load_file(filename)
  end

  def wait_until(timeout_secs=60, interval_secs=5)
    start = Time.now.to_i
    loop do
      begin
        yield
        break
      rescue RSpec::Expectations::ExpectationNotMetError => e
        elapsed = Time.now.to_i - start
        if elapsed > timeout_secs
          puts "Expectation not met after #{elapsed}s (timeout: #{timeout_secs}s), failing"
          raise e
        # else
        #   puts "Expectation not met after #{elapsed}s (timeout: #{timeout_secs}s), retrying"
        end
      end
      sleep(interval_secs)
    end
  end
end
