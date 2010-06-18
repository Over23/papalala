# TODO: Count also other stats than WORDS, LETTERS, SECONDS.
# TODO: Track users across nick changes.
# TODO: TopN commands.
# TODO: Shakedown stats records.

use strict;
use warnings;

use Irssi;
use DBI;

use vars qw($VERSION %IRSSI);
$VERSION = "0.0.1";
%IRSSI = (
    authors     => 'Petr Baudis',
    name        => 'wordstats',
    description => 'Keep and report per-user talk statistics',
    license     => 'BSD',
);

our $irssidir = Irssi::get_irssi_dir;
our $stats = Stats->new("$irssidir/wordstats.sqlite3");

sub event_public {
	my ($server, $message, $nick, $hostmask, $channel) = @_;
	my $cp = Irssi::settings_get_str('bot_cmd_prefix');

	my $user = $nick; # TODO

	if ($message =~ /^${cp}(t?)(top[123]0|stat|stathelp)(?:\s+(\S+))?$/) {
		# TODO
		my @slabels = qw(letters words actions smileys kicks modes topics time);
		if ($2 eq 'stat') {
			$user = $3 if $3;
			# create empty stats record for the user in order
			# to update the number of seconds
			$stats->recstat(time, $user, $channel, $stats->zstats());

			my @stats = $stats->ustat($user, $channel, $1 eq 't' ? time - 86400 : 0);
			if (not defined $stats[0]) {
				$server->send_message($channel, "$user: no such file or directory", 0);
			} else {
				$stats[Stats::SECONDS] = format_time($stats[Stats::SECONDS]);
				$slabels[Stats::SECONDS] = "time spent";
				@stats = map { $stats[$_] . ' ' . $slabels[$_] } 0..$#stats;
				$server->send_message($channel, "$user: ".join(', ', @stats), 0);
			}

		} elsif ($2 eq 'stathelp') {
			$server->send_message($channel, "[t](top10,20,30|stat|stathelp) <".join(' ',@slabels).">", 0);

		} else {
			$server->send_message($channel, "$user: brm", 0);
		}
		return;
	}

	my @ustats = $stats->ustat($user, $channel, time - 86400);
	my @stats = $stats->zstats();

	$stats->{dbh}->do('BEGIN TRANSACTION');
	foreach my $word (split(/\W+/, $message)) {
		next unless $word;
		$stats->recword(time, $user, $channel, $word);
		$stats[Stats::WORDS]++;
		$stats[Stats::LETTERS] += length $word;
	}
	$stats->recstat(time, $user, $channel, @stats);
	$stats->{dbh}->do('COMMIT TRANSACTION');

	my @ustats2 = $stats->ustat($user, $channel, time - 86400);
	if (int($ustats2[Stats::WORDS] / 1000) > int($ustats[Stats::WORDS] / 1000)) {
		# The user entered his next thousand right now. Cheer him on!
		my @addr = ("broucku", "kotatko", "cicinko", "fifinko", "brouci", "broucku", "zlutasku", "princatko", "broucku", "drobecku", "myspuldo", "jenicku", "marenko", "broucku", "brouci", "paroubecku", "ty, ty... ty...", "moje nejmilejsi hracko", "broucku");
		my @msgs = (
			'%u: brrrrm...', # should never trigger
			[
			'%u: Vlezly botik Ti gratuluje k tisici slovum, kterymi jsi nas zde dnes jiz kolektivne obstastnilo, %a.',
			'%u: Gratuluji, vyhralos dva virtualni duhove medvidky haribo za svoji tisickovku slov, %a.',
			'%u jede, uz ma dneska tisic slov. Do toho, %a!',
			'%u se dneska nejak rozkecal. Uz ma tisic slov.',
			'%u: Drz uz svuj rozmily zobacek, %a.',
			'%u: Vsiml sis, %a, ze uz mas dneska 10^3 slov?',
			'%u: Bla bla bla bla bla bla bla... (x1000)',
			'M4W1A<W1N>6-H(\'!R=FYI8V@@=&ES:6,@<VQO=B!P<F5J92!K;VQE:W1I=B!I&9&QE<G4*',
			],
			'%u: Dva tisice slov. Dneska jsi to poradne rozjelo, %a.',
			'%u: Prave jsi dosahlo TRI TISICE SLOV - jsi fakt dobre, %a!',
			"\%u: \2CTYRI TISICE SLOV\2. Channel pwnz0r3d, l33t.",
		);
		my $th = ($ustats2[Stats::WORDS] / 1000);
		my $m;
		if ($th > $#msgs) {
			$m = "($user stale flooduje a flooduje, az to uz vtipne neni. ".($th*1000)." slov, nuda.)";
		} else {
			if (ref($msgs[$th]) eq 'ARRAY') {
				$m = $msgs[$th]->[int(rand(@{$msgs[$th]}))];
			} else {
				$m = $msgs[$th];
			}
			my $addr = $addr[int(rand(@addr))];
			$m =~ s/%u/$user/g;
			$m =~ s/%a/$addr/g;
		}
		$server->send_message($channel, $m, 0);
		if (!($ustats2[Stats::WORDS] % 1000)) {
			$server->send_message($channel, "$user: HEADSHOT! r0xx0r \\o/", 0);
		}
	}
}

