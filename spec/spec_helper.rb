# frozen_string_literal: true

require 'rspec'
require 'rspec/collection_matchers'
require 'rest-client'
require 'securerandom'
require 'time'

require_relative 'support/kube_client'
require_relative 'support/http'
require_relative 'support/file'
require_relative 'support/config'
require_relative 'support/util'

RSpec.configure do |conf|
  include HttpHelpers
  include FileHelpers
  include UtilHelpers

  include KubeClient # provides kubectl command running

  conf.filter_run focus: true
  conf.run_all_when_everything_filtered = true
  conf.formatter = :documentation
end

RSpec::Matchers.define :be_a_404 do |expected|
  match do |response| # actual
    expect(response.code).to eq 404
  end
end

RSpec::Matchers.define :be_a_200 do |expected|
  match do |response| # actual
    expect(response.code).to eq 200
  end
end

RSpec::Matchers.define :include_regex do |regex|
  match do |actual|
    actual.find { |str| str =~ regex }
  end
end
