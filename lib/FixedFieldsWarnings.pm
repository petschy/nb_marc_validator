package FixedFieldsWarnings;

use Modern::Perl '2017';
use autodie qw(:all);
use utf8::all;
use diagnostics;
use Moose;
use namespace::autoclean;

use Data::Dumper;

has 'warnings' => (
					is      => 'rw',
					isa     => 'ArrayRef',
					default => sub { [] }, 
);


sub get_warnings
{
	my $self = shift;
	return $self->warnings;
}

sub add_warning
{
	my $self        = shift;
	my @new_warning = shift;
	push @{ $self->warnings }, @new_warning;
	
}

__PACKAGE__->meta->make_immutable;
1;
