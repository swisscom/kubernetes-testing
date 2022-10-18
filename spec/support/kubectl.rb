# frozen_string_literal: true

require 'fileutils'
require 'yaml'

require_relative 'command_runner'
require_relative 'util'

module Kubectl
  class KUBECTL
    def initialize(command_runner: CommandRunner::Runner.new)
      @command_runner = command_runner
    end

    def run(command, allow_failure: false)
      run_with_env(command, '', allow_failure: allow_failure)
    end

    def run_with_env(command, env, allow_failure: false)
      run_cmd = "TERM=dumb kubectl #{command}"
      run_cmd = "#{env} #{run_cmd}" unless env.to_s.empty?
      command_runner.run(run_cmd, allow_failure: allow_failure)
    end

    def wait_for_deployment(deployment, wait_time = "120s", namespace = Config.namespace, allow_failure: false)
      run("wait --for condition=available deploy/#{deployment} --timeout=#{wait_time} -n #{namespace}", allow_failure: allow_failure)
    end

    def cluster_info(allow_failure: false)
      run("cluster-info", allow_failure: allow_failure)
    end

    def get_namespaces(allow_failure: false)
      namespaces = get_objects("namespaces", allow_failure: allow_failure)
      namespaces['items']
    end

    def get_certificates(namespace = Config.namespace, allow_failure: false)
      ingresses = get_objects("certificate", namespace, allow_failure: allow_failure)
      ingresses['items']
    end

    def get_ingresses(namespace = Config.namespace, allow_failure: false)
      ingresses = get_objects("ingress", namespace, allow_failure: allow_failure)
      ingresses['items']
    end

    def get_deployments(namespace = Config.namespace, allow_failure: false)
      deployments = get_objects("deploy", namespace, allow_failure: allow_failure)
      deployments['items']
    end

    def get_pods(namespace = Config.namespace, allow_failure: false)
      pods = get_objects("pod", namespace, allow_failure: allow_failure)
      pods['items']
    end

    def get_pods_by_label(label, namespace = Config.namespace, allow_failure: false)
      pods = get_objects_by_label("pod", label, namespace, allow_failure: allow_failure)
      pods['items']
    end

    def get_labels(obj_type, obj_name, namespace = Config.namespace, allow_failure: false)
      labels = get_object(obj_type, obj_name, namespace, allow_failure: allow_failure)
      labels['metadata']['labels']
    end

    def get_object(obj_type, obj_name, namespace = Config.namespace, allow_failure: false)
      YAML.load(run("-n #{namespace} get #{obj_type} #{obj_name} -o yaml", allow_failure: allow_failure))
    end

    def get_objects(obj_type, namespace = Config.namespace, allow_failure: false)
      YAML.load(run("-n #{namespace} get #{obj_type} -o yaml", allow_failure: allow_failure))
    end

    def get_objects_by_label(obj_type, obj_label, namespace = Config.namespace, allow_failure: false)
      YAML.load(run("-n #{namespace} get #{obj_type} -l #{obj_label} -o yaml", allow_failure: allow_failure))
    end

    def create_namespace(namespace = Config.namespace, allow_failure: false)
      run("create namespace #{namespace}", allow_failure: allow_failure)
    end

    def label_namespace(key, value, namespace = Config.namespace, allow_failure: false)
      run("label namespace #{namespace} #{key}=#{value}", allow_failure: allow_failure)
    end

    def deploy(name:, filename:, namespace: Config.namespace,
        issuer: Config.lets_encrypt_issuer, tls_enabled: Config.lets_encrypt_enabled, allow_failure: false)
      # create tmp manifest dir & prepare new random filename
      FileUtils.mkdir_p("#{Config.tmp_path}/manifests/")
      tmp_filename = "#{Config.tmp_path}/manifests/#{random_name("manifest")}.yml"

      # replace variables
      data = File.read(filename)
      data.gsub!('${NAME}', name)
      data.gsub!('${DOMAIN}', Config.domain)
      data.gsub!('${NAMESPACE}', namespace)
      data.gsub!('${ISSUER}', issuer)
      data.gsub!('${TLS_ENABLED}', tls_enabled.to_s)
      File.open(tmp_filename, "w") { |file| file.puts data }

      # deploy
      run("-n #{namespace} apply -f #{tmp_filename}", allow_failure: allow_failure)

      # cleanup
      FileUtils.rm_f(tmp_filename)
    end

    def delete(name:, filename:, namespace: Config.namespace,
        issuer: Config.lets_encrypt_issuer, tls_enabled: Config.lets_encrypt_enabled, allow_failure: false)
      # create tmp manifest dir & prepare new random filename
      FileUtils.mkdir_p("#{Config.tmp_path}/manifests/")
      tmp_filename = "#{Config.tmp_path}/manifests/#{random_name("manifest")}.yml"

      # replace variables
      data = File.read(filename)
      data.gsub!('${NAME}', name)
      data.gsub!('${DOMAIN}', Config.domain)
      data.gsub!('${NAMESPACE}', namespace)
      data.gsub!('${ISSUER}', issuer)
      data.gsub!('${TLS_ENABLED}', tls_enabled.to_s)
      File.open(tmp_filename, "w") { |file| file.puts data }

      # deploy
      run("-n #{namespace} delete -f #{tmp_filename}", allow_failure: allow_failure)

      # cleanup
      FileUtils.rm_f(tmp_filename)
    end

    def delete_deployment(deployment, namespace = Config.namespace, allow_failure: false)
      run("-n #{namespace} delete deploy #{deployment} --timeout=90s --grace-period=45 --wait=true", allow_failure: allow_failure)
    end

    def delete_namespace(namespace = Config.namespace, allow_failure: false)
      run("delete namespace #{namespace} --timeout=180s --grace-period=60 --wait=true", allow_failure: allow_failure)
    end

    def setup_env
      cleanup_env
      begin
        puts "- create namespace [#{Config.namespace}]"
        create_namespace(Config.namespace)
      rescue StandardError => e
        puts e.message
        puts e.backtrace.inspect
        puts "failed to create namespace [#{Config.namespace}]"
        abort
      end
      begin
        puts "- label namespace [#{Config.namespace}]"
        label_namespace("app", "kubernetes-testing", Config.namespace)
        label_namespace("namespace.kubernetes.io/name", Config.namespace, Config.namespace)
      rescue StandardError => e
        puts e.message
        puts e.backtrace.inspect
        puts "failed to label namespace [#{Config.namespace}]"
        abort
      end
    end

    def cleanup_env
      begin
        puts "- delete deployments in [#{Config.namespace}]"
        deployments = get_deployments(Config.namespace)
        deployments.each do |deployment|
          delete_deployment(deployment)
        end
      rescue
      end
      begin
        puts "- delete namespace [#{Config.namespace}]"
        delete_namespace(Config.namespace)
      rescue
      end
    end

    private
    attr_reader :command_runner
  end
end
