require "spec_helper"
require "nokogiri/diff"

describe VCloudSdk::Client do

  let(:logger) { VCloudSdk::Config.logger }
  let(:url) { ENV['VCLOUD_URL'] || VCloudSdk::Test::DefaultSetting::VCLOUD_URL }
  let(:username) { ENV['VCLOUD_USERNAME'] || VCloudSdk::Test::DefaultSetting::VCLOUD_USERNAME }
  let(:password) { ENV['VCLOUD_PWD'] || VCloudSdk::Test::DefaultSetting::VCLOUD_PWD }
  let(:vdc_name) { ENV['VDC_NAME'] || VCloudSdk::Test::DefaultSetting::VDC_NAME }
  let(:catalog_name) { ENV['CATALOG_NAME'] || VCloudSdk::Test::DefaultSetting::CATALOG_NAME }
  #let(:url) { 'https://p2v1-vcd.vchs.vmware.com:443' }
  #let(:username) { 'justiny@vmware.com@164-935' }
  #let(:password) { 'Pa$$w0rd' }
  #let(:vdc_name) { "164-935" }
  #let(:catalog_name) { "cloudfoundry" }

  describe "#initialize" do
    it "set up connection successfully" do
      described_class.new(url, username, password, {}, logger)
    end

    it "given incorrect url" do
      expect do
        described_class.new(url + 'wronglink', username, password, {}, logger)
      end.to raise_error
    end

    it "given incorrect username/pwd" do
      expect do
        described_class.new(url, username, 'wrongpassword', {}, logger)
      end.to raise_error(RestClient::Unauthorized, /401 Unauthorized/)
    end
  end

  describe "#find_vdc_by_name" do
    subject { described_class.new(url, username, password, {}, logger) }

    it "fail if targeted vdc does not exist" do
      expect { subject.find_vdc_by_name("xxxx") }.to raise_error
    end

    it "find targeted vdc if it exists" do
      vdc = subject.find_vdc_by_name(vdc_name)
      vdc.should_not be_nil
    end
  end

  describe "#find_catalog_by_name" do
    subject { described_class.new(url, username, password, {}, logger) }

    it "return nil if targeted catalog does not exist" do
      catalog = subject.find_catalog_by_name("xxxx")
      catalog.should be_nil
    end

    it "find targeted catalog if it exists" do
      catalog = subject.find_catalog_by_name(catalog_name)
      catalog.should_not be_nil
    end
  end

  describe "#create_catalog" do
    subject { described_class.new(url, username, password, {}, logger) }

    it "creates target catalog successfully" do
      pending "Delete catalog after creation"

      catalog_name_to_create = SecureRandom.uuid
      response = subject.create_catalog(catalog_name_to_create)
      response.name.should eql catalog_name_to_create
      expect { subject.create_catalog(catalog_name_to_create) }.to raise_error("400 Bad Request")
    end
  end
end
