#!/bin/sh

# ./setup.sh

# - Installs homebrew and all related apps
# - Tested on macOS Big Sur (11.0)

set -eux

#------------------------------------------------------------------------------
# Homebrew and packages
HOMEBREW_PREFIX="/usr/local"

if [ -d "$HOMEBREW_PREFIX" ]; then
  if ! [ -r "$HOMEBREW_PREFIX" ]; then
    sudo chown -R "$LOGNAME:admin" "$HOMEBREW_PREFIX"
  fi
else
  sudo mkdir "$HOMEBREW_PREFIX"
  sudo chflags norestricted "$HOMEBREW_PREFIX"
  sudo chown -R "$LOGNAME:admin" "$HOMEBREW_PREFIX"
fi

if ! command -v brew >/dev/null; then
  curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install.sh | bash
  export PATH="/usr/local/bin:$PATH"
fi

brew analytics off
brew update
brew bundle -v --no-lock --file=- <<EOF
  tap "heroku/brew"
  tap "homebrew/cask-fonts"
  tap "homebrew/services"

  brew "awscli"
  brew "nvm"
  brew "git"
  brew "docker-compose"
  brew "curl"
  brew "direnv"

  cask "iterm2"
  cask "docker"
  cask "the-unarchiver"
EOF

brew cask install font-envy-code-r-for-powerline.rb

brew upgrade
brew cleanup

#------------------------------------------------------------------------------
# Set preferences
$PWD/dotfiles/macprefs

#------------------------------------------------------------------------------
# Shell
update_shell() {
  (
    sudo chown -R $(whoami) /usr/local/share/fish
    chmod u+w /usr/local/share/fish
  )

  local shell_path;
  shell_path="$(command -v fish)"

  if ! grep "$shell_path" /etc/shells > /dev/null 2>&1 ; then
    sudo sh -c "echo $shell_path >> /etc/shells"
  fi
  chsh -s "$shell_path"
}

case "$SHELL" in
  */fish)
    if [ "$(command -v fish)" != "$HOMEBREW_PREFIX/bin/fish" ] ; then
      update_shell
    fi
    ;;
  *)
    update_shell
    ;;
esac

#------------------------------------------------------------------------------
# Symlinks
(
  cd "dotfiles"

  ln -sf "$PWD/asdf/asdfrc" "$HOME/.asdfrc"
  ln -sf "$PWD/asdf/tool-versions" "$HOME/.tool-versions"

  ln -sf "$PWD/config" "$HOME/.config"

  ln -sf "$PWD/git/gitattributes" "$HOME/.gitattributes"
  ln -sf "$PWD/git/gitconfig" "$HOME/.gitconfig"
  ln -sf "$PWD/git/gitignore" "$HOME/.gitignore"
  ln -sf "$PWD/git/gitmessage" "$HOME/.gitmessage"

  # Specify the preferences directory
  defaults write com.googlecode.iterm2.plist PrefsCustomFolder -string "$PWD/iterm2"
  # Tell iTerm2 to use the custom preferences in the directory
  defaults write com.googlecode.iterm2.plist LoadPrefsFromCustomFolder -bool true

  mkdir -p "$HOME/.local/bin"

  ln -sf "$PWD/sql/psqlrc" "$HOME/.psqlrc"

  mkdir -p "$HOME/.ssh"

  ln -sf "$PWD/tmux/tmux.conf" "$HOME/.tmux.conf"

  mkdir -p "$HOME/Library/Application Support/Code/User"
  ln -s "$PWD/vscode/settings.json" "$HOME/Library/Application Support/Code/User/settings.json"
  ln -s "$PWD/vscode/keybindings.json" "$HOME/Library/Application Support/Code/User/keybindings.json"
  ln -s "$PWD/vscode/snippets" "$HOME/Library/Application Support/Code/User/snippets"

  cat "$PWD/vscode/extensions" | grep -v '^#' | egrep -v '^\s*$' | xargs -L1 code --install-extension

  defaults write com.microsoft.VSCode ApplePressAndHoldEnabled -bool false
)


#------------------------------------------------------------------------------
# Languages
asdf_install() {
  if ! asdf plugin-list | grep -Fq "$1"; then
    asdf plugin-add $1
  fi

  asdf install $1 latest
  asdf global $1 $(asdf latest $1)
}

# link against brew libraries
BREW_PACKAGES=(openssl zlib readline)
SYSROOT=$(xcrun --sdk macosx --show-sdk-path)

INCLUDES=""
LIBRARIES=""
for INDEX in ${!BREW_PACKAGES[@]}; do
    BREW_PACKAGE=${BREW_PACKAGES[${INDEX}]}
    PATH_PREFIX=$(brew --prefix ${BREW_PACKAGE})
    INCLUDES="-I${PATH_PREFIX}/include ${INCLUDES}"
    LIBRARIES="-L${PATH_PREFIX}/lib ${LIBRARIES}"
done
INCLUDES="${INCLUDES} -I${SYSROOT}/usr/include"
LIBRARIES="${LIBRARIES} -L${SYSROOT}/usr/lib"

export CFLAGS="-isysroot ${SYSROOT} ${INCLUDES}"
export LDFLAGS="${LIBRARIES}"

# we don't need no steenking signatures!
export NODEJS_CHECK_SIGNATURES=no

asdf_install elixir
asdf_install elm
asdf_install gleam
asdf_install golang
asdf_install nodejs
asdf_install purescript
asdf_install python
asdf_install ruby
asdf_install rust
asdf_install yarn