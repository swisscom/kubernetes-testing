# frozen_string_literal: true

require 'capybara'
require 'capybara/rspec'
require 'selenium/webdriver'
require 'spec_helper'

if Config.dashboard_enabled
  Capybara.default_driver = :headless_chrome
  Capybara.javascript_driver = :headless_chrome
  Capybara.register_driver :headless_chrome do |app|
    browser_options = Selenium::WebDriver::Chrome::Options.new
    browser_options.add_argument('allow-insecure-localhost')  # ignore localhost TLS/SSL errors
    browser_options.add_argument('ignore-certificate-errors') # ignore certificate errors
    browser_options.add_argument('headless')
    browser_options.add_argument('disable-gpu')
    browser_options.add_argument('disable-dev-shm-usage')
    browser_options.add_argument('no-sandbox')
    Capybara::Selenium::Driver.new(app, browser: :chrome, options: browser_options)
  end

  describe 'dashboard', :dashboard => true, type: :feature, js: true do
    before(:all) do
      @kubectl = KUBECTL.new()
    end

    it "can be https queried at [dashboard.#{Config.domain}] and displays the login page" do
      response = https_get("https://dashboard.#{Config.domain}")
      expect(response.code).to eq(200)
      expect(response.headers[:content_type]).to include('text/html')
      expect(response.body).to include('The Kubernetes Authors', '<title>Kubernetes Dashboard</title>')
      expect(response.body).to include('<link rel="icon" type="image/png" href="assets/images/kubernetes-logo.png">', '<kd-root></kd-root>')
    end

    context "when doing the login process" do
      before(:all) do
        @token = @kubectl.run("-n kubernetes-dashboard create token kubernetes-dashboard")
        sleep 3
      end
      before(:each) do
        visit "https://dashboard.#{Config.domain}/"
        expect(find_field(id: 'token').value).to eq("")
        fill_in 'token', with: "#{@token}"
        sleep 1
        click_button(class: 'kd-login-button')
        # find('button[type="submit"]').click
        sleep 3 # unfortunately we have to wait here to make sure the login/javascript did their work
      end

      it "is logged-in" do
        visit "https://dashboard.#{Config.domain}/"
        wait_until(15,3) {
          expect(page.html).to include('<title>Kubernetes Dashboard</title>')
          expect(page).to have_content 'Workloads'
          expect(page).to have_content 'Daemon Sets'
          expect(page).to have_content 'Deployments'
          expect(page).to have_content 'Replica Sets'
          expect(page).to have_content 'Replication Controllers'
          expect(page).to have_content 'Stateful Sets'
          expect(page).to have_content(/There is nothing to display here|Workload Status/)
        }
      end

      it "displays nodes" do
        visit "https://dashboard.#{Config.domain}/#/node"
        wait_until(15,3) {
          expect(page).to have_content 'CPU requests'
          expect(page).to have_content 'CPU limits'
          expect(page).to have_content 'CPU capacity'
        }
      end

      it "displays deployments" do
        visit "https://dashboard.#{Config.domain}/#/deployment?namespace=kubernetes-dashboard"
        wait_until(15,3) {
          expect(page).to have_content 'kubernetes-dashboard'
          expect(page).to have_content 'kubernetesui/dashboard'
          expect(page).to have_content 'app.kubernetes.io/component: kubernetes-dashboard'
          expect(page).to have_content 'app.kubernetes.io/instance: kubernetes-dashboard'
        }
      end

      if Config.grafana_enabled
        it "displays replica sets" do
          visit "https://dashboard.#{Config.domain}/#/replicaset?namespace=grafana"
          wait_until(15,3) {
            expect(page).to have_content 'grafana/grafana'
            expect(page).to have_content 'app.kubernetes.io/instance: grafana'
            expect(page).to have_content 'app.kubernetes.io/name: grafana'
          }
        end
      end

      if Config.loki_enabled
        it "displays stateful sets" do
          visit "https://dashboard.#{Config.domain}/#/statefulset?namespace=loki"
          wait_until(15,3) {
            expect(page).to have_content 'loki'
            expect(page).to have_content 'app.kubernetes.io/instance: loki'
            expect(page).to have_content 'grafana/loki'
          }
        end
      end

      if Config.prometheus_enabled
        it "displays services" do
          visit "https://dashboard.#{Config.domain}/#/service?namespace=prometheus"
          wait_until(15,3) {
            expect(page).to have_content 'Internal Endpoints'
            expect(page).to have_content 'prometheus-server.prometheus:'
            expect(page).to have_content 'prometheus-alertmanager.prometheus:'
            expect(page).to have_content 'prometheus-node-exporter.prometheus:'
            expect(page).to have_content 'prometheus-kube-state-metrics.prometheus:'
            expect(page).to have_content 'app: prometheus'
            expect(page).to have_content 'ClusterIP'
          }
        end
      end

      if Config.lets_encrypt_enabled
        it "displays clusterroles" do
          visit "https://dashboard.#{Config.domain}/#/clusterrole/cert-manager-controller-issuers?namespace=cert-manager"
          wait_until(15,3) {
            expect(page).to have_content 'app: cert-manager'
            expect(page).to have_content 'app.kubernetes.io/component: controller'
            expect(page).to have_content 'app.kubernetes.io/instance: cert-manager'
            expect(page).to have_content 'issuers/status'
            expect(page).to have_content 'cert-manager.io'
          }
        end
      end
    end
  end
end
