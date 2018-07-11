package MyConfig;

use Modern::Perl '2017';
use autodie qw(:all);
use utf8::all;
use diagnostics;

use Moose;
use namespace::autoclean;

use String::Util qw(trim);
use Data::Dumper;

has 'marcdir' => (
				is      => 'ro',
				isa     => 'Str',
				default => 'mrc/',
);

has 'datadir' => (
				is      => 'ro',
				isa     => 'Str',
				default => 'data/',
);

has 'warningsdir' => (
				is      => 'ro',
				isa     => 'Str',
				default => 'warnings/',
);


__PACKAGE__->meta->make_immutable;
1;
