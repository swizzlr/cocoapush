desc 'Bundle what?'
task :bootstrap do
  `bundle install`
end

desc 'Fully regenerate push package'
task :pushpackage => 'pushpackage:zip'

namespace :pushpackage do
  desc 'Regenerate manifest.json'
  task :manifest do
    require 'openssl'
    require 'json'

    Dir.chdir 'CocoaPods.pushpackage' do |dir|
      # delete manifest
      File.delete('manifest.json') rescue nil
      manifest = Hash.new
      # create manifest hash
      file_paths = Dir['**/*']
      file_paths.delete_if { |path| Dir.exists? path || path == 'signature' }
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
  task :zip => [:manifest, :sign] do
    require 'zip'
    File.delete('CocoaPods.pushpackage.zip')
    Zip::File.open('CocoaPods.pushpackage.zip', Zip::File::CREATE) do |package|
      Dir.chdir 'CocoaPods.pushpackage' do |dir|
        Dir['**/*'].each { |file| package.add file, File.expand_path(file) unless Dir.exists? file }
      end
    end

  end

end
