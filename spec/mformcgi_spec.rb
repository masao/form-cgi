#!/usr/bin/env ruby

require "fileutils"
require "rspec/expectations"
require_relative "../mformcgi.rb"

context FormCGIAdmin do
  def setup
    unless File.exists? "data"
      FileUtils.mkdir("data")
    end
  end
  before :each do
    setup
    @cgi = CGI.new
    @app = FormCGIAdmin.new(@cgi)
    STDERR.puts @app.inspect
  end
  it "#load_csv" do
    expect( @app.to_csv ).to be_empty
  end
end
