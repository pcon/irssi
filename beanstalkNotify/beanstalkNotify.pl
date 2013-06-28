use strict;
use vars qw($VERSION %IRSSI);

use Irssi;
use JSON;
use Queue::Beanstalk;
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
Irssi::settings_add_str('beanstalkNotify', 'beanstalk_port', '8888');

sub show_help() {
	my $help = $IRSSI{name}." ".$VERSION."
Settings you can change with /SET
	beanstalk_server:		The server to send notifications to
	beanstalk_port:		The port to the beanstalk server
";

	print CLIENTCRAP $help;
}

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

	my $title = $nick;
	my $message = $date."\n".$msg;
	send_notify($title, $message);
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

		my $title = $dest->{target};
		my $message = $date."\n".$stripped;
		send_notify($title, $message);
	}
}

#--------------------------------------------------------------------
# Send notification
#--------------------------------------------------------------------

sub send_notify {
	my ($title, $message) = @_;
	utf8::decode($title);
	utf8::decode($message);

	my $BEANSTALK_SERVER = Irssi::settings_get_str('beanstalk_server');
	my $BEANSTALK_PORT = Irssi::settings_get_str('beanstalk_port');

	my $beanstalk;

	eval {
		$beanstalk = Queue::Beanstalk->new(
			'servers' => [ $BEANSTALK_SERVER.':'.$BEANSTALK_PORT ],
			'connect_timeout' => 2,
		);
	};

	my %data_hash = ('title' => $title, 'body' => $message);
	my $data = encode_json \%data_hash;

	if (defined($beanstalk)) {
		$beanstalk->put($data)
	}
}

#--------------------------------------------------------------------
# Irssi::signal_add_last / Irssi::command_bind
#--------------------------------------------------------------------

Irssi::signal_add_last("message private", "priv_msg");
Irssi::signal_add_last("print text", "hilight");

#- end