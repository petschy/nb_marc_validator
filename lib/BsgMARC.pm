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

sub _set_valid_data_file {
	my $config = MyConfig->new();
	return $config->datadir() . "BSG_MARC";
}

sub check_local
{
	my $self     = shift;
	my $record   = new MARC::Record;
	my $warnings = MARCWarnings->new();
	( $record, $warnings, my $bib_id ) = @_;

	&_check_264( $record, $warnings, $bib_id );
	&_check_kapitel( $record, $warnings, $bib_id );
	&_check_zeitcode( $record, $warnings, $bib_id );

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


sub _check_kapitel
{
	my $record   = new MARC::Record;
	my $warnings = MARCWarnings->new();
	( $record, $warnings, my $bib_id ) = @_;

	my $config = MyConfig->new();
	my $file   = $config->datadir() . "BSG_KAPITEL";
	my $fh     = IO::File->new( $file, '<:utf8' );
	my @kapitel;
	while (<$fh>)
	{
		chomp;
		push @kapitel, $_;
	}

	my @f998 = $record->field('998');
	if (@f998)
	{
		foreach my $f998 (@f998)
		{
			my @subfields = $f998->subfields();
			foreach my $subfield (@subfields)
			{
				my ( $code, $data ) = @$subfield;
				if ($code eq 'c'){
					unless (grep( /$data/, @kapitel )){
						my $ind_or_sf = $code;
						my $tag       = '998';
						my $content   = $data;
						my $problem =
						  "Ungültiges Kapitel.";
						my @message =
						  ( $bib_id, $tag, $ind_or_sf, $content, $problem );
						$warnings->add_warning( \@message );
						
					}
				}
			}

		}
	}


}

sub _check_zeitcode
{
	my $record   = new MARC::Record;
	my $warnings = MARCWarnings->new();
	( $record, $warnings, my $bib_id ) = @_;

	my $config = MyConfig->new();
	my $file   = $config->datadir() . "BSG_ZEITCODES";
	my $fh     = IO::File->new( $file, '<:utf8' );
	my @kapitel;
	while (<$fh>)
	{
		chomp;
		push @kapitel, $_;
	}

	my @f998 = $record->field('998');
	if (@f998)
	{
		foreach my $f998 (@f998)
		{
			my @subfields = $f998->subfields();
			foreach my $subfield (@subfields)
			{
				my ( $code, $data ) = @$subfield;
				if ($code eq 'e'){
					unless (grep( /$data/, @kapitel )){
						my $ind_or_sf = $code;
						my $tag       = '998';
						my $content   = $data;
						my $problem =
						  "Ungültiger Zeitcode.";
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