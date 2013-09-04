# # Dependencies
# anything not in the standard library is included in the repo, or
# can be installed with an:
#
#     npm install

# Standard lib
fs = require 'fs'
path = require 'path'
http = require 'http'

# From npm
_ = require 'underscore'
express = require 'express'
Git = require 'nodegit'


REPO_PATH = path.resolve(__dirname, '../.git')


# Set export objects for node and coffee to a function that generates a server.
module.exports = exports = (argv) ->

  # Create the main application object, app.
  app = express()

  app.startOpts = do ->
    options = {}
    for own k, v of argv
      options[k] = v
    options

  log = (stuff...) ->
    console.log stuff if argv.debug

  loga = (stuff...) ->
    console.log stuff

  errorHandler = (req, res, next) ->
    fired = false
    res.e = (error, status) ->
      if !fired
        fired = true
        res.statusCode = status or 500
        res.end 'Server ' + error
        log "Res sent:", res.statusCode, error
      else
        log "Allready fired", error
    next()

  #### Middleware ####
  #
  # Allow json to be got cross origin.
  cors = (req, res, next) ->
    res.header('Access-Control-Allow-Origin', '*')
    res.header('Access-Control-Allow-Headers', 'If-Modified-Since, Authorization, Content-Type')
    next()



  #### Express configuration ####
  # Set up all the standard express server options,
  # including hbs to use handlebars/mustache templates
  # saved with a .html extension, and no layout.
  app.configure ->
    app.use(express.cookieParser())
    app.use(express.bodyParser())
    app.use(express.methodOverride())
    app.use(express.session({ secret: 'notsecret'}))
    app.use(errorHandler)
    app.use(app.router)

  ##### Set up standard environments. #####
  # In dev mode turn on console.log debugging as well as showing the stack on err.
  app.configure 'development', ->
    app.use(express.errorHandler({ dumpExceptions: true, showStack: true }))
    argv.debug = console? and true

  # Show all of the options a server is using.
  log argv

  # Swallow errors when in production.
  app.configure 'production', ->
    app.use(express.errorHandler())

  # Load up the repo
  Git.Repo.open REPO_PATH, (error, repo) ->

    console.log(error)
    throw error if error

    #### Routes ####
    # Routes currently make up the bulk of the Express port of
    # Smallest Federated Wiki. Most routes use literal names,
    # or regexes to match, and then access req.params directly.

    # Enable CORS for all routes
    app.all '*', cors

    ##### Get routes #####
    app.get '/zen', (req, res) -> res.send('Server is up!')

    app.get '/user', (req, res) ->
      res.send {login: 'TEST_USER'}

    app.get '/repos/:repoUser/:repoName/collaborators/:userId', (req, res) ->
      res.status(204).send()

    app.get '/repos/:repoUser/:repoName', (req, res) ->
      res.send({master_branch: 'master'})

    app.get '/repos/:repoUser/:repoName/git/trees/:repoBranch', (req, res) ->

      #repo.getBranch 'master', (error, branch) ->
      repo.getMaster (error, branch) ->
        throw error if error

        branch.getTree (error, tree) ->
          throw error if error

          entries = []
          # Always return recursive (by walking the tree)

          # `walk()` returns an event.
          walker = tree.walk(true) # true == blobsOnly
          walker.on 'entry', (entry) ->
            if entry.isFile()
              entries.push
                type: 'blob' # File
                path: entry.path()
                sha: entry.oid().sha()
                #mode: entry.filemode()

          walker.on 'end', () ->
            res.send {
              sha: tree.oid().sha()
              tree: entries
            }

          # Don't forget to call `start()`!
          walker.start()


    app.get '/repos/:repoUser/:repoName/git/blobs/:blobSha', (req, res) ->
      # Assume 'application/vnd.github.raw' is passed in (so respond with raw data)
      oid = Git.Oid.fromString(req.params.blobSha)

      repo.getBlob oid, (error, blob) ->
        throw error if error

        res.send(blob.content())
        # res.send {
        #   content: blob.content()
        #   encoding: 'utf-8'
        #   sha: blob.oid().sha()
        #   size: blob.size()
        # }


    app.get '/repos/:repoUser/:repoName/commits', (req, res) ->
      sha = req.query.sha

      res.send([]) # TODO: Figure out how to list the most recent commits in a repo


    # app.get ///^((/[a-zA-Z0-9:.-]+/[a-z0-9-]+(_rev\d+)?)+)/?$///, (req, res) ->
    #   urlPages = (i for i in req.params[0].split('/') by 2)[1..]
    #   urlLocs = (j for j in req.params[0].split('/')[1..] by 2)
    #   info = {
    #     pages: []
    #     authenticated: req.isAuthenticated()
    #     loginStatus: if owner
    #       if req.isAuthenticated()
    #         'logout'
    #       else 'login'
    #     else 'claim'
    #   }
    #   for page, idx in urlPages
    #     if urlLocs[idx] is 'view'
    #       pageDiv = {page}
    #     else
    #       pageDiv = {page, origin: """data-site=#{urlLocs[idx]}"""}
    #     info.pages.push(pageDiv)
    #   res.render('static.html', info)

    # app.get ///([a-z0-9-]+)\.html$///, (req, res, next) ->
    #   file = req.params[0]
    #   log(file)
    #   if file is 'runtests'
    #     return next()
    #   pagehandler.get file, (e, page, status) ->
    #     if e then return res.e e
    #     if status is 404
    #       return res.send page, status
    #     info = {
    #     	pages: [
    #     	  page: file
    #     	  generated: """data-server-generated=true"""
    #     	  story: wiki.resolveLinks(render(page))
    #     	]
    #     	authenticated: req.isAuthenticated()
    #     	loginStatus: if owner
    #     	  if req.isAuthenticated()
    #     	    'logout'
    #     	  else 'login'
    #     	else 'claim'
    #     }
    #     res.render('static.html', info)

    # app.get ///system/factories.json///, (req, res) ->
    #   res.status(200)
    #   res.header('Content-Type', 'application/json')
    #   glob path.join(argv.c, 'plugins', '*', 'factory.json'), (e, files) ->
    #     if e then return res.e(e)
    #     files = files.map (file) ->
    #       return fs.createReadStream(file).on('error', res.e).pipe(JSONStream.parse())

    #     es.concat.apply(null, files)
    #       .on('error', res.e)
    #       .pipe(JSONStream.stringify())
    #       .pipe(res)


    # ###### Json Routes ######
    # # Handle fetching local and remote json pages.
    # # Local pages are handled by the pagehandler module.
    # app.get ///^/([a-z0-9-]+)\.json$///, (req, res) ->
    #   file = req.params[0]
    #   pagehandler.get file, (e, page, status) ->
    #     if e then return res.e e
    #     res.send(status or 200, page)

    # # Remote pages use the http client to retrieve the page
    # # and sends it to the client.  TODO: consider caching remote pages locally.
    # app.get ///^/remote/([a-zA-Z0-9:\.-]+)/([a-z0-9-]+)\.json$///, (req, res) ->
    #   remoteGet req.params[0], req.params[1], (e, page, status) ->
    #     if e
    #       log "remoteGet error:", e
    #       return res.e e
    #     res.send(status or 200, page)


    # # Redirect remote favicons to the server they are needed from.
    # app.get ///^/remote/([a-zA-Z0-9:\.-]+/favicon.png)$///, (req, res) ->
    #   remotefav = "http://#{req.params[0]}"

    #   res.redirect(remotefav)

    # ###### Meta Routes ######
    # # Send an array of pages in the database via json
    # app.get '/system/slugs.json', (req, res) ->
    #   fs.readdir argv.db, (e, files) ->
    #     if e then return res.e e
    #     res.send(files)

    # app.get '/system/plugins.json', (req, res) ->
    #   fs.readdir path.join(argv.c, 'plugins'), (e, files) ->
    #     if e then return res.e e
    #     res.send(files)

    # app.get '/system/sitemap.json', (req, res) ->
    #   pagehandler.pages (e, sitemap) ->
    #     return res.e(e) if e
    #     res.json(sitemap)

    # ##### Put routes #####

    # app.put /^\/page\/([a-z0-9-]+)\/action$/i, (req, res) ->
    #   action = JSON.parse(req.body.action)
    #   # Handle all of the possible actions to be taken on a page,
    #   actionCB = (e, page, status) ->
    #     #if e then return res.e e
    #     if status is 404
    #       res.send(page, status)
    #     # Using Coffee-Scripts implicit returns we assign page.story to the
    #     # result of a list comprehension by way of a switch expression.
    #     try
    #       page.story = switch action.type
    #         when 'move'
    #           action.order.map (id) ->
    #             page.story.filter((para) ->
    #               id == para.id
    #             )[0] or throw('Ignoring move. Try reload.')

    #         when 'add'
    #           idx = page.story.map((para) -> para.id).indexOf(action.after) + 1
    #           page.story.splice(idx, 0, action.item)
    #           page.story

    #         when 'remove'
    #           page.story.filter (para) ->
    #             para?.id != action.id

    #         when 'edit'
    #           page.story.map (para) ->
    #             if para.id is action.id
    #               action.item
    #             else
    #               para


    #         when 'create', 'fork'
    #           page.story or []

    #         else
    #           log "Unfamiliar action:", action
    #           page.story
    #     catch e
    #       return res.e e

    #     # Add a blank journal if it does not exist.
    #     # And add what happened to the journal.
    #     if not page.journal
    #       page.journal = []
    #     if action.fork
    #       page.journal.push({type: "fork", site: action.fork})
    #       delete action.fork
    #     page.journal.push(action)
    #     pagehandler.put req.params[0], page, (e) ->
    #       if e then return res.e e
    #       res.send('ok')
    #       log 'saved'

    #   log action
    #   # If the action is a fork, get the page from the remote server,
    #   # otherwise ask pagehandler for it.
    #   if action.fork
    #     remoteGet(action.fork, req.params[0], actionCB)
    #   else if action.type is 'create'
    #     # Prevent attempt to write circular structure
    #     itemCopy = JSON.parse(JSON.stringify(action.item))
    #     pagehandler.get req.params[0], (e, page, status) ->
    #       if e then return actionCB(e)
    #       unless status is 404
    #         res.send('Page already exists.', 409)
    #       else
    #         actionCB(null, itemCopy)

    #   else if action.type == 'fork'
    #     if action.item # push
    #       itemCopy = JSON.parse(JSON.stringify(action.item))
    #       delete action.item
    #       actionCB(null, itemCopy)
    #     else # pull
    #       remoteGet(action.site, req.params[0], actionCB)
    #   else
    #     pagehandler.get(req.params[0], actionCB)


    # # Return the oops page when login fails.
    # app.get '/oops', (req, res) ->
    #   res.statusCode = 403
    #   res.render('oops.html', {msg:'This is not your wiki!'})

    # # Traditional request to / redirects to index :)
    # app.get '/', (req, res) ->
    #   res.redirect(index)

    #### Start the server ####
    server = app.listen 3000, null, ->
      app.emit 'listening'
      loga "Server listening on", 3000, "in mode:", app.settings.env

  # Return app when called, so that it can be watched for events and shutdown with .close() externally.
  app

