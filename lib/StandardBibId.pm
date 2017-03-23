package StandardBibId;

use Modern::Perl '2017';
use autodie qw(:all);
use utf8::all;
use diagnostics;
use Moose;
use namespace::autoclean;

use Data::Dumper;

has 'bib_id' => (
				  is  => 'rw',
				  isa => 'Str',
);


sub set_bib_id
{
	my $self   = shift;
	my $bib_id = shift;
	if ( $bib_id =~ /^vtls\d{9}/ )
	{
		$bib_id = substr $bib_id, -9;
		$self->bib_id($bib_id);
		return ();
	} else
	{
		$self->bib_id($bib_id);
		my @warning = ( $self->bib_id, '001', '-', qq(Ungültige BibId) );
		return @warning;
	}

}


__PACKAGE__->meta->make_immutable;
1;
