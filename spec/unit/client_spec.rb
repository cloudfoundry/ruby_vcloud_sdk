require "spec_helper"
require_relative "mocks/client_response"
require_relative "mocks/response_mapping"
require_relative "mocks/rest_client"
require "nokogiri/diff"

describe VCloudSdk::Client do

  let(:logger) { VCloudSdk::Config.logger }
  let(:url) { VCloudSdk::Test::Response::URL }
  let(:username) { "cfadmin" }
  let(:password) { "akimbi" }
  let(:response_mapping) { response_mapping }
  let(:conn) { double("Connection") }

  let!(:mock_connection) do
    VCloudSdk::Test.mock_connection(logger, url)
  end

  let(:session) do
    VCloudSdk::Xml::WrapperFactory
      .wrap_document(VCloudSdk::Test::Response::SESSION)
  end

  let(:org_response) do
    VCloudSdk::Xml::WrapperFactory
      .wrap_document(VCloudSdk::Test::Response::ORG_RESPONSE)
  end

  describe "#initialize" do
    it "set up connection successfully" do
      VCloudSdk::Connection::Connection
        .should_receive(:new)
        .once
        .and_return(mock_connection)
      described_class.new(url, username, password, {}, logger)
    end

    it "use default settings if not specified in input arguments" do
      VCloudSdk::Connection::Connection
        .should_receive(:new).once.and_return conn

      conn.should_receive(:connect)
        .with(username, password)
        .once
        .ordered
        .and_return(session)
      conn.should_receive(:get)
        .with(session.organization)
        .once
        .ordered
        .and_return(org_response)

      client = described_class.new(nil, username, password, {}, logger)
      VCloudSdk::Test.verify_settings client,
                                      :@retries => VCloudSdk::Client
                                      .const_get(:RETRIES),
                                      :@time_limit => VCloudSdk::Client
                                      .const_get(:TIME_LIMIT_SEC)

      VCloudSdk::Config.rest_throttle.should eq VCloudSdk::Client.const_get(:REST_THROTTLE)
    end

    it "use settings in input arguments" do
      VCloudSdk::Connection::Connection
        .should_receive(:new).once.and_return conn

      conn.should_receive(:connect)
        .with(username, password)
        .once
        .ordered
        .and_return(session)
      conn.should_receive(:get)
        .with(session.organization)
        .once
        .ordered
        .and_return(org_response)

      retries = {
        default: 5,
        upload_vapp_files: 7,
        cpi: 1
      }

      time_limit_sec = {
        default: 120,
        delete_vapp_template: 120,
        delete_vapp: 120,
        delete_media: 120,
        instantiate_vapp_template: 300,
        power_on: 600,
        power_off: 600,
        undeploy: 720,
        process_descriptor_vapp_template: 300,
        http_request: 240
      }

      rest_throttle = {
        min: 0,
        max: 1,
      }

      options = {
        retries: retries,
        time_limit_sec: time_limit_sec,
        rest_throttle: rest_throttle,
      }

      client = described_class.new(nil, username, password, options, logger)

      VCloudSdk::Test.verify_settings client,
                                      :@retries => retries,
                                      :@time_limit => time_limit_sec
      VCloudSdk::Config.rest_throttle.should eq rest_throttle
    end
  end

  describe "#find_vdc_by_name" do
    subject { initialize_client }

    it "fail if targeted vdc does not exist" do
      expect { subject.find_vdc_by_name("xxxx") }.to raise_error
    end

    it "find targeted vdc if it exists" do
      vdc = subject.find_vdc_by_name(VCloudSdk::Test::Response::OVDC)
      vdc.should_not be_nil
    end
  end

  describe "#catalogs" do
    subject { initialize_client }

    its(:catalogs) { should have_at_least(1).items }
  end

  describe "#find_catalog_by_name" do
    subject { initialize_client }

    it "return nil if targeted catalog does not exist" do
      catalog = subject.find_catalog_by_name("xxxx")
      catalog.should be_nil
    end

    it "find targeted catalog if it exists" do
      catalog = subject.find_catalog_by_name(VCloudSdk::Test::Response::CATALOG_NAME)
      catalog.should_not be_nil
    end
  end

  private
  def initialize_client
    VCloudSdk::Connection::Connection.stub(:new) { mock_connection }
    described_class.new(url, username, password, {}, logger)
  end
end
