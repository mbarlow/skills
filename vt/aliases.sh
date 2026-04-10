# vt skill — shell aliases
# Source this from ~/.bashrc (or ~/.zshrc):
#   source ~/git/github.com/mbarlow/skills/vt/aliases.sh

# Switch Linux virtual terminals — `vt 3` jumps to TTY3, `vt 1` back to the
# graphical session. Requires the NOPASSWD sudoers rule installed by
# install.sh (see README.md).
alias vt='sudo chvt'
