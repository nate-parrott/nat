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



### Developing

Clone this repo, and also clone [chattoys](https://github.com/nate-parrott/chattoys). Place it in an adjacent folder (i.e. clone both this project and chattoys in the same folder). You may periodically need to pull changes from there, too.


