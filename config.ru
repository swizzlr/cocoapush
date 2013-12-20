use Rack::Deflater

require 'rack-cache'
use Rack::Cache

require './app.rb'
run CocoaPush
