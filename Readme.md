
# Gitrelief

Gitrelief is a git-client that provides various views into a repository as an http-server.
It offers a number of views:

* status
* log (includes affected paths and complete log-message)
* branches (relationship between selectable branches)
* diff (Side-by-side view of before/after changes)
* follow (Show only commits that affected a particular file or directory)

Currently, stage/unstage in the status view are the only links
that change the state of the repository. Everything else is
a display of current state.

If the repository contains a directory 'public', the server will offer to
serve contained html-files as they are. This is useful to pin views, e.g.
of specific commits.

## Usage

Launch the server in the root of a git-repository

    gitrelief [--port 8081] [--name demo]

The default port is 8080, the default name (used for page titles) is 'gitrelief'.
View localhost:&lt;port&gt; in a browser.

# Build

    git submodule init
    git submodule update
    nim server                 (build server in preconfigured directory, defaults to ./bb/)

To configure the build-directory, copy config.cfg.template to config.cfg,
enter the desired path in config.cfg ([Build]/OUTDIR). OUTDIR defaults to ./bb/.

# Development status

Built with Nim 2.2.6 on Linux and Windows 11.

**Gitrelief** is a robust server.
It serves html-files that do not use javascript, but contain many useful
links to context-specific views. Runs on Linux and Windows.
