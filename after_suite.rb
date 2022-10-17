# frozen_string_literal: true

require 'rest-client'
require 'securerandom'

require_relative 'spec/support/kubectl'
require_relative 'spec/support/config'
require_relative 'spec/support/util'

include UtilHelpers
include Kubectl

puts "running env cleanup for kubernetes-testing ..."
kubectl = KUBECTL.new()
kubectl.cleanup_env
puts "finished cleaning up kubernetes-testing!"
