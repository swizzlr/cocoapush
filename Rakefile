require './helpers.rb'

desc 'Bundle what?'
task :bootstrap do
  if `which mongo`.strip.empty? then
    p 'MongoDB not installed, installing now. BE SURE TO FOLLOW CAVEATS AND ADD TO LAUNCHCTL'
    p `brew install mongodb`
  end

  if `which memcached`.strip.empty? then
    p 'Memcache not installed, installing now. BE SURE TO FOLLOW CAVEATS AND ADD TO LAUNCHCTL'
    p `brew install memcached`
  end

  if `which heroku`.strip.empty? then
    p 'Heroku toolbelt not installed, taking you to the webpage for it.'
    `open https://toolbelt.heroku.com`
  end

  Process.exec('bundle install')

end

desc 'Print usage of stress target'
task :stress => 'stress:usage'

namespace :stress do

  targets = {
    :heroku   =>  'https://cocoapush.herokuapp.com',
    :local    =>  'http://localhost:3000',
    :localssl =>  'https://localhost:3000',
    :foreman  =>  'http://localhost:9578'
  }

  paths = {
    :pushpackage      =>  [:POST,   '/push/v1/pushPackages/web.org.cocoapods.push'],
    :get_pushpackage  =>  [:GET,    '/pushpackage'],
    :register         =>  [:POST,   '/push/v1/devices/DEVICE_TOKEN_GOES_HERE/registrations/web.org.cocoapods.push'],
    :unregister       =>  [:DELETE, '/push/v1/devices/DEVICE_TOKEN_GOES_HERE/registrations/web.org.cocoapods.push'],
    :get_settings     =>  [:GET,    '/push/v1/settingsForDeviceToken'],
    :post_settings    =>  [:POST,   '/push/v1/settingsForDeviceToken']
  }

  default_target = :heroku
  default_path = :pushpackage

  desc 'Print usage of stress target'
  task :usage do
    p 'rake stress:[ab|siege][target, paths]'
    p 'Targets:'
    p "Default target #{:heroku}"
    p targets
    p 'Paths:'
    p "Default path #{:pushpackage}"
    p paths
    p
  end

  desc 'Stress test with apache bench'
  task :ab, :target, :path do |t, args|
    target = targets[:"#{args.target}"] || targets[default_target]
    path = paths[:"#{args.path}"] || paths[default_path]
    Process.exec p "ab #{if path[0] == :POST then '-p /dev/null' else '' end} -c 100 -n 10000 #{target}#{path[1]}"
  end

  desc 'Stress test with siege'
  task :siege, :target, :path do |t, args|
    target = targets[:"#{args.target}"] || targets[default_target]
    path = paths[:"#{args.path}"] || paths[default_path]
    if path[0] == :POST then p 'Siege won\'t POST for you' ; exit -1 end
    Process.exec p "siege -c 100 -r 10000 #{target}#{path[1]}"
  end
end

desc 'Flush memcache'
task :flush do
  require 'dalli'
  require 'memcachier'
  Dalli::Client.new.flush_all
end

desc 'Convert p12 key to pem format for push notification signing and pushpackage signing. Pass in password as argument.'
task :convert, :password do |t, args|
  raise NeedsPassword if args.password.nil?
  require 'shellwords'
  Process.exec p "echo #{args.password.shellescape}|openssl pkcs12 -passin stdin -in certs/web.org.cocoapods.push.p12 -out certs/web.org.cocoapods.push-combined.pem -nodes -clcerts"
end

desc 'Generate .env file from private keys and sync to heroku'
task :generate_env do
  File.open '.env', 'w' do |env|
    env << 'APPLE_KEY_CERT=' + File.read('certs/web.org.cocoapods.push-combined.pem').escape + "\n"
    env << 'PORT=' + 9578.to_s + "\n"
    env << 'WEBSERVICE_URL=' + 'https://localhost:9578/push' + "\n"
    env << 'MEMCACHE_SERVERS=' + 'localhost:11211' + "\n"
    env << 'NEW_RELIC_APP_NAME=CocoaPush' + "\n"
    env << "RACK_ENV=production\n"
  end

  `heroku help config:push`
  if $?.exitstatus != 0 then
    p "You didn\'t have heroku-config installed, installing now."
    p `heroku plugins:install git://github.com/ddollar/heroku-config.git`
  end

  p `heroku config:push -o`
  p `heroku config:set WEBSERVICE_URL=#{HEROKU_WEBSERVICE_URL}`
  p `heroku config:unset MEMCACHE_SERVERS`

end

desc 'Watch for changes and restart server when necessary.'
task :kick => 'kick:kicker'

