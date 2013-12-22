class String
 def escape
   self.dump[1..-2]
 end

 def unescape
   eval %Q{"#{self}"}
 end
end

HEROKU_WEBSERVICE_URL = 'https://cocoapush.herokuapp.com/push'
VERSION = 'v1'
NOTIF_EXTENSION_SUBROUTE = 'push'
WEBSITE_PUSH_ID = 'web.org.cocoapods.push'
