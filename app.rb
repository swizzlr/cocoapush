require 'sinatra/base'
require 'thin'

class CocoaPush < Sinatra::Base
  set :threaded, true
  enable :logging

  helpers do #ripped from http://wbear.wordpress.com/2010/03/20/sinatra-request-headers-helper/ (WHAT IS WRONG WITH THIS FRICKEN APP FRAMEWORK)
    def request_headers
      env.inject({}){|acc, (k,v)| acc[$1.downcase] = v if k =~ /^http_(.*)/i; acc}
    end
  end

  post "/github-webhook" do
    # make a webhook happen
  end

  version = 'v1'
  notif_extension_subroute = 'push'
  website_push_id = 'web.org.cocoapods.push'

  post "/#{notif_extension_subroute}/#{version}/pushPackages/#{website_push_id}" do
    return "hey"
    #return push package with user ID and store user ID to db
  end

  post "/#{notif_extension_subroute}/#{version}/devices/:device_token/registrations/#{website_push_id}" do
    #register device token for user ID
  end

  delete "/#{notif_extension_subroute}/#{version}/devices/:device_token/registrations/#{website_push_id}" do
    #unregister device token and delete user ID
  end

  post "/#{notif_extension_subroute}/#{version}/log" do
    p '!!!ERROR!!!'
    JSON.parse(request.body.read)['logs'].each { |error| p error }
    p
    return 500
  end

  get "/#{notif_extension_subroute}/#{version}/settingsForDeviceToken" do
    #return settings for device token
  end

  post "/#{notif_extension_subroute}/#{version}/settingsForDeviceToken" do
    #update settings for device token
  end

end

