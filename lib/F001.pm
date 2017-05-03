package F001;

use Modern::Perl '2017';
use autodie qw(:all);
use utf8::all;
use diagnostics;
use Moose;
use namespace::autoclean;

use Data::Dumper;

use MARCWarnings;

has 'bib_id' => (
				  is  => 'rw',
				  isa => 'Str',
);


sub set_bib_id
{
	my $self   = shift;
	my $bib_id = shift;
	my $warnings = shift;
	if ( $bib_id =~ /^vtls\d{9}/ )
	{
		$bib_id = substr $bib_id, -9;
		$self->bib_id($bib_id);
		return ();
	} else
	{
		$self->bib_id($bib_id);
		my @warning = ( $self->bib_id, '001', '-',$self->bib_id, qq(Ungültige BibId) );
		$warnings->add_warning(\@warning);
	}

}

sub get_bib_id {
	my $self = shift;
	return $self->bib_id;
}


__PACKAGE__->meta->make_immutable;
1;
