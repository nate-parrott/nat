
https://github.com/user-attachments/assets/d277496c-2d35-43ce-a354-e42fda0a47e8

# A little guy who takes on simple coding tasks for you
## Built for iOS + Mac devs, but should work for anything

### What does it do?

You give it a prompt, it explores the codebase, makes edits, and builds + tests the app to verify success.

### Usage

Run the app, enter an [OpenRouter](https://openrouter.ai) key (this makes it easier to support many different AI models)

Two modes:
1. **Normal mode**: the app asks for confirmation for edits and terminal commands. You review edits in a Github-style diff interface and approve or offer feedback. Interrupt the agent at any time. Run alongside Xcode.
2. **Worktree mode**: use [git worktree](https://stackoverflow.com/questions/31935776/what-would-i-use-git-worktree-for) to check out of a copy of your repo, works on autopilot, checks its work via tests and builds, then stops when done. Review the diff and merge. Can often get you 90% of the way there; sometimes 100%.

### Features

- [x] Chats as documents that you can save, restore and share
- [x] Read active project + file from Xcode, if open
- [x] Worktree mode for doing long-running in a separate directory on its own, then presenting a PR for review
- Models
    - [x] Claude 3.5 Sonnet
    - [x] Internal support for other models
    - [ ] UI for model selection
- Agent tools
  - [x] View files
  - [x] Code search by secondary agents that explore codebase in parallel and provide relevant snippets to the main model
  - [x] Code search via regex
  - [x] Terminal tool for running `xcodebuild`, interacting w/ `git`, and anything else
  - [x] File editing via full-file replacement, find/replace,
    - [x] Syntax check post-apply (Swift only)
    - [x] "Applier model" for using a faster model to apply edits via full file rewrite if find/replace fails
  - [x] Web research via Perplexity
  - [ ] Code search via vector store + SQLite FTS index
  - [ ] Ability to test an app via Claude Computer Use (system wide or via `simctl`)
  - [ ] Tool to _find usages_ and _find definition_ via tree-sitter or SourceKit LSP
- Documentation Scratchpad
    - [x] In-app ui for editing documentation that the model can use (in `nat_docs/`)
    - [ ] Tooling to allow model to automatically generate complex docs to improve
- [x] Code search UI (in toolbar)
- [x] Autopilot toggle (running person in bottom bar) to toggle autoconfirm for file edits + terminal (default on in Worktree mode)

**Future Ideas**

- Beyond chat: what the interface for requesting changes was a rich _design doc_ for features you want implemented, with lists of reference materials, tasks, images and diagrams, which updated live as the agent performed various tasks?
- Complex batch workflows: for example, can I have several LLMs traverse my entire codebase to perform a large refactor in parallel, like making my app internationalized? 
- Claude Computer Use for running + testing apps
- Integration with [42pag.es](https://42pag.es) to let you sketch visual designs and turn them into pixel-perfect code
- Better quality + reliability!
- Ability to enqueue a task from your phone and review the PR remotely
- Let Nat handle its own releases (archive + notarization + uploading)
- Whisper dictation for natural input

### Developing

Clone this repo, and also clone [chattoys](https://github.com/nate-parrott/chattoys). Place it in an adjacent folder (i.e. clone both this project and chattoys in the same folder). You may periodically need to pull changes from there, too.
