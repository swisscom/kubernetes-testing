# frozen_string_literal: true

require 'capybara'
require 'capybara/rspec'
require 'selenium/webdriver'
require 'spec_helper'

if Config.longhorn_enabled
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

  describe 'a kubernetes deployment with a persistent volume', :longhorn => true, type: :feature, js: true do
    before(:all) do
      @kubectl = KUBECTL.new()
      @name = Config.random_names ? random_name('deployment') : 'test-deployment'
    end

    it "can be https queried at [longhorn.#{Config.domain}] and displays the OAuth2 login page" do
      wait_until(15,3) {
        response = http_get("https://longhorn.#{Config.domain}/")
        expect(response).to_not be_nil
        expect(response.code).to eq(200)
        expect(response.headers[:content_type]).to include('text/html')
        expect(response.body).to include('<title>dex</title>')
        expect(response.body).to include('Log in to')
      }
    end

    context "when logging in to [longhorn.#{Config.domain}]" do
      before(:each) do
        visit "https://longhorn.#{Config.domain}/"
        click_button 'Log in with Email'
        sleep(2)
        expect(find_field(name: 'login').value).to eq("")
        expect(find_field(name: 'password').value).to eq("")
        fill_in 'login', with: Config.admin_username
        fill_in 'password', with: Config.admin_password
        click_button 'Login'
        sleep(2)
      end

      it "is signed-in" do
        wait_until(17,3) {
          visit "https://longhorn.#{Config.domain}/#/dashboard"
          sleep(3)
          expect(page).to have_content 'Dashboard'
          expect(page).to have_content 'Healthy'
          expect(page).to have_content 'Degraded'
          expect(page).to have_content 'Schedulable'
          expect(page).to have_content 'Reserved'
          expect(page).to have_content 'Event Log'
        }
      end

      it "displays nodes" do
        wait_until(17,3) {
          visit "https://longhorn.#{Config.domain}/#/node"
          sleep(3)
          expect(page).to have_content 'Schedulable'
          expect(page).to have_content 'Readiness'
          expect(page).to have_content 'Allocated'
          expect(page).to have_content 'worker-pool'
        }
      end
    end

    context 'when deployed using [longhorn] storage class' do
      before(:all) do
        deploy = @kubectl.deploy(name: @name, filename: 'spec/assets/deployment-with-pvc.yml', storage_class: 'longhorn')
      end
      after(:all) do
        delete = @kubectl.delete(name: @name, filename: 'spec/assets/deployment-with-pvc.yml', storage_class: 'longhorn')

        deployments = @kubectl.get_deployments
        expect(deployments).to_not include(@name)
      end

      it "exists" do
        wait_until(60,10) {
          deployments = @kubectl.get_deployments
          expect(deployments).to_not be_nil

          deployments.map! { |deployment| deployment['metadata']['name'] }
          expect(deployments).to include(@name)
        }
      end

      it "has running pods with a volume mount" do
        @kubectl.wait_for_deployment(@name)

        wait_until(366,15) {
          pods = @kubectl.get_pods_by_label("app=#{@name}")
          expect(pods).to_not be_nil
          expect(pods.count).to eq(1) # the deployment has 1 replica defined

          pods.each{ |pod|
            expect(pod['metadata']['name']).to match(/#{@name}-[-a-z0-9]+/)
            expect(pod['status']['phase']).to eq('Running')
            expect(pod['status']['containerStatuses'].count).to eq(1)
            pod['status']['containerStatuses'].each{ |container|
              expect(container['started']).to eq(true)
            }
          }
        }

        wait_until(60,15) {
          pods = @kubectl.get_pods_by_label("app=#{@name}")
          expect(pods).to_not be_nil

          pods.each{ |pod|
            expect(pod['spec']['containers'].count).to eq(1)
            expect(pod['spec']['containers'][0]['volumeMounts'].count).to be >= 1
            mount_paths = pod['spec']['containers'][0]['volumeMounts'].map { |it| it['mountPath'] }
            expect(mount_paths).to include('/var/www')
          }
        }
      end

      it "has a bound persistent volume claim" do
        @kubectl.wait_for_deployment(@name)

        wait_until(240,15) {
          pvc = @kubectl.get_object("pvc", @name)
          expect(pvc).to_not be_nil
          expect(pvc['metadata']['name']).to eq(@name)
          expect(pvc['metadata']['annotations']['pv.kubernetes.io/bind-completed']).to eq("yes")
          expect(pvc['metadata']['annotations']['pv.kubernetes.io/bound-by-controller']).to eq("yes")
          expect(pvc['metadata']['annotations']['volume.kubernetes.io/storage-provisioner']).to eq("driver.longhorn.io")
          expect(pvc['spec']['storageClassName']).to eq("longhorn")
          expect(pvc['status']['phase']).to eq("Bound")
        }
      end

      it "has a persistent volume" do
        @kubectl.wait_for_deployment(@name)

        wait_until(240,15) {
          pvc = @kubectl.get_object("pvc", @name)
          expect(pvc).to_not be_nil
          expect(pvc['metadata']['name']).to eq(@name)

          pv_name = pvc['spec']['volumeName']

          pv = @kubectl.get_object("pv", pv_name)
          expect(pv).to_not be_nil
          expect(pv['metadata']['name']).to eq(pv_name)
          expect(pv['metadata']['annotations']['pv.kubernetes.io/provisioned-by']).to eq("driver.longhorn.io")
          expect(pv['spec']['storageClassName']).to eq("longhorn")
          expect(pv['spec']['claimRef']['name']).to eq(@name)
          expect(pv['spec']['csi']['driver']).to eq("driver.longhorn.io")
          expect(pv['spec']['csi']['volumeHandle']).to eq(pv_name)
          expect(pv['status']['phase']).to eq("Bound")
        }
      end

      if Config.ingress_enabled
        context 'with an Ingress' do
          before(:all) do
            @ingress_filename = 'spec/assets/ingress.yml'
            @ingress_filename = 'spec/assets/ingress-http.yml' unless Config.lets_encrypt_enabled
            deploy = @kubectl.deploy(name: @name, filename: @ingress_filename)
          end
          after(:all) do
            delete = @kubectl.delete(name: @name, filename: @ingress_filename)

            ingresses = @kubectl.get_ingresses
            expect(ingresses).to_not include(@name)
          end

          if Config.lets_encrypt_enabled
            context 'with a valid certificate' do
              before(:all) do
                wait_until(240,15) {
                  certificates = @kubectl.get_certificates
                  expect(certificates).to_not be_nil
                  expect(certificates.count).to be >= 1

                  expect(certificates.any?{ |c| c['metadata']['name'] == "#{@name}-tls" }).to eq(true)
                  certificate = certificates.select{ |c| c['metadata']['name'] == "#{@name}-tls" }.first

                  expect(certificate['spec']).to_not be_nil
                  expect(certificate['spec']['dnsNames']).to_not be_nil
                  expect(certificate['spec']['dnsNames'].count).to eq(1)
                  expect(certificate['spec']['dnsNames'][0]).to eq("#{@name}.#{Config.domain}")

                  expect(certificate['status']).to_not be_nil
                  expect(certificate['status']['conditions']).to_not be_nil
                  expect(certificate['status']['conditions'].count).to eq(1)
                  expect(certificate['status']['conditions'][0]['type']).to eq('Ready')
                  expect(certificate['status']['conditions'][0]['status']).to eq('True')

                  expect(Time.parse(certificate['status']['notAfter']) > (Time.now + 60*60*24*5)).to eq(true)
                  expect(Time.parse(certificate['status']['notAfter']) < (Time.now + 60*60*24*180)).to eq(true)
                  expect(Time.parse(certificate['status']['notBefore']) > (Time.now - 60*60*24*1)).to eq(true)
                }
              end

              it "can validate the app config via https and domain [#{Config.domain}]" do
                wait_until(30,5) {
                  response = https_get("https://#{@name}.#{Config.domain}/config")
                  expect(response).to_not be_nil
                  expect(response.code).to eq(200)
                  expect(response.headers[:content_type]).to include('application/x-yaml')
                  expect(response.body).to include('fileServerFolder: /var/www')
                }
              end

              context 'with files created on the persistent volume' do
                before(:all) do
                  response = https_patch("https://#{@name}.#{Config.domain}/greet/howdy", "")
                  expect(response.code).to eq(202)
                end

                it "can serve files from the persistent volume" do
                  wait_until(30,5) {
                    for file_suffix in 0..10 do
                      response = https_get("https://#{@name}.#{Config.domain}/static/greet-#{file_suffix}.txt")
                      expect(response).to_not be_nil
                      expect(response.code).to eq(200)
                      expect(response.headers[:content_type]).to include('text/plain')
                      expect(response.body).to include('Howdy')
                    end
                  }
                end
              end
            end

          else # no lets-encrypt, let's just try with HTTP

            it "can validate the app config via http and domain [#{Config.domain}]" do
              wait_until(30,5) {
                response = http_get("http://#{@name}.#{Config.domain}/config")
                expect(response).to_not be_nil
                expect(response.code).to eq(200)
                expect(response.headers[:content_type]).to include('application/x-yaml')
                expect(response.body).to include('fileServerFolder: /var/www')
              }
            end

            context 'with files created on the persistent volume' do
              before(:all) do
                response = http_patch("http://#{@name}.#{Config.domain}/greet/howdy", "")
                expect(response.code).to eq(202)
              end

              it "can serve files from the persistent volume" do
                wait_until(30,5) {
                  for file_suffix in 0..10 do
                    response = http_get("http://#{@name}.#{Config.domain}/static/greet-#{file_suffix}.txt")
                    expect(response).to_not be_nil
                    expect(response.code).to eq(200)
                    expect(response.headers[:content_type]).to include('text/plain')
                    expect(response.body).to include('Howdy')
                  end
                }
              end
            end
          end
        end
      end
    end
  end
end
