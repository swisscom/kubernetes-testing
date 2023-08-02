# frozen_string_literal: true

require 'date'
require 'json'
require 'spec_helper'

if Config.prometheus_enabled
  describe 'prometheus', :prometheus => true do
    before(:all) do
      @kubectl = KUBECTL.new()
      @name = Config.random_names ? random_name('prometheus') : 'test-prometheus'
    end

    it "is running" do
      wait_until(60,10) {
        deployments = @kubectl.get_deployments('prometheus')
        expect(deployments).to_not be_nil

        deployments.map! { |deployment| deployment['metadata']['name'] }
        expect(deployments).to include('prometheus-server')
      }

      @kubectl.wait_for_deployment('prometheus-server', "240s", 'prometheus')
      wait_until(120,15) {
        pods = @kubectl.get_pods_by_label("app.kubernetes.io/name=prometheus", 'prometheus')
        expect(pods).to_not be_nil
        expect(pods.count).to be >= 1

        pods.each{ |pod|
          expect(pod['metadata']['name']).to match(/prometheus-server-[-a-z0-9]+/)
          expect(pod['status']['phase']).to eq('Running')
          expect(pod['status']['containerStatuses'].count).to be >= 1
          pod['status']['containerStatuses'].each{ |container|
            expect(container['started']).to eq(true)
          }
        }
      }
    end

    it "has running node-exporters" do
      @kubectl.wait_for_daemonset('prometheus-prometheus-node-exporter', "240s", 'prometheus')
      wait_until(120,15) {
        pods = @kubectl.get_pods_by_label('app.kubernetes.io/name=prometheus-node-exporter', 'prometheus')
        expect(pods).to_not be_nil
        expect(pods.count).to be >= 1

        nodes = @kubectl.get_nodes
        expect(nodes).to_not be_nil
        expect(nodes.count).to be >= 1
        expect(pods.count).to eq nodes.count

        pods.each{ |pod|
          expect(pod['metadata']['name']).to match(/prometheus-node-exporter-[-a-z0-9]+/)
          expect(pod['status']['phase']).to eq('Running')
          expect(pod['status']['containerStatuses'].count).to be >= 1
          pod['status']['containerStatuses'].each{ |container|
            expect(container['started']).to eq(true)
          }
        }
      }
    end

    it "can be https queried at [prometheus.#{Config.domain}] and displays the OAuth2 login page" do
      wait_until(15,3) {
        visit "https://prometheus.#{Config.domain}/"
        sleep(3)
        expect(page).to have_content 'Log in to Your Account'
        expect(page).to have_content 'Email Address'
      }
    end

    context "when port-forwarding from localhost to [service/prometheus-server]" do
      before(:each) do
        @forward_pid = @kubectl.port_forward('service/prometheus-server',9090,80,'prometheus')
        sleep 5
      end
      after(:each) do
        @kubectl.stop_pid(@forward_pid)
        #@kubectl.stop_forward('service/prometheus-server',9090,80,'prometheus')
      end

      it "has metrics available" do
        # 1.0 = one day
        # 1.0/24 = 1 hour
        # 1.0/(24*60) = 1 minute
        # 1.0/(24*60*60) = 1 second
        d = DateTime.now.new_offset(0) # UTC
        start_timestamp = (d.new_offset(0) - (5.0/(24*60))).strftime("%Y-%m-%dT%H:%M:00.000Z") # minus 5min
        end_timestamp = (d.new_offset(0) + (10.0/(24*60))).strftime("%Y-%m-%dT%H:%M:00.000Z") # plus 10min

        response = http_get("http://localhost:9090/api/v1/series?match[]=up{job=\"prometheus\"}&start=#{start_timestamp}")
        expect(response).to_not be_nil
        expect(response.code).to eq(200)
        expect(response.headers[:content_type]).to include('application/json')
        expect(response.body).to eq('{"status":"success","data":[{"__name__":"up","instance":"localhost:9090","job":"prometheus"}]}')

        response = http_get("http://localhost:9090/api/v1/query_range?query=up{app_kubernetes_io_name=\"prometheus-node-exporter\"}&start=#{start_timestamp}&end=#{end_timestamp}&step=15s")
        expect(response).to_not be_nil
        expect(response.code).to eq(200)
        expect(response.headers[:content_type]).to include('application/json')
        expect(response.body).to include('{"status":"success","data":{"resultType":"matrix","result":[{"metric":{"__name__":')
        data = JSON.parse(response.body)
        expect(data).to_not be_nil
        expect(data['status']).to eq("success")
        expect(data['data']['result']).to_not be_nil
        expect(data['data']['result'].count).to be >= 1
        expect(data['data']['result'][0]['metric']).to_not be_nil
        expect(data['data']['result'][0]['metric']['job']).to_not be_nil
        expect(data['data']['result'][0]['metric']['job']).to eq('kubernetes-service-endpoints')
        expect(data['data']['result'][0]['values']).to_not be_nil
        expect(data['data']['result'][0]['values'].count).to be >= 10

        if Config.lets_encrypt_enabled
          response = http_get("http://localhost:9090/api/v1/query_range?query=up{app='cert-manager'}&start=#{start_timestamp}&end=#{end_timestamp}&step=15s")
          expect(response).to_not be_nil
          expect(response.code).to eq(200)
          expect(response.headers[:content_type]).to include('application/json')
          expect(response.body).to include('{"status":"success","data":{"resultType":"matrix","result":[{"metric":{"__name__":')
          data = JSON.parse(response.body)
          expect(data).to_not be_nil
          expect(data['status']).to eq("success")
          expect(data['data']['result']).to_not be_nil
          expect(data['data']['result'].count).to be >= 1
          expect(data['data']['result'][0]['metric']).to_not be_nil
          expect(data['data']['result'][0]['metric']['job']).to_not be_nil
          expect(data['data']['result'][0]['metric']['job']).to eq('kubernetes-pods')
          expect(data['data']['result'][0]['values']).to_not be_nil
          expect(data['data']['result'][0]['values'].count).to be >= 5
        end
      end
    end
  end
end
