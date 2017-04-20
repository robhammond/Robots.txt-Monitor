package RobotsMonitor::Functions::Common;
use strict;
use Exporter 'import';
our @EXPORT_OK = qw(build_robots_url build_local_fn);

sub build_robots_url {
	my ($protocol, $host) = @_;
	return $protocol . "://" . $host . '/robots.txt';
}

sub build_local_fn {
	my ($protocol, $host) = @_;
	my $fn = $protocol . '_' . $host;
	$fn =~ s![^-0-9A-Za-z_]!_!g;
	$fn =~ s!_+!_!g;
	$fn .= '.txt';
	return $fn;
}

1;
