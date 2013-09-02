

# Installing dependencies (OSX)

To build `nodegit` you will need:

- `brew install cmake libzip`
- `npm install -g node-gyp`

You can try to add `"nodegit": "git://github.com/nodegit/nodegit.git#wip",` to `package.json` (under `dependencies`) but if it does not work, you may need to manually install `nodegit`.
Here are the steps I've found that work for me:

1. `cd ./node_modules && git clone https://github.com/nodegit/nodegit.git && cd ./nodegit && git checkout origin/wip`
2. `npm install` (This will error when trying to link `zlib.dynlib`)
3. `node install` (This will error and say `/bin/sh: node-gyp: command not found`)
4. `npm install` (again, but this time it will succeed)
5. `cd ../../` (Switch back to the root)

# Start the server

`node test-server/index.js`

If you want to change the Git Repo that is being used (you probably do), change the `REPO_PATH` in `server.coffee`

To verify it is running go to http://localhost:3000/repos/DUMMY_REPO_USER/DUMMY_REPO_NAME/git/trees/DUMMY_REPO_BRANCH


# Configure the github-book editor

Inside https://github.com/oerpub/github-book/blob/github-refactor-oerpub/scripts/gh-book/session.coffee#L17 add the following line:

    repoURL: 'http://localhost:3000'

That way the editor will use localhost instead of `https://api.github.com`
