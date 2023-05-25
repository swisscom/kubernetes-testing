# frozen_string_literal: true

require 'capybara'
require 'capybara/rspec'
require 'selenium/webdriver'
require 'spec_helper'
require 'base64'

if Config.grafana_enabled
  Capybara.default_driver = :headless_chrome
  Capybara.javascript_driver = :headless_chrome
  Capybara.register_driver :headless_chrome do |app|
    browser_options = Selenium::WebDriver::Chrome::Options.new
    browser_options.add_argument('allow-insecure-localhost')  # Ignore TLS/SSL errors on localhost
    browser_options.add_argument('ignore-certificate-errors') # Ignore certificate related errors
    browser_options.add_argument('headless')
    browser_options.add_argument('disable-gpu')
    browser_options.add_argument('disable-dev-shm-usage')
    browser_options.add_argument('no-sandbox')
    Capybara::Selenium::Driver.new(app, browser: :chrome, options: browser_options)
  end

  describe 'grafana', :grafana => true, type: :feature, js: true do
    before(:all) do
      @kubectl = KUBECTL.new()
      @secret = Base64.decode64(@kubectl.run("-n grafana get secret grafana -o jsonpath='{.data.admin-password}'"))
      # @secret = `kubectl -n grafana get secret grafana -o jsonpath='{.data.admin-password}' | base64 -d; echo`
    end

    it "can be https queried at [grafana.#{Config.domain}]" do
      response = https_get("https://grafana.#{Config.domain}")
      expect(response.code).to eq(200)
      expect(response.headers[:content_type]).to include('text/html')
      expect(response.body).to include('<title>Grafana</title>')
      expect(response.body).to include('<div class="preloader__text">Loading Grafana</div>','checkBrowserCompatibility')
    end

      it "displays the login page" do
        visit "https://grafana.#{Config.domain}/"
        wait_until(15,3) {
          expect(page).to have_content 'Welcome to Grafana'
          expect(page).to have_content 'Forgot your password?'
        }
      end

    context "when logging in" do
      before(:each) do
        visit "https://grafana.#{Config.domain}/"
        expect(find_field(name: 'user').value).to eq("")
        expect(find_field(name: 'password').value).to eq("")
        fill_in 'user', with: "admin"
        fill_in 'password', with: @secret
        click_button 'Log in'
        sleep(3)
      end

      it "is signed-in" do
        wait_until(17,3) {
          visit "https://grafana.#{Config.domain}/"
          sleep(3)
          expect(page).to have_content 'Welcome to Grafana'
          expect(page).to have_content 'Documentation'
          expect(page).to have_content 'Tutorials'
          expect(page).to_not have_content 'Forgot your password?'
        }
      end

      it "displays nginx dashboard" do
        #visit "https://grafana.#{Config.domain}/d/nginx/nginx-ingress-controller?orgId=1&refresh=5m&editview=dashboard_json"
        wait_until(33,5) {
          visit "https://grafana.#{Config.domain}/d/nginx/nginx-ingress-controller?orgId=1&refresh=5m"
          sleep(5)
          expect(page).to have_content 'NGINX Ingress Controller'
          expect(page).to have_content 'Controller Request Volume'
          expect(page).to have_content 'Average Memory Usage'
        }
      end

      it "displays metrics explorer" do
        wait_until(33,5) {
          visit "https://grafana.#{Config.domain}/explore?orgId=1&left=%7B%22datasource%22:%22PBFA97CFB590B2093%22,%22queries%22:%5B%7B%22refId%22:%22A%22,%22datasource%22:%7B%22type%22:%22prometheus%22,%22uid%22:%22PBFA97CFB590B2093%22%7D,%22editorMode%22:%22builder%22,%22expr%22:%22go_goroutines%7Bapp%3D%5C%22operating-system-manager%5C%22%7D%22,%22legendFormat%22:%22__auto%22,%22range%22:true,%22instant%22:true%7D%5D,%22range%22:%7B%22from%22:%22now-1h%22,%22to%22:%22now%22%7D%7D"
          sleep(5)
          expect(page).to have_content 'go_goroutines{'
          expect(page).to have_content 'app="operating-system-manager"'
          expect(page).to have_content 'namespace="kube-system"'
          expect(page).to have_content 'go_goroutines{app="operating-system-manager"}'
        }
      end
    end
  end
end
