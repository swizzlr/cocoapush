require './helpers.rb'
require 'sinatra/base'
require 'sinatra/streaming'
require 'thin'
require 'json'

class CocoaPush < Sinatra::Base
  set :threaded, true
  enable :logging

  helpers do #ripped from http://wbear.wordpress.com/2010/03/20/sinatra-request-headers-helper/ (WHAT IS WRONG WITH THIS FRICKEN APP FRAMEWORK)
    def request_headers
      env.inject({}){|acc, (k,v)| acc[$1.downcase] = v if k =~ /^http_(.*)/i; acc}
    end
    Sinatra::Streaming
  end

  post "/github-webhook" do
    # make a webhook happen
  end

  post "/#{NOTIF_EXTENSION_SUBROUTE}/#{VERSION}/pushPackages/#{WEBSITE_PUSH_ID}" do
    stream do |zip|
      zip << File.read('./CocoaPods.pushpackage.zip')
    end
    response['Content-Type'] = 'application/zip'
    return 200
    #return push package with user ID and store user ID to db
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
    #return settings for device token
  end

  post "/#{NOTIF_EXTENSION_SUBROUTE}/#{VERSION}/settingsForDeviceToken" do
    #update settings for device token
  end

end

