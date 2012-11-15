use strict;
use vars qw ($VERSION %IRSSI);

use Irssi;
use Data::Dumper;

$VERSION = '0.1';
%IRSSI = (
	name        => 'appendnick',
	authors     => 'Patrick Connelly',
	contact     => 'patrick@deadlypenguin.com',
	url         => 'http://pcon.github.com',
	license     => 'GPLv2',
	description => 'appends your nick with |<text> and then removes it'
);

Irssi::settings_add_str('addnick', 'nick_seperator', '|');
Irssi::settings_add_bool('addnick', 'set_away', 0);

sub show_help() {
	my $help = $IRSSI{name}." ".$VERSION."
Settings you can change with /SET
	nick_seperator:	The seperator for the nick
";

	print CLIENTCRAP $help;
}


sub appendNick {
	my $NICK_SEPERATOR = Irssi::settings_get_str('nick_seperator');
	my $SET_AWAY = Irssi::settings_get_bool('set_away');

	my $away_msg = undef;

	my ($data, $server, $channel) = @_;
	my @params = split(/ /, $data);
	my $nick_part = @params[0];

	if ($SET_AWAY and scalar(@params) >= 2) {
		shift(@params);
		$away_msg = join(' ', @params);
	}

	foreach my $server (Irssi::servers) {
		my $current_nick = $server->{'wanted_nick'};
		my $new_nick = $current_nick . $NICK_SEPERATOR . $nick_part;

		$server->command("NICK $new_nick");

		if ($away_msg ne undef) {
			$server->command("AWAY $away_msg");
		}
	}
}

sub revertNick {
	my $NICK_SEPERATOR = Irssi::settings_get_str('nick_seperator');
	my $SET_AWAY = Irssi::settings_get_bool('set_away');

	foreach my $server (Irssi::servers) {
		my $current_nick = $server->{'wanted_nick'};
		my @nick_parts = split(/\Q$NICK_SEPERATOR/, $current_nick);
		my $new_nick = @nick_parts[0];

		$server->command("NICK $new_nick");

		if ($SET_AWAY and not $server->{'usermod_away'}) {
			$server->command("AWAY");
		}
	}
}

Irssi::command_bind("appendnick", "appendNick");
Irssi::command_bind("revertnick", "revertNick");