require "spec_helper"
require_relative "mocks/client_response"
require_relative "mocks/response_mapping"
require "nokogiri/diff"

logger = VCloudSdk::Config.logger

describe VCloudSdk::Client, :min, :all do

  let(:url) { "https://10.147.0.0:8443" }
  let(:username) { "cfadmin" }
  let(:password) { "akimbi" }
  let(:response_mapping) { response_mapping }
  let(:conn) { double("Connection") }
  let(:root_session) do
    VCloudSdk::Xml::WrapperFactory
    .wrap_document(VCloudSdk::Test::Response::SESSION)
  end

  let(:vcloud_response) do
    VCloudSdk::Xml::WrapperFactory
    .wrap_document(VCloudSdk::Test::Response::VCLOUD_RESPONSE)
  end

  let(:admin_org_response) do
    VCloudSdk::Xml::WrapperFactory
    .wrap_document(VCloudSdk::Test::Response::ADMIN_ORG_RESPONSE)
  end

  def build_url
    url + @resource
  end

  def mock_rest_connection
    rest_client = double("Rest Client")
    site = double("site")
    rest_client.stub(:get) do |headers|
      VCloudSdk::Test::ResponseMapping
      .get_mapping(:get, build_url).call(build_url, headers)
    end
    rest_client.stub(:post) do |data, headers|
      VCloudSdk::Test::ResponseMapping
      .get_mapping(:post, build_url).call(build_url, data, headers)
    end
    site.stub(:[]) do |value|
      @resource = value
      rest_client
    end

    VCloudSdk::Connection::Connection.new(url, nil, nil, site)
  end

  describe "#initialize" do
    it "set up connection successfully" do
      VCloudSdk::Config.configure(
          logger: logger,
          rest_throttle: { min: 0, max: 1 })

      connection = mock_rest_connection
      VCloudSdk::Connection::Connection.should_receive(:new)
      .with(anything, anything).once.and_return connection
      described_class.new(url, username, password, {}, logger)
    end

    it "use default settings if not specified in input arguments" do
      VCloudSdk::Connection::Connection.should_receive(:new)
      .with(anything, anything).once.and_return conn
      conn.should_receive(:connect).with(username, password)
      .once.ordered.and_return(root_session)
      conn.should_receive(:get).with(root_session.admin_root)
      .once.ordered.and_return(vcloud_response)
      conn.should_receive(:get).with(vcloud_response.organization)
      .once.ordered.and_return(admin_org_response)
      client = described_class.new(nil, username, password, {}, logger)
      VCloudSdk::Test.verify_settings client,
                                      :@retries => VCloudSdk::Client
                                      .const_get(:RETRIES),
                                      :@time_limit => VCloudSdk::Client
                                      .const_get(:TIME_LIMIT_SEC)

      VCloudSdk::Config.rest_throttle.should eq VCloudSdk::Client.const_get(:REST_THROTTLE)
    end

    it "use settings in input arguments" do
      VCloudSdk::Connection::Connection.should_receive(:new)
      .with(anything, anything).once.and_return conn
      conn.should_receive(:connect).with(username, password)
      .once.ordered.and_return(root_session)
      conn.should_receive(:get).with(root_session.admin_root)
      .once.ordered.and_return(vcloud_response)
      conn.should_receive(:get).with(vcloud_response.organization)
      .once.ordered.and_return(admin_org_response)

      retries =
          {
              default: 5,
              upload_vapp_files: 7,
              cpi: 1
          }

      time_limit_sec =
          {
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

      rest_throttle =
          {
              min: 0,
              max: 1
          }

      options = { retries: retries, time_limit_sec: time_limit_sec, rest_throttle: rest_throttle }
      client = described_class.new(nil, username, password,
                                   options, logger)
      VCloudSdk::Test.verify_settings client,
                                      :@retries => retries,
                                      :@time_limit => time_limit_sec

      VCloudSdk::Config.rest_throttle.should eq rest_throttle
    end
  end
end
