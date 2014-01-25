require './helpers.rb'
require 'sinatra/base'
require 'json'

# --- MongoDB stack initialization --- #

require 'mongo'
require 'uri'

ENV['MONGODB_URI'] = ENV['MONGOHQ_URL']
db_name = URI.parse(ENV['MONGODB_URI']).path.gsub(/^\//, '') rescue nil

Mongo_Client = Mongo::MongoClient.new(:pool_size => 50, :pool_timeout => 5)
DB = Mongo_Client.db(db_name || 'cocoapush')

p "Connected to Mongo server: #{Mongo_Client.host}, using DB: #{DB.name}"

Users = DB.collection('users')
Pods = DB.collection('pods')
URLRoutes = DB.collection('url_routes')

# --- Grocer connection initialization --- #

require 'grocer'

CocoaPusher = Grocer.pusher({ certificate: 'certs/web.org.cocoapods.push-combined.pem' })

class CocoaPush < Sinatra::Base
  configure :production do
    require 'newrelic_rpm'
  end

  enable :logging
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
      pod_users = Pods.find_one({ _id: pod }, { fields: { users: 1, _id: 0 } })['users'] rescue nil
      next if pod_users.nil?
      notification = Grocer::SafariNotification.new ({
        title: 'New Pod Available',
        body: 'A pod you are interested in is available',
        url_args: [CocoaPush.generate_route_for_pod(pod)]
      })
      p "Pushing notifications for pod #{pod}"
      pod_users.each do |device_token|
        # set the device token and flush it down the tubes
        notification.device_token = device_token
        p "Pushing #{notification}"
        CocoaPusher.push notification
      end
    end
  end

  def self.generate_route_for_pod(pod, link = 'https://github.com/CocoaPods/Specs')
    url_info = Pods.find_one( #this is not idiomatic
        { _id: pod },
        { fields: { users: 0, _id: 0} }
    )['url_info']

    if url_info # it may have been created already
      return url_info['cocoapush_route'] if (url_info['link'] == link) #has the URL changed?
    end

    require 'securerandom'
    begin
      possible_route = SecureRandom.urlsafe_base64 6
      URLRoutes.insert({_id: possible_route, pod: pod, link: link}) # we need to find a nice way of cleaning up old routes. background rake job, anyone? it'll be slow as they're not indexed.
      Pods.update(
          { _id: pod },
          {"$set" => { url_info: { cocoapush_route: possible_route, link: link } }}
      )
    rescue Mongo::OperationFailure
      retry # in case of route collision
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
    return 200
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
    return 200
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
      return JSON.generate(result) unless result.empty?
    else
      return [404, 'User not registered or has no settings']
    end
  end

  post "/#{NOTIF_EXTENSION_SUBROUTE}/#{VERSION}/settingsForDeviceToken/:device_token" do
    (req = JSON.parse(request.body.read)) rescue return [400, 'Invalid JSON']
    pods = req["pods"] rescue nil
    is_registered = Users.find_one( { _id: params[:device_token] }, { fields: { settings: 0 } } )
    return [412, "This user has not yet been registered to the database. Who is this? What\'s your operating number?"] unless is_registered
    if pods
      p 'updating pods'
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
      return 201
    end
    return 200
  end

  get "/route/:route_hash" do
    redirect to URLRoutes.find_one(
        { _id: params[:route_hash]},
        { fields: { _id: 0, link: 1 } }
    )['link'] rescue return 404
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

