require "spec_helper"
require "json"

describe InfluxDB::Client do
  before do
    @influxdb = InfluxDB::Client.new "database", :host => "influxdb.test",
      :port => 9999, :username => "username", :password => "password"
  end

  describe "#new" do
    it "should instantiate a new InfluxDB client and default to localhost" do
      @influxdb = InfluxDB::Client.new

      @influxdb.should be_a(InfluxDB::Client)
      @influxdb.host.should ==("localhost")
      @influxdb.port.should ==(8086)
      @influxdb.username.should ==("root")
      @influxdb.password.should ==("root")
    end

    it "should instantiate a new InfluxDB client" do
      @influxdb = InfluxDB::Client.new "database", :hostname => "host",
        :port => "port", :username => "username", :password => "password"

      @influxdb.should be_a(InfluxDB::Client)
      @influxdb.host.should ==("localhost")
      @influxdb.port.should ==("port")
      @influxdb.username.should ==("username")
      @influxdb.password.should ==("password")
    end
  end

  describe "#create_database" do
    it "should POST to create a new database" do
      stub_request(:post, "http://influxdb.test:9999/db").with(
        :query => {:u => "username", :p => "password"},
        :body => JSON.generate({:name => "foo"})
      )

      @influxdb.create_database("foo").should be_a(Net::HTTPOK)
    end
  end

  describe "#delete_database" do
    it "should DELETE to remove a database" do
      stub_request(:delete, "http://influxdb.test:9999/db/foo").with(
        :query => {:u => "username", :p => "password"}
      )

      @influxdb.delete_database("foo").should be_a(Net::HTTPOK)
    end
  end

  describe "#get_database_list" do
    it "should GET a list of databases" do
      database_list = [{"name" => "foobar"}]
      stub_request(:get, "http://influxdb.test:9999/dbs").with(
        :query => {:u => "username", :p => "password"}
      ).to_return(:body => JSON.generate(database_list, :status => 200))

      @influxdb.get_database_list.should == database_list
    end
  end

  describe "#create_database_user" do
    it "should POST to create a new database user" do
      stub_request(:post, "http://influxdb.test:9999/db/foo/users").with(
        :query => {:u => "username", :p => "password"},
        :body => JSON.generate({:username => "useruser", :password => "passpass"})
      )

      @influxdb.create_database_user("foo", "useruser", "passpass").should be_a(Net::HTTPOK)
    end
  end

  describe "#write_point" do
    it "should POST to add points" do
      body = [{
        :name => "seriez",
        :points => [["juan", 87]],
        :columns => ["name", "age"]
      }]

      stub_request(:post, "http://influxdb.test:9999/db/database/series").with(
        :query => {:u => "username", :p => "password"},
        :body => JSON.generate(body)
      )

      # data = [{:name => "juan", :age => 87}, {:name => "pablo", :age => 64}]
      data = {:name => "juan", :age => 87}

      @influxdb.write_point("seriez", data).should be_a(Net::HTTPOK)
    end

    it "should POST multiple points" do
      body = [{
        :name => "seriez",
        :points => [["juan", 87], ["shahid", 99]],
        :columns => ["name", "age"]
      }]

      stub_request(:post, "http://influxdb.test:9999/db/database/series").with(
        :query => {:u => "username", :p => "password"},
        :body => JSON.generate(body)
      )

      data = [{:name => "juan", :age => 87}, { :name => "shahid", :age => 99}]

      @influxdb.write_point("seriez", data).should be_a(Net::HTTPOK)
    end

    it "should POST multiple points with missing columns" do
      body = [{
        :name => "seriez",
        :points => [["juan", 87], ["shahid", nil]],
        :columns => ["name", "age"]
      }]

      stub_request(:post, "http://influxdb.test:9999/db/database/series").with(
        :query => {:u => "username", :p => "password"},
        :body => JSON.generate(body)
      )

      data = [{:name => "juan", :age => 87}, { :name => "shahid"}]

      @influxdb.write_point("seriez", data).should be_a(Net::HTTPOK)
    end
  end

  describe "#execute_queries" do
    before(:each) do
      data = [{ :name => "foo", :columns => ["name", "age"], :values => [["shahid", 99],["dix", 50]]}]

      stub_request(:get, "http://influxdb.test:9999/db/database/series").with(
        :query => { :q => "select * from foo", :u => "username", :p => "password"}
      ).to_return(
        :body => JSON.generate(data)
      )
    end

    expected_series = { 'foo' => [{"name" => "shahid", "age" => 99}, {"name" => "dix", "age" => 50}]}

    it 'can execute a query with a block' do
      series = { }

      @influxdb.query "select * from foo" do |name, points|
        series[name] = points
      end

      series.should ==(expected_series)
    end

    it 'can execute a query without a block' do
      series = @influxdb.query 'select * from foo'
      series.should ==(expected_series)
    end
  end
end
