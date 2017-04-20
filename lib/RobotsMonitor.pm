package RobotsMonitor;
use Mojo::Base 'Mojolicious';
use MongoDB;

sub startup {
	my $self = shift;

	# Documentation browser under "/perldoc"
	$self->plugin('PODRenderer');
	# load config file
	my $config = $self->plugin('Config');

	# mongodb
	$self->attr(db => sub { 
		MongoDB::MongoClient
		->new( 
			host => $config->{'mongodb'}->{'host'} . ':' . $config->{'mongodb'}->{'port'},
			timeout => 300000, 
			query_timeout => 300000 
		)
		->get_database($config->{'mongodb'}->{'db'});
	});
	$self->helper('db' => sub { shift->app->db });

	# Router
	my $r = $self->routes;

	# Normal route to controller
	$r->get('/')->to('core#welcome');
	$r->get('/add')->to('core#add');
	$r->post('/save')->to('core#save');
	$r->post('/save-multi')->to('core#save_multi');
	$r->get('/delete')->to('core#delete');
	$r->get('/active')->to('core#active');
	$r->get('/view')->to('core#view');
	$r->get('/version')->to('core#version');
	$r->get('/compare')->to('core#compare');
}

1;
