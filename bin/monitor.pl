#!/usr/bin/env perl
use strict;
use warnings;
use Modern::Perl;
use Mojo::UserAgent;
use DateTime;
use Data::Dumper;
use Mojo::Log;
use Mojo::Util qw(decode);
use Mojo::File;
use MongoDB;
use FindBin qw($Bin);
use lib ("$Bin/../lib");
use RobotsMonitor::Functions::Common qw(build_robots_url build_local_fn);

my $config = parse_config("$Bin/../robots_monitor.conf");

my $log = Mojo::Log->new;

my $client   = MongoDB::MongoClient->new(
	host => $config->{'mongodb'}->{'host'} . ':' . $config->{'mongodb'}->{'port'},
);
my $db       = $client->get_database( $config->{'mongodb'}->{'db'} );
my $monitors = $db->get_collection( 'robots_txt' );
my $res = $monitors->find({ 
	active => 'True',
});

my @sites = $res->all;

my $dir = "$Bin/../" . $config->{'git_dir'};

my $ua = Mojo::UserAgent->new;

for my $s (@sites) {
	next unless $s;

	my $url = build_robots_url($s->{'protocol'}, $s->{'host'});
	my $safe_dom = $s->{'host'};
	$safe_dom =~ s![^-a-zA-Z0-9]!_!g;
	my $domain_dir = $dir . "/" . $safe_dom;

	$log->info("Fetching: $url");
	my $tx = $ua->get($url);
	if (my $res = $tx->success) {
		my $fn = build_local_fn($s->{'protocol'}, $s->{'host'});
		$res->content->asset->move_to("$domain_dir/$fn");
		my $commit_id = _commit_page($domain_dir, $fn);

		my $data = {
			last_checked => time(),
			http_status => $tx->res->code,
		};
		my $changes;
		if ($s->{'http_status'}) {
			if ($tx->res->code != $s->{'http_status'}) {
				$changes->{'http_status'} = $tx->res->code;
			}
		}
		if ($commit_id) {
			$changes->{'commit_id'} = $commit_id;
			$changes->{'http_status'} = $tx->res->code;
		}
		if ($changes->{'http_status'} || $changes->{'commit_id'}) {
			$changes->{'time'} = time();
			$monitors->update(
				{_id => $s->{'_id'}},
				{
					'$push' => {
						changes => {
							'$each' => [$changes],
							'$position' => 0
						}
					}
				}
			);
		}

		$monitors->update(
			{_id => $s->{'_id'}},
			{
				'$set' => $data
			}
		);
	} else {
		my $err = $tx->error;
		$log->error("Error fetching $s->{host} robots file.");

		if ($s->{'http_status'}) {
			if ($tx->res->code != $s->{'http_status'}) {
				my $changes;
				$changes->{'http_status'} = $tx->res->code;
				$changes->{'time'} = time();
				$monitors->update(
					{_id => $s->{'_id'}},
					{
						'$push' => {
							changes => {
								'$each' => [$changes],
								'$position' => 0
							}
						}
					}
				);
			}
		}
		
		$monitors->update(
			{_id => $s->{'_id'}},
			{
				'$set' => {
					last_checked => time(),
					http_status => $tx->res->code,
				}
			}
		);
	}
}


sub _commit_page {
	my ($dir, $fn) = @_;
	
	my $dt = DateTime->now;
	my $time = $dt->ymd . " " . $dt->hms;
	# my $msg = system("cd $dir; git add --all; git commit --message='Updated: $time, Update ID: $id';");
	my $msg = `cd $dir; git add $fn; git commit --message='Updated: $time';`;
	# $log->info($msg);
	my $commit_id;
	if ($msg =~ m{\[master ([^\]]+)\]}gsi) {
		$commit_id = $1;
		# remove first commit message
		$commit_id =~ s!\(root-commit\) !!;
	}
	if ($commit_id) {
		$log->info("Commit: $commit_id");
	} else {
		$log->info("No changes");
	}
	
	return $commit_id;
}

sub parse_config {
    my $file = shift;
    my $path = Mojo::File->new($file);
    my $content = decode('UTF-8', $path->slurp);

    my $config
        = eval 'package Mojolicious::Plugin::Config::Sandbox; no warnings;'
            . "use Mojo::Base -strict; $content";
    die qq{Couldn't load configuration from file "$file": $@} if !$config && $@;
    die qq{Config file "$file" did not return a hash reference.\n}
        unless ref $config eq 'HASH';

    return $config;
}