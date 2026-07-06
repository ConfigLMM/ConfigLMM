#!/usr/bin/sh

distro=$(cat /etc/os-release | grep ^ID= |  cut -d '=' -f 2 | cut -d '"' -f 2)

EUID="$(id -u)"

admin () {
    if [ "$EUID" -eq "0" ]; then
        "$@"
    else
        sudo "$@"
    fi
}

#if [ "$EUID" -ne "0" ]; then
    if ! command -v sudo >/dev/null 2>&1; then
        case $distro in

        opensuse-leap)
            echo "You don't have sudo! Enter root password to install it"
            su root -c "zypper install --no-confirm sudo"
            ;;

        arch)
            echo "You don't have sudo! Enter root password to install it"
            su root -c "pacman -S --noconfirm --needed sudo"
            ;;

        debian)
            echo "You don't have sudo! Enter root password to install it"
            su root -c "apt-get install --yes sudo"
            ;;

        *)
            echo "Sudo not found but is needed!" >&2
            echo "Don't know how to install it for your $distro distribution!" >&2
            echo "Submit a PR :)" >&2
            exit 3
            ;;
        esac
    fi
#fi

case $distro in

opensuse-leap)
    admin zypper install --no-confirm ruby libvirt-devel
    ;;

arch)
    admin pacman -S --noconfirm --needed ruby rubygems
    ;;

debian)
    admin apt-get install --yes ruby ruby-dev ruby-libvirt
    ;;

*)
    if ! command -v ruby >/dev/null 2>&1; then
        echo "Ruby not found!" >&2
        echo "Don't know how to install it for your $distro distribution!" >&2
        echo "Submit a PR :)" >&2
        exit 1
    fi
    ;;
esac

if ! command -v gem >/dev/null 2>&1; then
    echo "RubyGems not found!" >&2
    exit 2
fi

rubyTooOld=$(ruby -e 'puts RUBY_VERSION.to_f < 3.3 ? 1 : 0')

if [ "$rubyTooOld" -eq "1" ]; then
    echo "Ruby is too old! Will install RVM" >&2
    gpg2 --keyserver hkp://keyserver.ubuntu.com --recv-keys 409B6B1796C275462A1703113804BB82D39DC0E3 7D2BAF1CF37B13E2069D6956105BD0E739499BDB >/dev/null
    curl -sSL https://get.rvm.io | bash -s stable --ruby=3.3.4

    if [ "$EUID" -eq "0" ]; then
        source /etc/profile.d/rvm.sh
    else
        source ~/.rvm/scripts/rvm
    fi

    if [ "$SHELL" = "/usr/bin/fish" ]; then
        curl -sSL --create-dirs -o ~/.config/fish/functions/rvm.fish https://raw.github.com/lunks/fish-nuggets/master/functions/rvm.fish
        sed -i "/rvm default/d" ~/.config/fish/config.fish
        echo "rvm default" >> ~/.config/fish/config.fish
    fi

    if [ "$EUID" -eq "0" ]; then
        # This shouldn't be needed but without it doesn't work
        export PATH=/usr/local/rvm/gems/ruby-3.3.4/bin:/usr/local/rvm/rubies/ruby-3.3.4/bin:$PATH
        export GEM_HOME=/usr/local/rvm/gems/ruby-3.3.4
        export GEM_PATH=/usr/local/rvm/gems/ruby-3.3.4
    fi

    bash -lc 'gem install ConfigLMM'

    echo "You need to close and reopen your shell" >&2
else
    gem install ConfigLMM
fi

echo "Done! Now you should be able to use \`configlmm\`" >&2