sub format_time {
        use integer;

        my $t = shift;
        my $r = "ouch, can't format that time";

        if ($t >= 0) {
                $r = sprintf "%i", $t % 60;
                $t /= 60;
        }
        if ($t > 0) {
                $r = sprintf "%i.%s", $t % 60, $r;
                $t /= 60;
        }
        if ($t > 0) {
                $r = sprintf "%i:%s", $t % 24, $r;
                $t /= 24;
        }
        if ($t > 0) {
                $r = sprintf "%id %s", $t % 31, $r;
                $t /= 31;
        }
        if ($t > 0) {
                $r = sprintf "%im %s", $t % 12, $r;
                $t /= 12;
        }
        if ($t > 0) {
                $r = sprintf "%iy %s", $t, $r;
        }

        return $r;
}

Irssi::signal_add_last('message public', 'event_public');

Irssi::settings_add_str('bot', 'bot_cmd_prefix', '`');

package Stats;

sub LETTERS {0};
sub WORDS {1};
sub ACTIONS {2};
sub SMILEYS {3};
sub KICKS {4};
sub MODES {5};
sub TOPICS {6};
sub SECONDS {7};
sub zstats { (0,0,0,0,0,0,0,0); }

sub new {
	my $class = shift;
	my ($dbfile) = @_;
	my $this = {};

	$this->{dbh} = DBI->connect("dbi:SQLite:dbname=$dbfile", "", "") or
		die ("Can't open DB: $!");
	$this->{qupword} = $this->{dbh}->prepare("UPDATE words SET hits = hits + 1, last = ? WHERE user=? AND channel=? AND network=? AND word=?");
	$this->{qrecword} = $this->{dbh}->prepare("INSERT INTO words (hits,last,user,channel,network,word) VALUES (1,?,?,?,?,?)");
	$this->{qupstat} = $this->{dbh}->prepare("UPDATE stats SET letters=letters+?, words=words+?, actions=actions+?, smileys=smileys+?, kicks=kicks+?, modes=modes+?, topics=topics+?, seconds=seconds+? WHERE user=? AND channel=? AND network=? AND time=? AND timespan=?");
	$this->{qrecstat} = $this->{dbh}->prepare("INSERT INTO stats (letters,words,actions,smileys,kicks,modes,topics,seconds, user,channel,network,time,timespan) VALUES (?,?,?,?,?,?,?,?, ?,?,?,?,?)");

	$this->{qgetstat} = $this->{dbh}->prepare("SELECT sum(letters), sum(words), sum(actions), sum(smileys), sum(kicks), sum(modes), sum(topics), sum(seconds) FROM stats WHERE user = ? AND channel = ? AND network = ? AND time > ? AND time + timespan < ?");

	$this->{userseconds} = {};

	bless $this, $class;
}

sub execute_rows {
	my $this = shift;
	my ($q, @par) = @_;
	$this->{$q}->execute(@par);
	return $this->{$q}->rows;
}

sub recword {
	my $this = shift;
	my ($t, $user, $channel, $word) = @_;
	$word = lc $word;
	$this->execute_rows('qupword', $t, $user, $channel, 'IRCnet', $word) or
		$this->execute_rows('qrecword', $t, $user, $channel, 'IRCnet', $word);
}

sub recstat {
	my $this = shift;
	my ($t, $user, $channel, @stats) = @_;

	my $tl = ($this->{userseconds}->{$user} and $this->{userseconds}->{$user}->{$channel});
	$tl and $stats[SECONDS] = $t - $tl;
	$this->{userseconds}->{$user}->{$channel} = $t;

	my $gran = 60;
	my $gt = int($t / $gran) * $gran;

	$this->execute_rows('qupstat', @stats, $user, $channel, 'IRCnet', $gt, $gran) or
		$this->execute_rows('qrecstat', @stats, $user, $channel, 'IRCnet', $gt, $gran);
}

sub ustat {
	my $this = shift;
	my ($user, $channel, $since) = @_;
	$this->execute_rows('qgetstat', $user, $channel, 'IRCnet', $since, ((1<<31)-1));
	$this->{qgetstat}->fetchrow_array;
}

1;
