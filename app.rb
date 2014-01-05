require './helpers.rb'
require 'sinatra/base'
require 'json'

require 'mongo'
Mongo_Client = Mongo::MongoClient.new("localhost", 27017, :pool_size => 50, :pool_timeout => 5)
DB = Mongo_Client.db('cocoapush')
Users = DB.collection('users')

class CocoaPush < Sinatra::Base
  configure :production do
    require 'newrelic_rpm'
  end

  enable :threaded
  set :server, 'puma'

  p "Sinatra is starting with Rack env: #{ENV['RACK_ENV']}"

  helpers do #ripped from http://wbear.wordpress.com/2010/03/20/sinatra-request-headers-helper/ (WHAT IS WRONG WITH THIS FRICKEN APP FRAMEWORK)
    def request_headers
      env.inject({}){|acc, (k,v)| acc[$1.downcase] = v if k =~ /^http_(.*)/i; acc}
    end
  end

  post "/github-webhook" do
    # make a webhook happen
  end

  post "/#{NOTIF_EXTENSION_SUBROUTE}/#{VERSION}/pushPackages/#{WEBSITE_PUSH_ID}" do
    #return push package with user ID and store user ID to db
    redirect to('/pushpackage')
  end

  get "/pushpackage" do
    cache_control :public, max_age: 10000000
    send_file './CocoaPods.pushpackage.zip'
  end

  post "/#{NOTIF_EXTENSION_SUBROUTE}/#{VERSION}/devices/:device_token/registrations/#{WEBSITE_PUSH_ID}" do
    #register device token for user ID
    Users.insert( {
      device_token: params[:device_token]
    } )
  end

  delete "/#{NOTIF_EXTENSION_SUBROUTE}/#{VERSION}/devices/:device_token/registrations/#{WEBSITE_PUSH_ID}" do
    #unregister device token and delete user ID
    Users.remove( {
      device_token: params[:device_token]
    } )
  end

  post "/#{NOTIF_EXTENSION_SUBROUTE}/#{VERSION}/log" do
    errors = JSON.parse(request.body.read)['logs']
    logger.warn "Got #{errors.count} errors from Safari:"
    errors.each { |error| logger.warn error }
    return 500
  end

  get "/#{NOTIF_EXTENSION_SUBROUTE}/#{VERSION}/settingsForDeviceToken/:device_token" do
    result = Users.find_one( { device_token: params[:device_token] } )
    result[:settings] unless result == nil

  end

  post "/#{NOTIF_EXTENSION_SUBROUTE}/#{VERSION}/settingsForDeviceToken/:device_token" do
    Users.update( { device_token: params[:device_token] }, { settings: request.body.read } )
  end

  def validate_incoming_json_settings(str)
    json = JSON.parse str
    if (json.class == Hash)
      if !json[:pods] || json[:pods].class == Array
        if !json[:terms] || json[:terms].class == Array
          return true
        end
      end
    end
  end

end

