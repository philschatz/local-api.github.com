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


FILEMODE_LOOKUP =
  '100644': 33188


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
    res.header('Access-Control-Allow-Methods', 'GET, PUT, POST, PATCH, DELETE')
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
    (res.status(403, error); return) if error

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
        (res.status(403, error); return) if error

        branch.getTree (error, tree) ->
          (res.status(403, error); return) if error

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
                mode: entry.filemode()

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
        (res.status(403, error); return) if error

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

    app.get '/repos/:repoUser/:repoName/git/refs/:headsOrTags/:refName', (req, res) ->
      refName = 'refs/heads/master' # "refs/#{req.params.headsOrTags}/#{req.params.repoBranch}"

      repo.getReference refName, (error, reference) ->
        (res.status(403, error); return) if error

        res.send
          ref: refName
          object:
            sha: reference.target().sha()
            type: 'branch'


    app.post '/repos/:repoUser/:repoName/git/blobs', (req, res) ->
      # JSON body is of the form:
      #
      #    { content: '...', encoding: 'utf-8' or 'base64' }
      #
      body = req.body

      buffer = new Buffer(body.content, body.encoding)
      repo.createBlobFromBuffer buffer, (err, oid) ->
        (res.status(403, error); return) if error
        res.send {sha: oid.sha()}


    app.post '/repos/:repoUser/:repoName/git/trees', (req, res) ->
      body = req.body

      (res.status(403, 'ERROR: For now, sha is required'); return) if not body.base_tree
      baseOid = Git.Oid.fromString(body.base_tree)

      repo.getCommit baseOid, (error, commit) -> # TODO: should be smart if a commit is passed in as base_tree
        (res.status(403, error); return) if error

        repo.getTree commit.treeId(), (error, tree) ->
          (res.status(403, error); return) if error

          # Build a tree based on base_tree
          builder = tree.builder()

          for entry in body.tree
            oid = Git.Oid.fromString(entry.sha)
            builder.insert(entry.path, oid, FILEMODE_LOOKUP[entry.mode])

          builder.write (error, oid) ->
            (res.status(403, error); return) if error
            res.send {sha:oid.sha()}

    app.post '/repos/:repoUser/:repoName/git/commits', (req, res) ->
      body = req.body

      makeSignature = (obj) ->
        name = obj?.name or 'DUMMY_NAME'
        email = obj?.email or 'DUMMY_EMAIL'
        if obj?.date
          time = new Date(obj.date)
        else
          time = new Date()
        time = time.getTime() / 1000 # Convert to seconds
        time = parseInt(time)
        offset = 0
        return Git.Signature.create(name, email, time, offset)

      updateRef = null
      author = makeSignature(body.author)
      committer = makeSignature(body.committer)
      messageEncoding = 'utf-8'
      message = body.message
      tree = Git.Oid.fromString(body.tree)
      # Assume at most 1 parent
      (res.status(403, 'ERROR: Exactly 1 parent assumed'); return) if !body.parents or body.parents.length != 1

      parentSha = body.parents[0]
      parentOid = Git.Oid.fromString(parentSha)

      repo.getCommit parentOid, (error, parentCommit) ->
        (res.status(403, error); return) if error

        # Assume 1 parent. Otherwise we need to look up all of them
        parents = [parentCommit]

        repo.createCommit updateRef, author, committer, message, tree, parents, (error, oid) ->
          (res.status(403, error); return) if error

          res.send {sha:oid.sha()}


    app.patch '/repos/:repoUser/:repoName/git/refs/:headsOrTags/:refName', (req, res) ->
      sha = req.body.sha
      oid = Git.Oid.fromString(sha)

      refName = 'refs/heads/master' # "refs/#{req.params.headsOrTags}/#{req.params.refName}"


      repo.getCommit oid, (error, commit) ->
        (res.status(403, error); return) if error

        newRef = repo.createReference refName, oid, 1

        if newRef
          res.send
            ref: refName
            object:
              type: commit
              sha: commit.oid().sha()
        else
          (res.status(403, 'ERROR: Could not change ref'); return)


    #### Start the server ####
    server = app.listen 3000, null, ->
      app.emit 'listening'
      loga "Server listening on", 3000, "in mode:", app.settings.env

  # Return app when called, so that it can be watched for events and shutdown with .close() externally.
  app

