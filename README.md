
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



Status of "Simulating https://api.github.com locally with a webserver":

- `[x]` read text files from the default branch of a git Repo
- `[x]` get the editor to load all text files (OPF, HTML, META-INF/container.xml)
- `[x]` simulate responses that do not involve the repo (who am I, do I have permission)
- `[.]` read binary files
- `[.]` post a new blob
- `[.]` post a new commit
- `[.]` update head reference
- `[ ]` error if the head update is a non fast-forward commit
- `[ ]` get the latest commits to a repo

Legend: `[x]` means "Coded and Works!", `[.]` means "Possible but not coded yet", and `[ ]` means "Not sure if git library supports it"
