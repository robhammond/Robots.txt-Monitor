package RobotsMonitor::Controller::Core;
use Mojo::Base 'Mojolicious::Controller';
use Mojo::Log;
use DateTime;
use FindBin qw($Bin);
use URI::Split qw(uri_split);
use RobotsMonitor::Functions::Common qw(build_robots_url build_local_fn);

my $log = Mojo::Log->new;

sub welcome {
	my $self = shift;
	my $db = $self->db;
	my $coll = $db->get_collection('robots_txt');
	my $res = $coll->find()->sort({host => 1});
	my @docs = $res->all;
	
	$self->render(
		monitors => \@docs
	);
}

sub add {
	my $self = shift;

	$self->render();
}

sub save {
	my $self = shift;
	my $db = $self->db;
	my $coll = $db->get_collection('robots_txt');
	my $params = $self->req->params()->to_hash;
	$params->{'active'} = 'True';

	my $res = $coll->insert($params);
	# init git
	my $dir = "$Bin/../" . $self->config->{'git_dir'};
	my $safe_dom = $self->param('host');
	$safe_dom =~ s![^-a-zA-Z0-9]!_!g;
	my $new_dir = "$dir" . '/' . $safe_dom;
	my $msg = `cd $dir; mkdir $new_dir; cd $new_dir; git init;`;
	$self->flash(msg => 'saved!');
	$self->redirect_to('/');
}

sub save_multi {
	my $self = shift;
	my $db = $self->db;
	my $coll = $db->get_collection('robots_txt');
	my @urls = split(/(\r|\n)/, $self->param('urls'));

	for my $u (@urls) {
		next unless $u =~ m{^https?://};
		my $site;
		($site->{'protocol'}, $site->{'host'}) = $u =~ m{^(https?)://([^/]+)};
		$site->{'active'} = 'True';
		my $res = $coll->insert($site);
		# init git
		my $dir = "$Bin/../" . $self->config->{'git_dir'};
		my $safe_dom = $site->{'host'};
		$safe_dom =~ s![^-a-zA-Z0-9]!_!g;
		my $new_dir = "$dir" . '/' . $safe_dom;
		my $msg = `cd $dir; mkdir $new_dir; cd $new_dir; git init;`;
	}

	$self->flash(msg => 'saved!');
	$self->redirect_to('/');
}

sub delete {
	my $self = shift;
	my $db = $self->db;
	my $coll = $db->get_collection('robots_txt');

	my $res = $coll->find_one({_id => MongoDB::OID->new(value => $self->param('id'))});

	my $del = $coll->remove({ _id => MongoDB::OID->new(value => $self->param('id'))});

	# also need to delete .git
	my $dir = "$Bin/../" . $self->config->{'git_dir'};
	my $safe_dom = $res->{'host'};
	$safe_dom =~ s![^-a-zA-Z0-9]!_!g;
	if (length($safe_dom) > 3) {
		my $new_dir = "$dir" . '/' . $safe_dom;
		my $msg = `rm -rf $new_dir;`;
	}

	$self->flash(msg => 'deleted!');
	$self->redirect_to('/');
}

sub active {
	my $self = shift;
	my $db = $self->db;
	my $coll = $db->get_collection('robots_txt');
	my $power = $self->param('power');
	if ($power eq 'True') {
		$power = 'False';
	} else {
		$power = 'True';
	}

	my $res = $coll->update({ _id => MongoDB::OID->new(value => $self->param('id'))}, {'$set' => {active => $power }});

	$self->flash(msg => '(de)activated!');
	$self->redirect_to('/');
}

sub view {
	my $self = shift;
	my $db = $self->db;
	my $coll = $db->get_collection('robots_txt');
	my $id = $self->param('id');

	my $res = $coll->find_one({ _id => MongoDB::OID->new(value => $id)});
	$res->{'robots_url'} = build_robots_url($res->{'protocol'}, $res->{'host'});

	$self->render( doc => $res );
}

sub version {
	my $self = shift;
	my $commit_id = $self->param('commit_id');
	my $id = $self->param('id');

	my $db = $self->db;
	my $coll = $db->get_collection('robots_txt');
	my $res = $coll->find_one({ _id => MongoDB::OID->new(value => $id)});
	my $safe_dom = $res->{'host'};
	$safe_dom =~ s![^-a-zA-Z0-9]!_!g;

	my $fn = build_local_fn($res->{'protocol'}, $res->{'host'});
	$res->{'robots_url'} = build_robots_url($res->{'protocol'}, $res->{'host'});

	my $commit_details;
	my $compare = ['Select'];
	for my $c (@{$res->{'changes'}}) {
		next unless $c->{'commit_id'};
		
		if ($c->{'commit_id'} eq $commit_id) {
			$commit_details = $c;
		} else {
			push @$compare, [DateTime->from_epoch(epoch => $c->{'time'})->format_cldr("yyyy-MM-dd HH:mm:ss Z"), $c->{'commit_id'}];
		}
	}

	my $folder = "$Bin/../" . $self->config->{'git_dir'} . "/$safe_dom";
	my $robots = `cd $folder; git show $commit_id:$fn`;
	$self->render( robots => $robots, doc => $res, details => $commit_details, compare => $compare );
}

sub compare {
	my $self = shift;
	my $robots1;
	my $robots2;
	my $id = $self->param('id');

	my $db = $self->db;
	my $coll = $db->get_collection('robots_txt');
	my $res = $coll->find_one({ _id => MongoDB::OID->new(value => $id)});

	for my $c (@{$res->{'changes'}}) {
		next unless $c->{'commit_id'};
		
		if ($c->{'commit_id'} eq $self->param('robots1')) {
			$robots1 = $c;
		} elsif ($c->{'commit_id'} eq $self->param('robots2')) {
			$robots2 = $c;
		}
	}

	my $safe_dom = $res->{'host'};
	$safe_dom =~ s![^-a-zA-Z0-9]!_!g;

	my $fn = build_local_fn($res->{'protocol'}, $res->{'host'});
	$res->{'robots_url'} = build_robots_url($res->{'protocol'}, $res->{'host'});

	my $folder = "$Bin/../" . $self->config->{'git_dir'} . "/$safe_dom";
	$robots1->{'txt'} = `cd $folder; git show $robots1->{commit_id}:$fn`;
	$robots2->{'txt'} = `cd $folder; git show $robots2->{commit_id}:$fn`;

	$self->render( robots1 => $robots1, robots2 => $robots2);
}

1;
