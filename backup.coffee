Flickr = require("flickr").Flickr

consumerKey = process.argv[2]
consumerSecret = process.argv[3]
oauthToken = process.argv[4]
oauthTokenSecret = process.argv[5]

client = new Flickr(consumerKey, consumerSecret, {"oauth_token": oauthToken, "oauth_token_secret": oauthTokenSecret})

client.executeAPIRequest "flickr.contacts.getList", {}, true, (err, data) ->
	if err
		console.log err
	else
		console.log data
