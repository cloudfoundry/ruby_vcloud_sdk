require "spec_helper"
require_relative "mocks/client_response"
require_relative "mocks/response_mapping"
require_relative "mocks/rest_client"
require "nokogiri/diff"
require "ruby_vcloud_sdk/xml/wrapper_classes/vapp"

describe VCloudSdk::VApp do

  let(:logger) { VCloudSdk::Test.logger }
  let(:url) { VCloudSdk::Test::Response::URL }
  let(:vapp_name) { VCloudSdk::Test::Response::VAPP_NAME }
  let(:catalog_name) { VCloudSdk::Test::Response::CATALOG_NAME }

  subject do
    vdc_response = VCloudSdk::Xml::WrapperFactory.wrap_document(
      VCloudSdk::Test::Response::VDC_RESPONSE)
    described_class.new(VCloudSdk::Test.mock_session(logger, url),
                        vdc_response.vapps.first)
  end

  describe "#initialize" do
    it "initializes successfully" do
      subject.name.should eql vapp_name
    end
  end

  describe "#delete" do

    before do
      VCloudSdk::Test::ResponseMapping
        .set_option delete_vapp_task_state: :running
    end

    context "vApp is stopped" do
      before do
        VCloudSdk::Test::ResponseMapping
          .set_option vapp_power_state: :off
      end

      context "vApp has no running_tasks" do
        it "deletes target vApp successfully" do
          deletion_task = subject.delete
          subject.send(:task_is_success, deletion_task)
            .should be_true
        end

        it "fails to delete vApp" do
          subject
            .should_receive(:task_is_success)
            .at_least(3)
            .and_return(false)

          expect { subject.delete }
            .to raise_exception VCloudSdk::ApiTimeoutError,
                                "Task Deleting Virtual Application (#{VCloudSdk::Test::Response::VAPP_ID})" +
                                " did not complete within limit of 3 seconds."
        end
      end

      context "vApp has running_tasks" do
        it "waits until running tasks complete" do
          deletion_running_task = VCloudSdk::Xml::WrapperFactory.wrap_document(
            VCloudSdk::Test::Response::INSTANTIATED_VAPP_DELETE_RUNNING_TASK)
          running_tasks = [deletion_running_task]
          VCloudSdk::Xml::VApp
            .any_instance
            .should_receive(:running_tasks)
            .twice
            .and_return(running_tasks)

          deletion_task = subject.delete
          subject.send(:task_is_success, deletion_task)
            .should be_true
        end
      end
    end

    context "vApp is powered on" do
      before do
        VCloudSdk::Test::ResponseMapping
          .set_option vapp_power_state: :on
      end

      it "fails to delete target vApp" do
        expect do
          subject.delete
        end.to raise_exception VCloudSdk::CloudError,
                               "vApp #{vapp_name} is powered on, power-off before deleting."
      end
    end
  end

  describe "#power_on" do
    context "vApp is powered off" do
      before do
        VCloudSdk::Test::ResponseMapping
          .set_option vapp_power_state: :powered_off
      end

      it "powers on target vApp successfully" do
        power_on_task = subject.power_on
        subject.send(:task_is_success, power_on_task)
          .should be_true
      end

      it "fails to power on vApp" do
        subject
          .should_receive(:task_is_success)
          .at_least(3)
          .and_return(false)

        expect { subject.power_on }
          .to raise_exception VCloudSdk::ApiTimeoutError,
                              "Task Starting Virtual Application test17_3_8(2b685484-ed2f-48c3-9396-5ad29cb282f4)" +
                              " did not complete within limit of 3 seconds."
      end
    end

    context "vApp is powered on" do
      before do
        VCloudSdk::Test::ResponseMapping
          .set_option vapp_power_state: :on
      end

      it "does not try to power on vApp again" do
        subject.send(:connection)
          .should_not_receive(:post)

        subject.power_on
      end
    end
  end

  describe "#power_off" do

    context "vApp is powered on" do
      before do
        VCloudSdk::Test::ResponseMapping
          .set_option vapp_power_state: :on
      end

      it "powers off target vApp successfully" do
        power_off_task = subject.power_off
        subject.send(:task_is_success, power_off_task)
          .should be_true
      end

      it "fails to power off vApp" do
        subject
          .should_receive(:task_is_success)
          .at_least(3)
          .and_return(false)

        expect { subject.power_off }
          .to raise_exception VCloudSdk::ApiTimeoutError,
                              "Task Starting Virtual Application test17_3_8(2b685484-ed2f-48c3-9396-5ad29cb282f4)" +
                              " did not complete within limit of 3 seconds."
      end
    end

    context "vApp is powered off" do
      before do
        VCloudSdk::Test::ResponseMapping
          .set_option vapp_power_state: :powered_off
      end

      it "does not try to power off the vApp again" do
        subject.send(:connection)
          .should_not_receive(:post)

        subject.power_off
      end
    end

    context "vApp is suspended" do
      before do
        VCloudSdk::Test::ResponseMapping
          .set_option vapp_power_state: :suspended
      end

      it "raises error" do
        subject.send(:connection)
          .should_not_receive(:post)

        expect { subject.power_off }
          .to raise_exception VCloudSdk::VappSuspendedError,
                              "discard state first"
      end
    end
  end

  describe "#recompose_from_vapp_template" do
    context "vapp is powered off" do
      before do
        VCloudSdk::Test::ResponseMapping
        .set_option vapp_power_state: :off
        VCloudSdk::Test::ResponseMapping
        .set_option catalog_state: :not_added
      end

      context "vapp template exists" do
        before do
          VCloudSdk::Test::ResponseMapping
            .set_option catalog_state: :added
        end

        it "adds vm to target vapp" do
          subject
            .recompose_from_vapp_template catalog_name,
                                          VCloudSdk::Test::Response::EXISTING_VAPP_TEMPLATE_NAME
        end
      end

      context "vapp template does not exist" do
        before do
          VCloudSdk::Test::ResponseMapping
            .set_option catalog_state: :not_added
        end

        it "raises ObjectNotFoundError" do
          expect do
            subject
              .recompose_from_vapp_template catalog_name,
                                            VCloudSdk::Test::Response::EXISTING_VAPP_TEMPLATE_NAME
          end.to raise_exception VCloudSdk::ObjectNotFoundError
                                 "Catalog Item '#{VCloudSdk::Test::Response::EXISTING_VAPP_TEMPLATE_NAME}' is not found"
        end
      end
    end

    context "vapp is powered on" do
      before do
        VCloudSdk::Test::ResponseMapping
          .set_option vapp_power_state: :on
      end

      it "raises an exception" do
        expect do
          subject
            .recompose_from_vapp_template catalog_name,
                                          VCloudSdk::Test::Response::EXISTING_VAPP_TEMPLATE_NAME
        end.to raise_exception VCloudSdk::CloudError
               "VApp is in status of 'POWERED_OFF' and can not be recomposed"
      end
    end
  end

  describe "#vms" do
    before do
      VCloudSdk::Test::ResponseMapping
        .set_option vapp_power_state: :on
    end

    it "returns a collection of vms" do
      vms = subject.vms
      vms.should have_at_least(1).item
      vms.each do |vm|
        vm.should be_an_instance_of VCloudSdk::VM
      end
    end
  end
end