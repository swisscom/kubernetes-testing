# frozen_string_literal: true

require 'rest-client'
require 'securerandom'

require_relative 'spec/support/kubectl'
require_relative 'spec/support/config'
require_relative 'spec/support/util'

include UtilHelpers
include Kubectl

puts "running env setup for kubernetes-testing ..."
kubectl = KUBECTL.new()
kubectl.setup_env
puts "finished env setup for kubernetes-testing!"
