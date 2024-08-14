#!/usr/bin/sh

distro=$(cat /etc/os-release | grep ^ID= |  cut -d '=' -f 2 | cut -d '"' -f 2)

function admin {
    if [ "$EUID" -eq "0" ]; then
        "$@"
    else
        sudo "$@"
    fi
}


case $distro in

opensuse-leap)
    admin zypper install --no-confirm ruby libvirt-devel
    ;;

arch)
    admin pacman -S --noconfirm --needed ruby rubygems
    ;;

*)
    if ! command -v ruby &> /dev/null
    then
        echo "Ruby not found!" >&2
        echo "Don't know how to install it for your $distro distribution!" >&2
        echo "Submit a PR :)" >&2
        exit 1
    fi
    ;;
esac

if ! command -v gem &> /dev/null; then
    echo "RubyGems not found!" >&2
    exit 2
fi

rubyTooOld=$(ruby -e 'puts RUBY_VERSION.to_f < 3.3 ? 1 : 0')

if [ "$rubyTooOld" -eq "1" ]; then
    echo "Ruby is too old! Will install RVM" >&2
    gpg2 --keyserver hkp://keyserver.ubuntu.com --recv-keys 409B6B1796C275462A1703113804BB82D39DC0E3 7D2BAF1CF37B13E2069D6956105BD0E739499BDB >/dev/null
    curl -sSL https://get.rvm.io | bash -s stable --ruby=3.3.4
    source /etc/profile.d/rvm.sh

    if [ "$SHELL" = "/usr/bin/fish" ]; then
        curl -sSL --create-dirs -o ~/.config/fish/functions/rvm.fish https://raw.github.com/lunks/fish-nuggets/master/functions/rvm.fish
        sed -i "/rvm default/d" ~/.config/fish/config.fish
        echo "rvm default" >> ~/.config/fish/config.fish
    fi
fi

# This shouldn't be needed but without it doesn't work
export PATH=/usr/local/rvm/gems/ruby-3.3.4/bin:/usr/local/rvm/rubies/ruby-3.3.4/bin:$PATH
export GEM_HOME=/usr/local/rvm/gems/ruby-3.3.4
export GEM_PATH=/usr/local/rvm/gems/ruby-3.3.4

bash -lc 'gem install ConfigLMM'

echo "You need to close and reopen your shell" >&2
