
# Gitrelief

Gitrelief is a git-client that provides various views into a repository as an http-server.
It offers

* status-view
* log-view
* branches-view
* diff-view
* follow-view

## Usage

Launch the server in the root of a git-repository

    gitrelief [--port 8081] [--name demo]

The default port is 8080, the default name (used for page titles) is 'gitrelief'.
View localhost:&lt;port&gt; in a browser.

# Build

    git submodule init
    git submodule update
    nim server                                    (build server in preconfigured directory, defaults to ./bb/)
    nim starter                                   (GUI helper, Linux/gtk3)

To configure the build-directory, set environment variable OUTDIR, e.g. OUTDIR=~/.local/bin/.

# Development status

Only tested on Linux. The server should run on Windows too.

Gitrelief is a robust server.
It serves html-files that do not use javascript, but contain many useful links.

Gitreliefstarter is work in progress.
It is intended for scenarios that involve several repositories. e.g. worktrees.
Saving the settings for each repository/worktree allows a robust workflow.
