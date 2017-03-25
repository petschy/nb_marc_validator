package BsgMARC;

use Modern::Perl '2017';
use autodie qw(:all); 
use utf8::all;
use diagnostics;

use Moose;
use namespace::autoclean;

use lib 'lib';

{
	extends 'StandardMARC';

}

sub _set_marcfile {
	return "data/BSG_MARC";
}


__PACKAGE__->meta->make_immutable;
1;