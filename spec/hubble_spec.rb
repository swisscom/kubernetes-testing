# frozen_string_literal: true

require 'capybara'
require 'capybara/rspec'
require 'selenium/webdriver'
require 'spec_helper'

if Config.hubble_enabled
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

  describe 'hubble', :hubble => true, type: :feature, js: true do
    before(:all) do
      @kubectl = KUBECTL.new()
    end

    it "can be https queried at [hubble.#{Config.domain}] and displays the OAuth2 login page" do
      wait_until(15,3) {
        response = http_get("https://hubble.#{Config.domain}/")
        expect(response).to_not be_nil
        expect(response.code).to eq(200)
        expect(response.headers[:content_type]).to include('text/html')
        expect(response.body).to include('<title>dex</title>')
        expect(response.body).to include('Log in to')
      }
    end

    context "when logging in" do
      before(:each) do
        visit "https://hubble.#{Config.domain}/"
        click_button 'Log in with Email'
        sleep(2)
        expect(find_field(name: 'login').value).to eq("")
        expect(find_field(name: 'password').value).to eq("")
        fill_in 'login', with: Config.admin_username
        fill_in 'password', with: Config.admin_password
        click_button 'Login'
        sleep(2)
      end

      it "displays nginx connections" do
        wait_until(33,5) {
          visit "https://hubble.#{Config.domain}/?namespace=ingress-nginx"
          sleep(5)
          expect(page).to have_content 'world'
          expect(page).to have_content 'ingress-nginx'
          expect(page).to have_content 'oauth2-proxy'
          expect(page).to have_content 'Destination Service'
          expect(page).to have_content 'Destination Port'
          expect(page).to have_content 'forwarded'
        }
      end
    end
  end
end
