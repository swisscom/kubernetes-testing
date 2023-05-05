# frozen_string_literal: true

require 'spec_helper'

if Config.deployment_enabled
  describe 'a kubernetes deployment', :deployment => true do
    before(:all) do
      @kubectl = KUBECTL.new()
      @name = Config.random_names ? random_name('deployment') : 'test-deployment'
    end

    context 'when deployed' do
      before(:all) do
        deploy = @kubectl.deploy(name: @name, filename: 'spec/assets/deployment.yml')
      end
      after(:all) do
        delete = @kubectl.delete(name: @name, filename: 'spec/assets/deployment.yml')

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

      it "has running pods" do
        @kubectl.wait_for_deployment(@name)

        wait_until(240,15) {
          pods = @kubectl.get_pods_by_label("app=#{@name}")
          expect(pods).to_not be_nil
          expect(pods.count).to be >= 2 # the deployment has 2 replicas defined

          pods.each{ |pod|
            expect(pod['metadata']['name']).to match(/#{@name}-[-a-z0-9]+/)
            expect(pod['status']['phase']).to eq('Running')
            expect(pod['status']['containerStatuses'].count).to be >= 1
            pod['status']['containerStatuses'].each{ |container|
              expect(container['started']).to eq(true)
            }
          }
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

              it "can be https queried via domain [#{Config.domain}]" do
                wait_until(120,15) {
                  response = https_get("https://#{@name}.#{Config.domain}/ingress")
                  expect(response).to_not be_nil
                  expect(response.code).to eq(200)
                  expect(response.headers[:content_type]).to include('text/html')
                  expect(response.body).to eq('Howdy, ingress!')
                }
              end
            end

          else # no lets-encrypt, let's just try with HTTP
            it "can be http queried via domain [#{Config.domain}]" do
              wait_until(120,15) {
                response = http_get("http://#{@name}.#{Config.domain}/ingress")
                expect(response).to_not be_nil
                expect(response.code).to eq(200)
                expect(response.headers[:content_type]).to include('text/html')
                expect(response.body).to eq('Howdy, ingress!')
              }
            end
          end
        end
      end
    end
  end
end
