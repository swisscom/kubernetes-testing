# frozen_string_literal: true

require 'spec_helper'

if Config.prometheus_enabled
  describe 'prometheus', :prometheus => true do
    before(:all) do
      @kubectl = KUBECTL.new()
      @name = Config.random_names ? random_name('prometheus') : 'test-prometheus'
    end

    # k -n prometheus port-forward service/prometheus-server 9999:80
    # curl 'http://localhost:9999/api/v1/query?query=up&time=2015-07-01T20:10:51.781Z'
    # curl 'http://localhost:9999/api/v1/query_range?query=up&start=2022-10-24T14:00:00.000Z&end=2022-10-24T17:22:00.000Z&step=15s'
    # curl -g 'http://localhost:9999/api/v1/series?' --data-urlencode 'match[]=up{job="prometheus"}' --data-urlencode 'start=2022-10-24T15:00:00.000Z'

    it "is running" do
      wait_until(60,10) {
        deployments = @kubectl.get_deployments('prometheus')
        expect(deployments).to_not be_nil

        deployments.map! { |deployment| deployment['metadata']['name'] }
        expect(deployments).to include('prometheus-server')
      }

      @kubectl.wait_for_deployment('prometheus-server', "120s", 'prometheus')
      wait_until(120,15) {
        pods = @kubectl.get_pods_by_label("app=prometheus,component=server", 'prometheus')
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
      @kubectl.wait_for_daemonset('prometheus-node-exporter', "120s", 'prometheus')
      wait_until(120,15) {
        pods = @kubectl.get_pods_by_label('app=prometheus,component=node-exporter', 'prometheus')
        expect(pods).to_not be_nil
        expect(pods.count).to be >= 1

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

    context "when port-forwarding from localhost to [service/prometheus-server]" do
      before(:all) do
        @forward_pid = @kubectl.port_forward("service/prometheus-server",9999,80)
      end
      after(:all) do
        @kubectl.stop_pid(@forward_pid)
        #@kubectl.stop_forward("service/prometheus-server",9999,80)
      end
    end
  end
end
