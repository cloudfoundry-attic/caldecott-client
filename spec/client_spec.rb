# Copyright (c) 2009-2011 VMware, Inc.

require File.join(File.dirname(__FILE__), "spec_helper")
require "caldecott-client/client"

describe "Caldecott Client" do
  before do
    @tunnel = mock("Tunnel")
    @tunnel.stub(:for_url)
    @tunnel.stub(:start)
    @tunnel.stub(:read).and_return("")
    @tunnel.stub(:write)
    @tunnel.stub(:stop) { @tunnel.stub(:closed?).and_return(true) }
    @tunnel.stub(:closed?).and_return(false)

    @conn = mock(Socket, :closed? => false)
    @conn.stub(:close){ @conn.stub(:closed?).and_return(true) }
  end

  it "raises an error if tunnel url is not provided" do
    expect { Caldecott::Client.start({}) }.to raise_error(Caldecott::InvalidTunnelUrl)
  end

  it "sends buffered data from tunnel to local server" do
    options = { :tun_url => "http://tunnel.cloudfoundry.com" }
    client = Caldecott::Client::CaldecottClient.new(options)
    @conn.stub(:send) { |arg, _| arg }
    @tunnel.stub(:read) do
      @tunnel.stop
      "test"
    end
    stub_const("Caldecott::Client::BUFFER_SIZE", 1)

    # Should receive all data split by 1 byte
    @conn.should_receive(:send).exactly(4).times.and_return("t", "e", "s", "t")
    r = Thread.new do
      client.read_from_tunnel(@tunnel, @conn)
    end
    r.join
  end
  
  it "sends over 1mb from tunnel to local server" do
    bigdata_size = (1024*1024)+3086
    bigdata = (0...bigdata_size).map{ "a" }.join
    
    options = { :tun_url => "http://tunnel.cloudfoundry.com" }
    client = Caldecott::Client::CaldecottClient.new(options)
    
    data_received=0
    
    @conn.stub(:send) do |arg, _| 
      data_received = data_received+arg.length
      arg
    end
    @tunnel.stub(:read) do
      @tunnel.stop
      bigdata
    end
    
    # Fix this to 1MB incase it is changed in the future
    stub_const("Caldecott::Client::BUFFER_SIZE", 1024 * 1024)

    @conn.should_receive(:send).exactly(2).times
    r = Thread.new do
      client.read_from_tunnel(@tunnel, @conn)
    end
    r.join
    data_received.should eq(bigdata_size)
  end

  it "sends data from local server to tunnel" do
    options = { :tun_url => "http://tunnel.cloudfoundry.com" }
    client = Caldecott::Client::CaldecottClient.new(options)
    @conn.stub(:recv).and_return("test", "")
    @tunnel.should_receive(:write).with("test")
    w = Thread.new do
      client.write_to_tunnel(@tunnel, @conn)
    end
    client.close
    w.join
  end
end