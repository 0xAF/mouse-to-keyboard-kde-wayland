#!/usr/bin/perl
# translate mouse events to keyboard keypresses
# made to work on KDE with Wayland

# this script needs:
# 1. kdotool - https://github.com/jinliu/kdotool
# 2. libinput package installed
# 3. evemu package installed 
# 3. perl-config-tiny - Config::Tiny

use strict;
use Config::Tiny;

my $DEBUG=0;
my $devices;
my $default_conf = "$ENV{HOME}/.config/mouse-to-keyboard.conf";
my $systemd_service = "$ENV{HOME}/.config/systemd/user/mouse-to-keyboard.service";
my $conf = shift || $default_conf;
my $Config;
my $mouse;
my $keyboard;
my $arg;

if ($conf =~ /^-/) {
	$arg = $conf;
	$conf = shift || $default_conf;
}

if ($arg =~ /^-h$/ || $arg =~ /^--help$/) {
	help();
	exit;
} elsif ($arg =~ /^-l$/) {
	get_devices();
	show_devices();
	exit;
} elsif ($arg =~ /^-c$/) {
	die "Config file $conf already exist. Please remove it to create new default config.\n" if ( -f $conf );
	printf "Creating config file in $conf\n";
	create_default_config();
	exit;
} elsif ($arg =~ /^-s$/) {
	die "SystemD service file $conf already exist. Please remove it to create new default service.\n" if ( -f $systemd_service );
	printf "Creating SystemD service file in $systemd_service\n";
	create_default_service();
	exit;
} elsif ($arg =~ /^-m$/) {
	init();
	process_events(1);
	exit;
} elsif ($arg =~ /^-k$/) {
	init();
	system("evemu-describe $devices->{$keyboard}->{kernel} | grep KEY_");
	exit;
} elsif ($arg =~ /^-d$/) {
	$DEBUG=1;
} elsif ($arg =~ /^-g$/) {
	printf "You have 2 seconds to focus the app (make it active), then you will see the app class, to use in the config file.\n";
	sleep(2);
	my $win = get_active_window();
	printf "$win\n";
	exit;
}

init();
process_events();

exit;

# subs 

sub get_active_window {
	my $win = qx(kdotool getwindowclassname `kdotool getactivewindow`);
	chomp($win);
	return $win;
}

sub parse_event {
	my $line = shift;
	chomp($line);
	my $event;
	my $action;
	my ($ev, $data) = ($line =~ /^\s*event\d+\s+(\S+)\s+\S+\s+(.*)$/);
	next if (!$ev || $ev eq 'POINTER_MOTION');
	if ($ev eq 'POINTER_BUTTON') {
		my ($btn, $press) = ($data =~ /^(\S+)\s+\S+\s+([^,]+),/);
		$event = $btn;
		$action = $press;
	} elsif ($ev eq 'POINTER_SCROLL_WHEEL') {
		my ($vert, $horiz) = ($data =~ /vert\s+(\S+)\s+horiz\s+(\S+)/);
		$event = "SCROLL";
		if (0) { }
		elsif ($vert =~ /^-/) { $event .= '_UP'; }
		elsif ($vert =~ /^[^0]/) { $event .= '_DOWN' }
		elsif ($horiz =~ /^-/) { $event .= '_LEFT' ; }
		elsif ($horiz =~ /^[^0]/) { $event .= '_RIGHT'; }
		$action = 'clicked';
	}
	return { e => $event, a => $action };
}

sub keyboard_press_release {
	my $p = shift;
	my $k = shift;

	my @keys = split(/\s+/, $k);
	@keys = reverse @keys if (!$p);
	foreach my $k (@keys) {
		printf "p[$p]: $k\n" if ($DEBUG);
		system("evemu-event $devices->{$keyboard}->{kernel} --sync --type EV_KEY --code $k --value $p");
		select(undef, undef, undef, 0.025) if ($p); # 25ms between keys
	}
}

sub process_events {
	my $monitor = shift;
	open(LIBINPUT, "libinput debug-events --device $devices->{$mouse}->{kernel} |");
	while (<LIBINPUT>) {
		my $event = parse_event($_);
		next unless ($event && $event->{e});
		if ($monitor) {
			printf "EVENT: $event->{e}";
			printf ", ACTION: $event->{a}" if ($event->{a});
			printf "\n";
		} else {
			my $win = get_active_window();
			next if ( !$Config->{$win} );
			my $keys = $Config->{$win}->{$event->{e}};
			printf "DEBUG: WIN: $win, EVENT: $event->{e}, ACTION: $event->{a}, EMULATE: $keys\n" if ($DEBUG);
			next if ( !$Config->{$win}->{$event->{e}} );
			keyboard_press_release(1, $keys) if ($event->{a} ne 'released');
			keyboard_press_release(0, $keys) if ($event->{a} ne 'pressed');
		}
	}
	close (LIBINPUT);
}

