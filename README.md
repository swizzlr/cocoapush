[![Code Climate](https://codeclimate.com/github/swizzlr/cocoapush.png)](https://codeclimate.com/github/swizzlr/cocoapush)

#Serves Safari Push Notifications for CocoaPods Users

##Getting started

Clone the repository.

It should run without Rubinius, that's just for performance on Heroku, but if you want to have that too, you'll need to install it with RVM. I recommend using the latest RVM through `rvm get head` since rbx support is kinda new.

`rvm install rbx-2.2.3`

Documentation for how to run it under rbenv is welcome!

Finally, run `rake bootstrap`. Follow the instructions about getting mongodb and memcached running.

##Running locally

To make it all work properly you'll need to decrypt the key package provided in certs/, so send me@swizzlr.co including your PGP public key or ask me on the Campfire for the passphrase.

When you have it, you'll want to `rake convert[passphrase]`. This will generate a key/cert file in *plaintext*. Thankfully, I can always revoke it, and it isn't guarding state secrets.

Now if you intend to use `foreman` you need to `rake generate_env`. This makes a .env file and tries to sync it to Heroku. If you don't have a Heroku instance setup, it'll just make the .env and throw some errors.

Finally, just type `rake run`. This will regenerate the pushpackage and run the server. Hit it with requests using `paw-push.paw` (it's a neat app).

`rake kick` will run or relaunch the server on changes to files, if you're into that.

###Caveats
Safari requires HTTPS to communicate with a push service. For some obscure reason I cannot get this to work locally. I'm looking into replacing puma's version with rack_ssl but it might be a while. In the meantime, use the Safari group in the .paw file to pretend to register for push notifications on the server. You'll probably end up with a user by the id of 'DEVICE\_TOKEN\_GOES\_HERE'. Then just hit it with some fake requests and it'll register your interest. You can debug the DB with `mongo` at the shell. You can send a fake github webhook too, though since you won't have your actual device tokens you won't be in much luck, until you can get SSL running locally.

At this point, I'm pretty much debugging online on Heroku. Let me know if you want admin access.

##Public-ish API
Two methods to update and retrieve. These are dumb and perform little to no validation, yet. They just send back whatever you've previously stored that the app knows about: right now, that's an object with a 'pods' key.

`GET /push/v1/settingsForDeviceToken/:device_token`

`POST /push/v1/settingsForDeviceToken/:device_token`

##If you want it to work

```
{
	"pods" : [
		"AFNetworking",
		"ReactiveCocoa"
	]
}
```

Later on I want to add "saved search", so it will look through the podspec's description and notify you of any new (only) pods which match your saved search.

#The Notifications
Right now it does a very dumb "'Pod Name' has been updated." notification with a link to the podspec.

Later on I want it to go to the pod URL/social if missing. Since APNs has a tight byte limit we can put a format string in the pushpackage but updating it is basically impossible AFAIK so what I'm about to do is put a Sinatra route with a wildcard final component that we can give short IDs to, store them in a DB and then redirect to whatever. Right now it'll redirect to the podspec blob.

The notifications are implemented by a github webhook on the specs repo (thanks, @SmileyKeith!) that scans for updated paths, strips out the `.podspec` and then looks up interested parties in the database. What it really needs to do is go download the Podspec using the Github blob API, parse it out using a module of CocoaPods-Core, compare to previous version in DB (so commits fixing a podspec won't trigger a notif. or might.?), store, build a notification with the name, store the URL with a short ID to a mongo collection, and push.