namespace :kick do
  Lockfile_name = '.server_running_lockfile'

  task :kicker => :run_or_restart_server do
    puts 'Starting kicker'
    Process.exec('bundle exec kicker')
  end

  task :run_or_restart_server do #all kicking logic is found in the rakefile. because reasons.
    puts 'Checking for running server...'
    if File.exists?(Lockfile_name)
      puts 'Killing server...'
      Process.kill('KILL', File.read(Lockfile_name).to_i) rescue nil
      File.delete(Lockfile_name)
    end
    puts 'Spawning rake task'
    pid = Process.spawn('rake run', :out => STDOUT)
    Process.detach(pid)
    File.open(Lockfile_name, 'w') { |file| file << pid }
  end
end

task :run => 'run:development'

namespace :run do
  task :generate_keys_from_env do
    unless File.exists? 'certs/web.org.cocoapods.push-combined.pem'
      p 'Generating APNS keyfile'
      File.open 'certs/web.org.cocoapods.push-combined.pem', 'w' do |file|
        p 'Writing combined keyfile to file.'
        key = ENV['APPLE_KEY_CERT'].unescape
        file << key
      end
    end
  end

  def get_port
    port = ENV['PORT'] || 3000.to_s
    puts 'Starting server on port... ' + port
    port
  end

  desc 'Start server with SSL and dev environment'
  task :development => :generate_keys_from_env do
    #abort
    # this does not work for some reason
    Process.exec p "bundle exec puma --environment development -b \'ssl://localhost:#{get_port}?key=#{File.expand_path './certs/insec_local_ssl.pem'}&cert=#{File.expand_path './certs/insec_local_ssl.pem'}\'"
  end

  desc 'Start server without SSL in dev environment'
  task :dev_no_ssl => [:generate_keys_from_env, :pushpackage] do
    Process.exec p "bundle exec puma --environment development -p #{get_port}"
  end

  desc 'Start server in production mode without SSL for heroku'
  task :production => [:generate_keys_from_env, :pushpackage] do
    Process.exec p "bundle exec puma --environment production -t 25:200 -p #{get_port}"
  end
end

desc 'Fully regenerate push package and ensure caches are flushed'
task :pushpackage => ['pushpackage:zip', :flush]

namespace :pushpackage do

  desc 'Generate website.json from .proto'
  task :website do
    require 'json'

    website = JSON.parse File.read 'website.json.proto'

    website['webServiceURL'] = ENV['WEBSERVICE_URL'] || website['webServiceURL']

    File.open 'CocoaPods.pushpackage/website.json', 'w' do |file|
      file << JSON.generate(website)
    end
  end

  desc 'Regenerate manifest.json'
  task :manifest => :website do
    require 'openssl'
    require 'json'

    Dir.chdir 'CocoaPods.pushpackage' do |dir|
      # delete manifest
      File.delete('manifest.json') rescue nil
      manifest = Hash.new
      # create manifest hash
      file_paths = Dir['**/*']
      file_paths.delete_if { |path| Dir.exists? path or path == "signature" }
      file_paths.each do |filename|
        digest = OpenSSL::Digest::SHA1.new(File.read(filename))
        manifest[filename] = digest.to_s
      end
      # jsonize and send to file
      File.open 'manifest.json', 'w' do |file|
        file << JSON.generate(manifest)
      end
    end

  end

  desc 'Create detached signature'
  task :sign => :manifest do
    require 'openssl'

    private_key = nil
    certificate = nil

    # get the signing objects
    Dir.chdir 'certs' do |dir|
      private_key = OpenSSL::PKey::RSA.new File.read('web.org.cocoapods.push-combined.pem')
      certificate = OpenSSL::X509::Certificate.new File.read('web.org.cocoapods.push-combined.pem')
    end

    Dir.chdir 'CocoaPods.pushpackage' do |dir|
      # delete sig
      File.delete('signature') rescue nil

      File.open 'signature', 'w' do |file|
        signature = OpenSSL::PKCS7.sign(certificate, private_key, File.read('manifest.json'), [], OpenSSL::PKCS7::BINARY|OpenSSL::PKCS7::DETACHED).to_der
        file << signature
      end
    end
  end

  desc 'Zip pushpackage folder'
  task :zip => [:website, :manifest, :sign] do
    require 'zip'
    if File.exists?('CocoaPods.pushpackage.zip') then
      p 'Deleting old package'
      File.delete('CocoaPods.pushpackage.zip')
    end

    p 'Writing pushpackage'

    Zip::File.open('CocoaPods.pushpackage.zip', Zip::File::CREATE) do |package|
      Dir.chdir 'CocoaPods.pushpackage' do |dir|
        Dir['**/*'].each { |file| package.add file, File.expand_path(file) unless Dir.exists? file }
      end
    end

  end

end
