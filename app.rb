require './helpers.rb'
require 'sinatra/base'
require 'json'

require 'mongo'
require 'uri'

ENV['MONGODB_URI'] = ENV['MONGOHQ_URL']
db_name = URI.parse(ENV['MONGODB_URI']).path.gsub(/^\//, '') rescue nil

Mongo_Client = Mongo::MongoClient.new(:pool_size => 50, :pool_timeout => 5)
DB = Mongo_Client.db(db_name || 'cocoapush')

p "Connected to Mongo server: #{Mongo_Client.host}, using DB: #{DB.name}"

Users = DB.collection('users')
Pods = DB.collection('pods')

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
    payload = JSON.parse params[:payload]
    pods = payload["commits"]
      .map { |commit| commit["added"] }
      .flatten
      .map { |path| path[/(?<=[\/])[^\/]+?(?!\/)(?=\.podspec$)/] } #is there a file path class that can do this for me?
      .uniq
    p 'Podspecs added to the specs repo:'
    p pods
    # push out to the people!
    pods.each do |pod|
      #create notification
      #grocer notification goes here
      Pods.find_one( { _id: pod }, { users: true, _id: false } )['users'].each do |device_token|
        # set the device token and flush it down the tubes
      end
    end
  end

  post "/test-webhook" do
    call! env.merge('PATH_INFO' => '/github-webhook')
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
    Users.insert( { _id: params[:device_token] } ) rescue return 200
    return 201
  end

  delete "/#{NOTIF_EXTENSION_SUBROUTE}/#{VERSION}/devices/:device_token/registrations/#{WEBSITE_PUSH_ID}" do
    #unregister device token and delete user ID
    result = Users.find_one(
      { _id: params[:device_token] },
      { fields:
        { 'settings.pods' => 1, _id: 0 }
      }
    )
    return [404, 'Device token not registered.'] unless result
    pods = result['settings']['pods'] rescue nil
    Users.remove( { _id: params[:device_token] } )
    if pods
      Pods.update(
        { _id: { '$in' => pods } }, #match any Pod document that is within the pods the user had requested
        { '$pull' => { users: params[:device_token] } }, #remove their device token from the pod
        { multi: true } #enable update of multiple documents
      )
    end
    return 204
  end

  post "/#{NOTIF_EXTENSION_SUBROUTE}/#{VERSION}/log" do
    errors = JSON.parse(request.body.read)['logs']
    logger.warn "Got #{errors.count} errors from Safari:"
    errors.each { |error| logger.warn error }
    return 202
  end

  get "/#{NOTIF_EXTENSION_SUBROUTE}/#{VERSION}/settingsForDeviceToken/:device_token" do
    result = Users.find_one( { _id: params[:device_token] } )['settings'] rescue nil
    if result
      return JSON.generate(result)
    else
      return [404, 'User not registered.']
    end
  end

  post "/#{NOTIF_EXTENSION_SUBROUTE}/#{VERSION}/settingsForDeviceToken/:device_token" do
    (req = JSON.parse(request.body.read)['pods']) rescue return [400, 'Invalid JSON']
    pods = req['pods'] rescue nil
    is_registered = Users.find_one( { _id: params[:device_token] }, { fields: { settings: 0 } } )
    return [412, "This user has not yet been registered to the database. Who is this? What\'s your operating number?"] unless is_registered
    if pods
      Users.update( #update settings on user side
        { _id: params[:device_token] },
        { settings: { pods: pods } }
      )
      pods.each do |pod| #update interested users per pod for benefit of notification pushing
        Pods.update(
          { _id: pod },
          { '$addToSet' => { users: params[:device_token] } }, # add to array or create if one missing, ensure unique
          { upsert: true } #create pod document if none matches selector
        )
      end
    end
    return 200
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

