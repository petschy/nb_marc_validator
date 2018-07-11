package NbMARC;

use Modern::Perl '2017';
use autodie qw(:all);
use utf8::all;
use diagnostics;

use Moose;
use namespace::autoclean;

use MARC::Record;
use MARC::Field;


{
	extends 'StandardMARC';

}

sub _set_valid_data_file
{
	my $config = MyConfig->new();
	return $config->datadir() . "NB_MARC";

}

sub check_local
{
	my $self     = shift;
	my $record   = new MARC::Record;
	my $warnings = MARCWarnings->new();
	( $record, $warnings, my $bib_id ) = @_;

	&_check_264( $record, $warnings, $bib_id );
}

sub _check_264

{
	my $record   = new MARC::Record;
	my $warnings = MARCWarnings->new();
	( $record, $warnings, my $bib_id ) = @_;
	my @f264 = $record->field('264');
	if (@f264)
	{
		foreach my $field (@f264)
		{
			if ( $field->indicator(2) eq '4' )
			{
				my @subfields = $field->subfields();
				my @codes;
				foreach my $subfield (@subfields)
				{
					my ( $code, $data ) = @$subfield;
					unless ( $code eq 'c' )
					{
						my $ind_or_sf = $code;
						my $tag       = '264';
						my $content   = $field->as_string();
						my $problem =
						  "Nur Unterfeld c ist erlaubt (2. Indikator = 4).";
						my @message =
						  ( $bib_id, $tag, $ind_or_sf, $content, $problem );
						$warnings->add_warning( \@message );

					}

				}

			}
		}
	}
}

__PACKAGE__->meta->make_immutable;
1;
