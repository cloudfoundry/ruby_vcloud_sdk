require "spec_helper"
require "nokogiri/diff"

describe VCloudSdk::VM do

  let(:logger) { VCloudSdk::Test.logger }
  let(:url) { ENV['VCLOUD_URL'] || VCloudSdk::Test::DefaultSetting::VCLOUD_URL }
  let(:username) { ENV['VCLOUD_USERNAME'] || VCloudSdk::Test::DefaultSetting::VCLOUD_USERNAME }
  let(:password) { ENV['VCLOUD_PWD'] || VCloudSdk::Test::DefaultSetting::VCLOUD_PWD }
  let!(:client) { VCloudSdk::Client.new(url, username, password, {}, logger) }
  let(:vdc_name) { ENV['VDC_NAME'] || VCloudSdk::Test::DefaultSetting::VDC_NAME }
  let(:vapp_name) { ENV['VAPP_NAME'] ||  VCloudSdk::Test::DefaultSetting::VAPP_NAME }
  let(:catalog_name) { ENV['CATALOG_NAME'] || VCloudSdk::Test::DefaultSetting::CATALOG_NAME }
  let(:vapp_template_name) { VCloudSdk::Test::DefaultSetting::EXISTING_VAPP_TEMPLATE_NAME }
  let(:media_name) { "mini1" }
  let(:vapp_name) { SecureRandom.uuid }
  let!(:vdc) { client.find_vdc_by_name(vdc_name) }

  after(:each) do
    VCloudSdk::Test::safe_remove_vapp(vdc, vapp_name)
  end

  describe "disk manipulation" do
    it "attaches and detaches the disk successfully" do
      begin
        catalog = client.find_catalog_by_name(catalog_name)
        vapp = catalog.instantiate_vapp_template(vapp_template_name,
                                                 vdc_name,
                                                 vapp_name)
        vm = vapp.vms.first
        vm.independent_disks.should eql []

        new_disk_name = "test2"
        new_disk = vdc.create_disk(new_disk_name, 1024, vm)
        new_disk.name.should eql new_disk_name
        new_disk.should_not be_attached

        vm.attach_disk(new_disk)
        new_disk.should be_attached
        new_disk.vm.href.should eql vm.href
        vm.independent_disks.size.should eql 1
        vm.detach_disk(new_disk)
        vm.independent_disks.should eql []
      ensure
        vdc.delete_all_disks_by_name(new_disk_name)
      end
    end
  end

  describe "vm manipulation" do
    it "powers on/off vm successfully" do
      catalog = client.find_catalog_by_name(catalog_name)
      vapp = catalog.instantiate_vapp_template(vapp_template_name,
                                               vdc_name,
                                               vapp_name)
      vm = vapp.vms.first
      vm.power_on
      vm.power_off
    end
  end

  describe "media file manipulation" do
    it "inserts/ejects media successfully" do
      catalog = client.find_catalog_by_name(catalog_name)
      vapp = catalog.instantiate_vapp_template(vapp_template_name,
                                               vdc_name,
                                               vapp_name)
      vm = vapp.vms.first
      task = vm.insert_media(catalog_name, media_name)
      vm.send(:task_is_success, task)
        .should be_true
      task = vm.eject_media(catalog_name, media_name)
      vm.send(:task_is_success, task)
        .should be_true
      end
    end

    context "catalog matching the name does not exist" do
      it "raises ObjectNotFoundError" do
        catalog = client.find_catalog_by_name(catalog_name)
        vapp = catalog.instantiate_vapp_template(vapp_template_name,
                                                 vdc_name,
                                                 vapp_name)
        vm = vapp.vms.first
        expect do
          vm.insert_media("dummy", media_name)
        end.to raise_exception VCloudSdk::ObjectNotFoundError,
                               "Catalog 'dummy' is not found"
        expect do
          vm.eject_media("dummy", media_name)
        end.to raise_exception VCloudSdk::ObjectNotFoundError,
                               "Catalog 'dummy' is not found"
      end
    end

    context "media file matching the name does not exist" do
      it "raises ObjectNotFoundError" do
        catalog = client.find_catalog_by_name(catalog_name)
        vapp = catalog.instantiate_vapp_template(vapp_template_name,
                                                 vdc_name,
                                                 vapp_name)
        vm = vapp.vms.first
        expect do
          vm.insert_media(catalog_name, "dummy")
        end.to raise_exception VCloudSdk::ObjectNotFoundError,
                               "Catalog Item 'dummy' is not found"
        expect do
          vm.eject_media(catalog_name, "dummy")
        end.to raise_exception VCloudSdk::ObjectNotFoundError,
                               "Catalog Item 'dummy' is not found"
      end
    end

    context "media file matching the name is already inserted" do
      it "inserts media file again returning successful message" do
        catalog = client.find_catalog_by_name(catalog_name)
        vapp = catalog.instantiate_vapp_template(vapp_template_name,
                                                 vdc_name,
                                                 vapp_name)
        vm = vapp.vms.first
        task = vm.insert_media(catalog_name, media_name)
        vm.send(:task_is_success, task)
          .should be_true
        task = vm.insert_media(catalog_name, media_name)
        vm.send(:task_is_success, task)
          .should be_true
      end
    end

    context "media file matching the name is not inserted" do
      it "ejects the media file returning successful message" do
        catalog = client.find_catalog_by_name(catalog_name)
        vapp = catalog.instantiate_vapp_template(vapp_template_name,
                                                 vdc_name,
                                                 vapp_name)
        vm = vapp.vms.first
        task = vm.eject_media(catalog_name, media_name)
        vm.send(:task_is_success, task)
          .should be_true
    end
  end

  describe "network manipulation" do
    it "adds nic to VM" do
      begin
        vapp_name = SecureRandom.uuid
        catalog = client.find_catalog_by_name(catalog_name)
        vapp = catalog.instantiate_vapp_template(vapp_template_name,
                                                 vdc_name,
                                                 vapp_name)
        vm = vapp.vms.first
        vdc = client.find_vdc_by_name(vdc_name)
        network = vdc.networks.first
        network_name = network.name
        vapp.add_network_by_name(network_name)
        vm.list_networks.should eql []
        vm.add_nic(network_name,
                   VCloudSdk::Xml::IP_ADDRESSING_MODE[:POOL])
        vm.add_nic(network_name,
                   VCloudSdk::Xml::IP_ADDRESSING_MODE[:NONE])
        vm.add_nic(network_name,
                   VCloudSdk::Xml::IP_ADDRESSING_MODE[:DHCP])
        vm.list_networks.size.should eql 3
      ensure
        vapp.power_off
        vapp.delete
      end
    end

    context "VM is powered on" do
      it "raises CloudError" do
        begin
          vapp_name = SecureRandom.uuid
          catalog = client.find_catalog_by_name(catalog_name)
          vapp = catalog.instantiate_vapp_template(vapp_template_name,
                                                   vdc_name,
                                                   vapp_name)
          vm = vapp.vms.first
          vdc = client.find_vdc_by_name(vdc_name)
          network = vdc.networks.first
          network_name = network.name
          vapp.add_network_by_name(network_name)
          vm.list_networks.should eql []
          vm.power_on
          expect do
            vm.add_nic(network_name,
                       VCloudSdk::Xml::IP_ADDRESSING_MODE[:POOL])
          end.to raise_exception VCloudSdk::CloudError,
                                 "VM #{vm.name} is powered-on and cannot add NIC."
        ensure
          vapp.power_off
          vapp.delete
        end
      end
    end

    context "Network is not added to VApp" do
      it "raises CloudError" do
        begin
          vapp_name = SecureRandom.uuid
          catalog = client.find_catalog_by_name(catalog_name)
          vapp = catalog.instantiate_vapp_template(vapp_template_name,
                                                   vdc_name,
                                                   vapp_name)
          vm = vapp.vms.first
          vdc = client.find_vdc_by_name(vdc_name)
          network = vdc.networks.first
          network_name = network.name
          vm.list_networks.should eql []
          expect do
            vm.add_nic(network_name,
                       VCloudSdk::Xml::IP_ADDRESSING_MODE[:POOL])
          end.to raise_exception VCloudSdk::ObjectNotFoundError,
                                 "Network #{network_name} is not added to parent VApp #{vapp.name}"
        ensure
          vapp.power_off
          vapp.delete
        end
      end
    end
  end

  describe "#set_product_section!" do
    let(:properties) do
      [{
         "type" => "string",
         "key" => "CRM_Database_Host",
         "value" => "CRM.example.com",
         "password" => "true",
         "Label" => "CRM Database Host"
       },
       {
         "type" => "string",
         "key" => "CRM_Database_Username",
         "value" => "dbuser",
         "password" => "false"
       },
       {
         "type" => "string",
         "key" => "admin_password",
         "value" => "tempest",
         "password" => "false"
       }
      ]
    end

    it "updates VM product section" do
      begin
        vapp_name = SecureRandom.uuid
        catalog = client.find_catalog_by_name(catalog_name)
        vapp = catalog.instantiate_vapp_template(vapp_template_name,
                                                 vdc_name,
                                                 vapp_name)
        vm = vapp.vms.first
        vm.set_product_section!(properties)
        vm.power_off
        vm.power_on
        vm.product_section_properties.should eql properties
      ensure
        vapp.power_off
        vapp.delete
      end
    end
  end

  subject do
    vdc = client.find_vdc_by_name(vdc_name)
    vdc.vapps.first.vms.first
  end

  describe "#memory" do
    it "returns memory in megabytes of VM" do
      memory_mb = subject.memory
      memory_mb.should > 0
    end
  end

  describe "#vcpu" do
    it "returns number of virtual cpus of VM" do
      subject.vcpu.should > 0
    end
  end
end
