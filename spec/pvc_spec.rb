# frozen_string_literal: true

require 'spec_helper'

if Config.storage_enabled
  describe 'a kubernetes deployment with a persistent volume', :storage => true do
    before(:all) do
      @kubectl = KUBECTL.new()
      @name = Config.random_names ? random_name('deployment') : 'test-deployment'
    end

    context 'when deployed using the default storage class' do
      before(:all) do
        deploy = @kubectl.deploy(name: @name, filename: 'spec/assets/deployment-with-pvc.yml')
      end
      after(:all) do
        delete = @kubectl.delete(name: @name, filename: 'spec/assets/deployment-with-pvc.yml')

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

        wait_until(240,15) {
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

      it "has a bound persistent volume" do
        @kubectl.wait_for_deployment(@name)

        wait_until(240,15) {
          pvc = @kubectl.get_object("pvc", @name)
          expect(pvc).to_not be_nil
          expect(pvc['metadata']['name']).to eq(@name)
          expect(pvc['metadata']['annotations']['pv.kubernetes.io/bind-completed']).to eq("yes")
          expect(pvc['metadata']['annotations']['pv.kubernetes.io/bound-by-controller']).to eq("yes")
          expect(pvc['spec']['storageClassName']).to_not be_nil
          expect(pvc['spec']['volumeName']).to_not be_nil
          expect(pvc['status']['phase']).to eq("Bound")

          pv_name = pvc['spec']['volumeName']
          pv = @kubectl.get_object("pv", pv_name)
          expect(pv).to_not be_nil
          expect(pv['metadata']['name']).to eq(pv_name)
          expect(pv['metadata']['annotations']['pv.kubernetes.io/provisioned-by']).to eq(pvc['metadata']['annotations']['volume.kubernetes.io/storage-provisioner'])
          expect(pv['spec']['storageClassName']).to eq(pvc['spec']['storageClassName'])
          expect(pv['spec']['claimRef']['name']).to eq(@name)
          expect(pv['spec']['csi']['driver']).to eq(pvc['metadata']['annotations']['volume.kubernetes.io/storage-provisioner'])
          expect(pv['spec']['csi']['volumeHandle']).to eq(pv_name)
          expect(pv['status']['phase']).to eq("Bound")
        }
      end
    end
  end
end
