use strict;
use vars qw($VERSION %IRSSI);

use Irssi;
use JSON;
use Beanstalk::Client;
$VERSION = '1.0.0';
%IRSSI = (
	authors     => 'Patrick Connelly',
	contact     => 'patrick@deadlypenguin.com',
	name        => 'beanstalkNotify',
	description => 'Send a message to a beanstalk queue when a hilight occurrs',
	url         => 'https://github.com/pcon/irssi',
	license     => 'GNU General Public License',
	changed     => '$Date: 2013-06-28 11:00:00 +0500 (Fri, 28 June 2013) $'
);

Irssi::settings_add_str('beanstalkNotify', 'beanstalk_server', 'beanstalk.example.com');
Irssi::settings_add_str('beanstalkNotify', 'beanstalk_port', '11300');
Irssi::settings_add_str('beanstalkNotify', 'beanstalk_here_tube', 'irc_here');
Irssi::settings_add_str('beanstalkNotify', 'beanstalk_away_tube', 'irc_away');

#--------------------------------------------------------------------
# In parts based on fnotify.pl 0.0.4 by Thorsten Leemhuis
# http://www.leemhuis.info/files/fnotify/
# which parts are based on knotify.pl 0.1.1 by Hugo Haas
# http://larve.net/people/hugo/2005/01/knotify.pl
# which is based on osd.pl 0.3.3 by Jeroen Coekaerts, Koenraad Heijlen
# http://www.irssi.org/scripts/scripts/osd.pl
#
# Other parts based on notify.pl from Luke Macken
# http://fedora.feedjack.org/user/918/
#
#--------------------------------------------------------------------

#--------------------------------------------------------------------
# Private message parsing
#--------------------------------------------------------------------

sub priv_msg {
	my ($server,$msg,$nick,$address,$target) = @_;
	my @weekDays = qw(Sun Mon Tue Wed Thu Fri Sat Sun);
	my ($sec,$min,$hour,$mday,$month,$yearoff,$dayofweek,$dayofyear,$daylight) = localtime();
	if ($min < 9) { $min = "0".$min;}
	if ($hour < 9) { $hour = "0".$hour;}
	my $date = "$weekDays[$dayofweek]-$hour:$min";

	send_notify($nick, $server->{chatnet}, $msg, $date, $server->{usermode_away});
}

#--------------------------------------------------------------------
# Printing hilight's
#--------------------------------------------------------------------

sub hilight {
    my ($dest, $text, $stripped) = @_;
    if ($dest->{level} & MSGLEVEL_HILIGHT) {
	my @weekDays = qw(Sun Mon Tue Wed Thu Fri Sat Sun);
	my ($sec,$min,$hour,$mday,$month,$yearoff,$dayofweek,$dayofyear,$daylight) = localtime();
	if ($min < 9) { $min = "0".$min;}
	if ($hour < 9) { $hour = "0".$hour;}
	my $date = "$weekDays[$dayofweek]-$hour:$min";

	send_notify($dest->{target}, $dest->{server}->{chatnet}, $stripped, $date, $dest->{server}->{usermode_away});
    }
}

#--------------------------------------------------------------------
# Send notification
#--------------------------------------------------------------------

sub send_notify {
	my ($channel, $server, $message, $date, $away) = @_;
	utf8::decode($channel);
	utf8::decode($server);
	utf8::decode($message);

	my $BEANSTALK_SERVER = Irssi::settings_get_str('beanstalk_server');
	my $BEANSTALK_PORT = Irssi::settings_get_str('beanstalk_port');
	my $BEANSTALK_HERE_TUBE = Irssi::settings_get_str('beanstalk_here_tube');
	my $BEANSTALK_AWAY_TUBE = Irssi::settings_get_str('beanstalk_away_tube');
	my $BEANSTALK_TUBE = ($away == 1) ? $BEANSTALK_AWAY_TUBE : $BEANSTALK_HERE_TUBE;

	my $beanstalk;

	eval {
		$beanstalk = Beanstalk::Client->new({
			server => $BEANSTALK_SERVER.':'.$BEANSTALK_PORT,
			connect_timeout => 2,
			default_tube => $BEANSTALK_TUBE
		});
	};

	my %data_hash = ('channel' => $channel, 'server' => $server, 'message' => $message, 'date' => $date);
	my $data = encode_json \%data_hash;

	if (defined($beanstalk)) {
		my $job = $beanstalk->put({
			data => $data
		});

		$beanstalk->disconnect;
	}
}

#--------------------------------------------------------------------
# Irssi::signal_add_last / Irssi::command_bind
#--------------------------------------------------------------------

Irssi::signal_add_last("message private", "priv_msg");
Irssi::signal_add_last("print text", "hilight");

#- end