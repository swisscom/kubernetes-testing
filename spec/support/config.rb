# frozen_string_literal: true

require 'yaml'

module Config
  @@config = YAML.load_file('config.yml')

  def self.tmp_path
    return '/tmp' if @@config['tmp_path'] == nil
    return '/tmp' if @@config['tmp_path'].to_s.empty?
    "#{@@config['tmp_path']}"
  end

  def self.namespace
    return 'kubernetes-testing' if @@config['namespace'] == nil
    return 'kubernetes-testing' if @@config['namespace'].to_s.empty?
    @@config['namespace']
  end

  def self.domain
    @@config['domain']
  end

  def self.admin_username
    return "admin" if @@config['admin'] == nil
    return "admin" if @@config['admin']['username'] == nil
    return "admin" if @@config['admin']['username'].to_s.empty?
    @@config['admin']['username']
  end

  def self.admin_password
    return "password" if @@config['admin'] == nil
    return "password" if @@config['admin']['password'] == nil
    return "password" if @@config['admin']['password'].to_s.empty?
    @@config['admin']['password']
  end

  def self.random_names
    return false if @@config['random_names'] == nil
    @@config['random_names']
  end

  def self.deployment_enabled
    return true if @@config['deployment'] == nil
    return true if @@config['deployment']['enabled'] == nil
    return true if @@config['deployment']['enabled'].to_s.empty?
    @@config['deployment']['enabled']
  end

  def self.dashboard_enabled
    return true if @@config['dashboard'] == nil
    return true if @@config['dashboard']['enabled'] == nil
    return true if @@config['dashboard']['enabled'].to_s.empty?
    @@config['dashboard']['enabled']
  end

  def self.grafana_enabled
    return true if @@config['grafana'] == nil
    return true if @@config['grafana']['enabled'] == nil
    return true if @@config['grafana']['enabled'].to_s.empty?
    @@config['grafana']['enabled']
  end

  def self.hubble_enabled
    return true if @@config['hubble'] == nil
    return true if @@config['hubble']['enabled'] == nil
    return true if @@config['hubble']['enabled'].to_s.empty?
    @@config['hubble']['enabled']
  end

  def self.ingress_enabled
    return true if @@config['ingress'] == nil
    return true if @@config['ingress']['enabled'] == nil
    return true if @@config['ingress']['enabled'].to_s.empty?
    @@config['ingress']['enabled']
  end

  def self.lets_encrypt_enabled
    return true if @@config['lets_encrypt'] == nil
    return true if @@config['lets_encrypt']['enabled'] == nil
    return true if @@config['lets_encrypt']['enabled'].to_s.empty?
    @@config['lets_encrypt']['enabled']
  end

  def self.prometheus_enabled
    return true if @@config['prometheus'] == nil
    return true if @@config['prometheus']['enabled'] == nil
    return true if @@config['prometheus']['enabled'].to_s.empty?
    @@config['prometheus']['enabled']
  end

  def self.loki_enabled
    return true if @@config['loki'] == nil
    return true if @@config['loki']['enabled'] == nil
    return true if @@config['loki']['enabled'].to_s.empty?
    @@config['loki']['enabled']
  end

  def self.longhorn_enabled
    return true if @@config['longhorn'] == nil
    return true if @@config['longhorn']['enabled'] == nil
    return true if @@config['longhorn']['enabled'].to_s.empty?
    @@config['longhorn']['enabled']
  end

  def self.vcloud_csi_enabled
    return true if @@config['vcloud_csi'] == nil
    return true if @@config['vcloud_csi']['enabled'] == nil
    return true if @@config['vcloud_csi']['enabled'].to_s.empty?
    @@config['vcloud_csi']['enabled']
  end

  def self.storage_enabled
    return true if @@config['storage'] == nil
    return true if @@config['storage']['enabled'] == nil
    return true if @@config['storage']['enabled'].to_s.empty?
    @@config['storage']['enabled']
  end

  def self.lets_encrypt_issuer
    return "lets-encrypt" if @@config['lets_encrypt'] == nil
    return "lets-encrypt" if @@config['lets_encrypt']['issuer'] == nil
    return "lets-encrypt" if @@config['lets_encrypt']['issuer'].to_s.empty?
    @@config['lets_encrypt']['issuer']
  end

  def self.lets_encrypt_server
    return "https://acme-v02.api.letsencrypt.org/directory" if @@config['lets_encrypt'] == nil
    return "https://acme-v02.api.letsencrypt.org/directory" if @@config['lets_encrypt']['server'] == nil
    return "https://acme-v02.api.letsencrypt.org/directory" if @@config['lets_encrypt']['server'].to_s.empty?
    @@config['lets_encrypt']['server']
  end

  def self.lets_encrypt_staging
    lets_encrypt_server == "https://acme-staging-v02.api.letsencrypt.org/directory"
  end

end
