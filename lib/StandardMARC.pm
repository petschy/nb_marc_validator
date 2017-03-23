package lib::StandardMARC;

use Modern::Perl '2017';
use autodie qw(:all); 
use utf8::all;
use diagnostics;

use Moose;
use namespace::autoclean;



__PACKAGE__->meta->make_immutable;
1;