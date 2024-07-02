# mouse-to-keyboard-kde-wayland
Listen to mouse events/presses and emulate key presses on keyboard  
Works on Wayland and X11.


## download and install
```sh
git clone https://github.com/0xAF/mouse-to-keyboard-kde-wayland.git

# install kdotool from https://github.com/jinliu/kdotool
# for Arch linux you can use AUR (yay)
yay -S kdotool

# install perl-config-tiny, libinput and evemu packages
# for Arch linux use:
pacman -S perl-config-tiny libunput evemu

```

## setup and usage
```sh
# show help
./mouse-to-keyboard.pl -h
# Emulate keyboard events from mouse buttons.
# Author: Stanislav Lechev <af@0xAF.org>
# License: WTFPL http://www.wtfpl.net/
# 
# usage: ./mouse-to-keyboard.pl [-d] [-l] [-m] [-g] [-k] [-s] [-c] [config_file]
# 
# -d           - debug events while the emulator is running
# -l           - list available devices and their event files
# -m           - monitor events (use this to create your config)
# -g           - get app class name after 2 seconds (use this time to focus the app)
# -k           - get available keys for the config
# -s           - create systemd user service
# -c           - create config file
# config_file  - use this config file

# create default config file
./mouse-to-keyboard.pl -c

# edit the config file
$EDITOR ~/.config/mouse-to-keyboard.conf

# find available devices to be used as mouse and keyboard (write them in the config)
./mouse-to-keyboard.pl -l

# find window class of the app you want to emulate key presses to.
./mouse-to-keyboard.pl -g

# find mouse events to listen to and simulate key presses on the app
./mouse-to-keyboard.pl -m

# find key codes (KEY_*) to simulate to the app
./mouse-to-keyboard.pl -k

# create systemd user service to run in background, once you login to KDE
./mouse-to-keyboard.pl -s

```