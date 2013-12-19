require './helpers.rb'

desc 'Bundle what?'
task :bootstrap do
  `bundle install`
end

desc 'Generate .env file from private keys and sync to heroku'
task :generate_env do
  File.open '.env', 'w' do |env|
    env << 'SSL_KEY=' + File.read('certs/org.cocoadocs.push-key.pem').escape + "\n"
    env << 'SSL_CERT=' + File.read('certs/org.cocoadocs.push-key.pem').escape + "\n"
    env << 'APPLE_KEY=' + File.read('certs/web.org.cocoapods.push-key.pem').escape + "\n"
    env << 'APPLE_CERT=' + File.read('certs/web.org.cocoapods.push-cert.pem').escape + "\n"
    env << 'PORT=' + 9578.to_s + "\n"
    env << 'WEBSERVICE_URL=' + 'https://localhost:9578/push' + "\n"
  end
  `heroku config:push -o`
  `heroku config:set WEBSERVICE_URL=https://cocoapush.herokuapps.com/push`
end

desc 'Watch for changes and restart server when necessary.'
task :kick => 'kick:kicker'

namespace :kick do
  lockfile_name = '.server_running_lockfile'

  task :kicker => :run_or_restart_server do
    puts 'Starting kicker'
    Process.exec('bundle exec kicker')
  end

  task :run_or_restart_server do #all kicking logic is found in the rakefile. because reasons.
    puts 'Checking for running server...'
    if File.exists?(lockfile_name)
      puts 'Killing server...'
      Process.kill('KILL', File.read(lockfile_name).to_i) rescue nil
      File.delete(lockfile_name)
    end
    puts 'Spawning rake task'
    pid = Process.spawn('rake run', :out => STDOUT)
    Process.detach(pid)
    File.open(lockfile_name, 'w') { |file| file << pid }
  end
end

task :run => 'run:development'

namespace :run do
  task :generate_keys_from_env do
    unless File.exists? 'certs/org.cocoadocs.push-key.pem'
      p 'Generating SSL keyfile'
      File.open 'certs/org.cocoadocs.push-key.pem', 'w' do |file|
        p 'Loading key...'
        key = ENV['SSL_KEY'].unescape
        p key
        file << key
      end
    end

    unless File.exists? 'certs/web.org.cocoapods.push-key.pem'
      p 'Generating APNS keyfile'
      File.open 'certs/web.org.cocoapods.push-key.pem', 'w' do |file|
        p 'Loading key...'
        key = ENV['APPLE_KEY'].unescape
        p key
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
    Process.exec("bundle exec thin --ssl --ssl-key-file certs/org.cocoadocs.push-key.pem --ssl-cert-file certs/org.cocoadocs.push-cert.pem --environment development -p #{get_port} start")
  end

  desc 'Start server in production mode without SSL for heroku'
  task :production => [:generate_keys_from_env, :pushpackage] do
    Process.exec("bundle exec thin --environment production -p #{get_port} start")
  end
end

desc 'Fully regenerate push package'
task :pushpackage => 'pushpackage:zip'

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
      file_paths.delete_if { |path| Dir.exists? path || path == 'signature' || path == '*.proto' }
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
      private_key = OpenSSL::PKey::RSA.new File.read('web.org.cocoapods.push-key.pem')
      certificate = OpenSSL::X509::Certificate.new File.read('web.org.cocoapods.push-cert.pem')
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

    p 'Regenerating pushpackage'

    if File.exists?('CocoaPods.pushpackage.zip') then
      p 'Deleting package'
      File.delete('CocoaPods.pushpackage.zip')
    end
    Zip::File.open('CocoaPods.pushpackage.zip', Zip::File::CREATE) do |package|
      Dir.chdir 'CocoaPods.pushpackage' do |dir|
        Dir['**/*'].each { |file| package.add file, File.expand_path(file) unless Dir.exists? file }
      end
    end

  end

end
