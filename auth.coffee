app = require("express").createServer()

consumerKey = process.argv[2]
consumerSecret = process.argv[3]

oauthToken = ""
oauthTokenSecret = ""

OAuth = require('oauth').OAuth;
oa = new OAuth("http://www.flickr.com/services/oauth/request_token",
                 "http://www.flickr.com/services/oauth/access_token", 
                 consumerKey, consumerSecret, 
                 "1.0A", "http://localhost:3000/oauth/callback", "HMAC-SHA1")

app.get '/oauth/callback', (req, res) ->
  console.log "OAuth token: #{req.query.oauth_token}"
  console.log "OAuth verifier: #{req.query.oauth_verifier}"
  res.send "Gooooood"

  oa.getOAuthAccessToken oauthToken, oauthTokenSecret, req.query.oauth_verifier, (err, oauth_token, oauth_token_secret, results) ->
    if err
      console.error "Error while getting access token"
      console.error err
    else
      console.log "OAuth access token: #{oauth_token}"
      console.log "OAuth access token secret: #{oauth_token_secret}"
      console.log "OAuth access token results:"
      console.log results

      console.log "Verification succeeded"
      console.log "OAuth token: #{oauthToken}"
      console.log "OAuth token secret: #{oauthTokenSecret}"


app.listen 3000

oa.getOAuthRequestToken (err, oauth_token, oauth_token_secret, results) ->
  if err
    console.error "Error while getting request token"
    console.error err
  else
    console.log "OAuth request token: #{oauth_token}"
    console.log "OAuth request token secret: #{oauth_token_secret}"
    console.log "OAuth request token results:"
    console.log results
    oauthToken = oauth_token
    oauthTokenSecret = oauth_token_secret

    console.log "Please visit http://www.flickr.com/services/oauth/authorize?oauth_token=#{oauth_token}&perms=read"