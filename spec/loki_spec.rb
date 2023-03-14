# frozen_string_literal: true

require 'date'
require 'json'
require 'spec_helper'

if Config.loki_enabled
  describe 'loki', :loki => true do
    before(:all) do
      @kubectl = KUBECTL.new()
      @name = Config.random_names ? random_name('loki') : 'test-loki'
    end

    it "is running" do
      wait_until(60,10) {
        pods = @kubectl.get_pods('loki')
        expect(pods).to_not be_nil

        pods.map! { |pod| pod['metadata']['name'] }
        expect(pods).to include('loki-0')
      }

      @kubectl.wait_for_statefulset('loki', "240s", 'loki')
      wait_until(120,15) {
        pods = @kubectl.get_pods_by_label("app.kubernetes.io/name=loki", 'loki')
        expect(pods).to_not be_nil
        expect(pods.count).to be >= 1

        pods.each{ |pod|
          expect(pod['metadata']['name']).to match(/loki-[-a-z0-9]+/)
          expect(pod['status']['phase']).to eq('Running')
          expect(pod['status']['containerStatuses'].count).to be >= 1
          pod['status']['containerStatuses'].each{ |container|
            expect(container['started']).to eq(true)
          }
        }
      }
    end

    context "when port-forwarding from localhost to [service/loki]" do
      before(:each) do
        @forward_pid = @kubectl.port_forward('service/loki',9091,3100,'loki')
        sleep 5
      end
      after(:each) do
        @kubectl.stop_pid(@forward_pid)
      end

      it "is ready" do
        wait_until(60,5) {
          response = http_get("http://localhost:9091/ready")
          expect(response).to_not be_nil
          expect(response.code).to eq(200)
          expect(response.headers[:content_type]).to include('text/plain')
          expect(response.body).to include('ready')
        }
      end

      it "has logs available for loki app" do
        wait_until(60,5) {
          response = http_get("http://localhost:9091/loki/api/v1/query?query=%7Bapp%3D%22loki%22%7D")
          expect(response).to_not be_nil
          expect(response.code).to eq(200)
          expect(response.headers[:content_type]).to include('application/json')
          expect(response.body).to include('{"status":"success"')
        }
      end

      context "when a new deployment is created" do
        before(:all) do
          deploy = @kubectl.deploy(name: @name, filename: 'spec/assets/deployment.yml')
        end
        after(:all) do
          delete = @kubectl.delete(name: @name, filename: 'spec/assets/deployment.yml')

          deployments = @kubectl.get_deployments
          expect(deployments).to_not include(@name)
        end

        it "has log available for the new deployment" do
          wait_until(240,15) {
            response = http_get("http://localhost:9091/loki/api/v1/query?query=%7Bjob%3D%22kubernetes-testing%2F#{@name}%22%7D")
            expect(response).to_not be_nil
            expect(response.code).to eq(200)
            expect(response.headers[:content_type]).to include('application/json')
            expect(response.body).to include('Listening on http://0.0.0.0:8080')
          }
        end
      end
    end
  end
end
