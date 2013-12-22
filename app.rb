require './helpers.rb'
require 'sinatra/base'
require 'thin'
require 'json'

class CocoaPush < Sinatra::Base
  set :threaded, true
  enable :logging

  set :static, true
  set :static_cache_control, true


  helpers do #ripped from http://wbear.wordpress.com/2010/03/20/sinatra-request-headers-helper/ (WHAT IS WRONG WITH THIS FRICKEN APP FRAMEWORK)
    def request_headers
      env.inject({}){|acc, (k,v)| acc[$1.downcase] = v if k =~ /^http_(.*)/i; acc}
    end
  end

  post "/github-webhook" do
    # make a webhook happen
  end

  post "/#{NOTIF_EXTENSION_SUBROUTE}/#{VERSION}/pushPackages/#{WEBSITE_PUSH_ID}" do
    redirect to('/pushpackage')
    #return push package with user ID and store user ID to db
  end

  get "/pushpackage" do
    cache_control :public, max_age: 10000000
    send_file './CocoaPods.pushpackage.zip'
  end

  post "/#{NOTIF_EXTENSION_SUBROUTE}/#{VERSION}/devices/:device_token/registrations/#{WEBSITE_PUSH_ID}" do
    #register device token for user ID
  end

  delete "/#{NOTIF_EXTENSION_SUBROUTE}/#{VERSION}/devices/:device_token/registrations/#{WEBSITE_PUSH_ID}" do
    #unregister device token and delete user ID
  end

  post "/#{NOTIF_EXTENSION_SUBROUTE}/#{VERSION}/log" do
    errors = JSON.parse(request.body.read)['logs']
    logger.warn "Got #{errors.count} errors from Safari:"
    errors.each { |error| logger.warn error }
    return 500
  end

  get "/#{NOTIF_EXTENSION_SUBROUTE}/#{VERSION}/settingsForDeviceToken" do

  end

  post "/#{NOTIF_EXTENSION_SUBROUTE}/#{VERSION}/settingsForDeviceToken" do
    #update settings for device token
  end

end

