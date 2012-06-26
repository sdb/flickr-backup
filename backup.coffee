fs = require "fs"
path = require "path"
url = require "url"
http = require "http"
Flickr = require("flickr").Flickr
async = require "async"
_ = require "underscore"
_.str = require "underscore.string"
confPath = process.argv[2] or "./config.json"
conf = require confPath

backupPath = path.resolve (conf.path or "./backup")

class Log
  constructor: () ->
    @file = fs.createWriteStream (path.join backupPath, "log.txt")

  success: (from, to) ->
    @copy from, to

  failure: (from, to) ->
    @copy from, to, true

  copy: (from, to, fail) ->
    msg = _.str.sprintf "%s: %s <- %s\n", (if fail then "FAILURE" else "SUCCESS"), (path.relative backupPath, to), from 
    @file.write msg

  close: () ->
    @file.end()

client = new Flickr(conf.consumerKey, conf.consumerSecret, {"oauth_token": conf.oauthToken, "oauth_token_secret": conf.oauthTokenSecret})
log = null

paged = (method, params, signedIn, node, subNode, page, perPage, callback, objects) =>
  p = _.extend params, {page: page, per_page: perPage}
  client.executeAPIRequest method, p, signedIn, (err, data) ->
    if err
      console.error "Error on #{method}"
      callback err
    else
      data = data[node]
      page = parseInt data.page
      pages = data.pages
      if not objects
        objects = []
      objects = objects.concat data[subNode]
      if page < pages
        paged method, params, signedIn, node, subNode, page + 1, perPage, callback, objects
      else
        callback null, objects

getPhotosets = (callback) ->
  paged "flickr.photosets.getList", {}, true, "photosets", "photoset", 1, 100, callback

getPhotosInPhotoset = (id, callback) ->
  paged "flickr.photosets.getPhotos", {photoset_id: id, extras: "url_o,original_format"}, true, "photoset", "photo", 1, 100, callback

getPhotos = (sets, callback) ->
  clb = (photos, set, cb) ->
    getPhotosInPhotoset set.id, (err, data) ->
      photos.push {title: set.title._content, photos: data}
      cb null, photos
  async.reduce sets, [], clb, callback

getAllPhotosInSets = (callback) -> async.waterfall [getPhotosets, getPhotos], callback

getAllPhotosNotInSets = (callback) ->
  paged "flickr.photos.getNotInSet", {extras: "url_o,original_format"}, true, "photos", "photo", 1, 100, (err, data) ->
    if err
      callback(err)
    else
      callback null, {title: "Not in set", photos: data}

getAllPhotos = (callback) ->
  console.info "Retrieving the URL's for all photos."
  async.series [getAllPhotosInSets, getAllPhotosNotInSets], callback

saveSet = (set, callback) ->
  setup = (cb) ->
    p = path.join backupPath, set.title
    console.info "Creating directory '#{p}' for set '#{set.title}'."
    fs.mkdir p, (err) ->
      if err
        cb err
      else
        console.info "Directory '#{p}' created successfully."
        cb null, p
  saveNow = (p, cb) ->
    savePhoto = (photo, cb) ->
      uri = url.parse photo.url_o
      name = photo.id + (if photo.title then " - " + photo.title else "")
      fp = path.normalize (p + "/" + name + "." + photo.originalformat)
      f = fs.createWriteStream(fp)
      options = {
          host: uri.host
          port: 80
          path: uri.pathname
      }
      f.on "close", () ->
        log.success uri.href, fp
        console.info "Copied '#{path.relative backupPath, fp}'."
        cb null
      http.get(options, (res) ->
        res.on "data", (d) -> f.write d
        res.on "end", () ->
          f.end()
      ).on "error", (e) ->
        log.fail uri.href, fp
        cb null
    async.forEachLimit set.photos, 10, savePhoto, cb
  async.waterfall [setup, saveNow], callback

saveAllPhotos = (sets, callback) ->
  console.info "Saving #{sets[0].length} sets and #{sets[1].photos.length} photos not in sets."
  sets = sets[0].concat [sets[1]]
  async.forEachLimit sets, 5, saveSet, callback

setup = (callback) ->
  console.info "Creating download directory '#{backupPath}'."
  fs.mkdir backupPath, (err) ->
    if err
      console.error "FAILED: Creating download directory '#{backupPath}'."
      callback err
    else
      console.info "Download directory '#{backupPath}' created successfully."
      log = new Log
      callback null

async.waterfall [setup, getAllPhotos, saveAllPhotos], (err, sets) ->
  if err
    console.error "Failed!"
    console.error err
  else
    log.close()
    console.info "Finished!"