#Serves Safari Push Notifications for CocoaPods Users

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
