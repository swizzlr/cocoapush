require 'rack-cache'
memcache_server = ENV["MEMCACHE_SERVERS"] || 'localhost:11211'
p "Using memcache server: #{memcache_server}"
use Rack::Cache do |options|
  options.set :verbose, true
  options.set :metastore, "memcached://#{memcache_server}/meta"
  options.set :entitystore, "memcached://#{memcache_server}/entity"
end

use Rack::Deflater

require './app.rb'
run CocoaPush