sub init {
	$Config  = Config::Tiny->read( $conf );
	die "No config file found\ntry $0 -h\n" unless ($Config);
	die "No mouse device in config file\n" unless ($Config->{_}->{mouse});
	die "No keyboard device in config file\n" unless ($Config->{_}->{keyboard});
	get_devices();

	$mouse = $Config->{_}->{mouse};
	$keyboard = $Config->{_}->{keyboard};
	$mouse =~ s/^\"(.*)\"$/$1/;
	$keyboard =~ s/^\"(.*)\"$/$1/;
	die "Cannot find mouse device ($mouse) in libinput. Try -l for list of available devices.\n" unless ($devices->{$mouse});
	die "Cannot find keyboard device ($keyboard) in libinput. Try -l for list of available devices.\n" unless ($devices->{$keyboard});

	printf "Mouse: $devices->{$mouse}->{kernel} ($mouse)\n";
	printf "Keyboard: $devices->{$keyboard}->{kernel} ($keyboard)\n";
}

sub help {
		print qq{Emulate keyboard events from mouse buttons.
Author: Stanislav Lechev <af\@0xAF.org>
License: WTFPL http://www.wtfpl.net/

usage: $0 [-d] [-l] [-m] [-g] [-k] [-s] [-c] [config_file]

-d           - debug events while the emulator is running
-l           - list available devices and their event files
-m           - monitor events (use this to create your config)
-g           - get app class name after 2 seconds (use this time to focus the app)
-k           - get available keys for the config
-s           - create systemd user service
-c           - create config file
config_file  - use this config file
};
}

sub create_default_config {
	system("mkdir -p `dirname $conf`");
	open(my $fh, ">", $conf) or die "Can't open > $conf: $!\n";
	print $fh qq{# mouse to keyboard emulation
# use "$0 -l" to see device names

# mouse device, to listen for events
mouse = Logitech_MXErgo_keyboard_pointer

# keyboard device to emulate key presses to
keyboard = Keychron_Keychron_K1SE_keyboard

# emulate mouse events to key presses on a specific app
# use "$0 -g" to get the app class name
# use "$0 -d" to get mouse events
[app_class]
EVENT_NAME = KEY_LEFTCTRL KEY_C ; inline comments can be written by <space><semicolon><space> at the end of the line

[org.kde.konsole]
BTN_EXTRA = KEY_LEFTCTRL KEY_LEFTSHIFT KEY_INSERT ; paste from selection
BTN_SIDE = KEY_LEFTCTRL KEY_LEFTSHIFT KEY_V ; paste from clipboard
SCROLL_LEFT = KEY_LEFTSHIFT KEY_LEFT ; switch to left window in tmux
SCROLL_RIGHT = KEY_LEFTSHIFT KEY_RIGHT ; switch to right window in tmux

[org.kde.kontact]
BTN_EXTRA = KEY_KPPLUS ; go to next unread message in folder
BTN_SIDE = KEY_LEFTALT KEY_KPPLUS ; go to next folder with unread messages

[firefox]
BTN_EXTRA = KEY_LEFTALT KEY_LEFT ; go back in hostory
BTN_SIDE = KEY_LEFTALT KEY_RIGHT ; go forward in hostory
SCROLL_LEFT = KEY_LEFTCTRL KEY_PAGEUP ; switch to previous tab
SCROLL_RIGHT = KEY_LEFTCTRL KEY_PAGEDOWN ; switch to next tab

[Chromium]
BTN_EXTRA = KEY_LEFTALT KEY_LEFT ; go back in hostory
BTN_SIDE = KEY_LEFTALT KEY_RIGHT ; go forward in hostory
SCROLL_LEFT = KEY_LEFTCTRL KEY_PAGEUP ; switch to previous tab
SCROLL_RIGHT = KEY_LEFTCTRL KEY_PAGEDOWN ; switch to next tab

[code-oss]
SCROLL_LEFT = KEY_LEFTCTRL KEY_PAGEUP ; switch to previous tab
SCROLL_RIGHT = KEY_LEFTCTRL KEY_PAGEDOWN ; switch to next tab

};
	close($fh);
}

sub create_default_service {
	use Cwd 'abs_path';
	system("mkdir -p `dirname $systemd_service`");
	open(my $fh, ">", $systemd_service) or die "Can't open > $systemd_service: $!\n";
	my $abs = abs_path($0);
	print $fh qq{[Unit]
Description=Mouse events to keyboard keyupress emulation.
After=display-manager.service

[Service]
ExecStart=$abs
RemainAfterExit=no
Restart=on-failure
RestartSec=5s

[Install]
WantedBy=default.target
};
	close($fh);
	printf "Created.\n\n";
	printf "You can now enable and start the service with 'systemctl --user daemon-reload && systemctl enable --user --now mouse-to-keyboard'\n";
}

sub get_devices {
	my @libinput_list_devices_output = do {
		local $/ = ''; # paragraph mode (each block in one item)
		`libinput list-devices`;
	};

	foreach my $block (@libinput_list_devices_output) {
		my @lines = split("\n", $block);
		my $obj;
		foreach my $line (@lines) {
			my ($k, $v) = ($line =~ /^\s*([^:]+):\s*(.*)$/);
			$k =~ s/^\s*(.*)\s+/$1/;
			$k =~ s/[\s-]+/_/g;
			$v =~ s/^\s*(.*)\s+/$1/;
			$v =~ s/[\s-]+/_/g;
			$obj->{lc($k)} = $v;
		}
		$devices->{ $obj->{device} . '_' . $obj->{capabilities} } = $obj;
	}
}

sub show_devices {
	foreach my $k (sort keys %{$devices}) {
		my $v;
		format STDOUT =
@<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<< @<<<<<<<<<<<<<<<<<<<<
'"'.$k.'"', $v
.
		$v = $devices->{$k}->{kernel};
		write;
	}
}



