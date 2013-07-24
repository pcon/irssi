#!/usr/bin/perl
#
# by pcon

use strict;
use IO::Socket;
use LWP::UserAgent;

use vars qw($VERSION %IRSSI);

use Irssi qw(command_bind active_win);
$VERSION = '1.1.1';
%IRSSI = (
	authors	=> 'pcon',
	contact	=> 'patrick@deadlypenguin.com',
	name	=> 'hurl',
	description	=> 'Takes a full url and makes it smaller with hURL',
	url => 'http://pcon.github.com',
	license	=> 'GPL',
);

Irssi::settings_add_str('hurl', 'hurl_url', '');

command_bind(
	hurl => sub {
		my ($msg, $server, $witem) = @_;

		my $BASE_URL = Irssi::settings_get_str('hurl_url');

		if (!$BASE_URL) {
			print CLIENTCRAP "hurl_url not set";
			return;
		}

		my $answer = hurl($msg);
		if ($answer) {
			active_win->command("SAY $answer");
		}
	}
);

sub hurl {
	my $url = shift;

	if ($url) {
		my $BASE_URL = Irssi::settings_get_str('hurl_url');

		my $ua = LWP::UserAgent->new;
		$ua->agent("fullurl for irssi/1.0 ");
		my $req = HTTP::Request->new(GET => $BASE_URL.$url);
		$req->content_type('application/x-www-form-urlencoded');
		my $res = $ua->request($req);

		if ($res->is_success) {
			return get_small_url($res->content);
		} else {
			print CLIENTCRAP "ERROR: hurl: hurl host is down or not pingable";
			return "";
		}
	} else {
		print CLIENTCRAP "USAGE: /hurl http://longurltoshorten.com";
	}
}

sub get_small_url($) {
	my $body = shift;
	return $body;
}