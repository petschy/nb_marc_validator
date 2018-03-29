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

sub _set_valid_data_file
{
	my $config = MyConfig->new();
	return $config->datadir() . "BSG_MARC";
}

sub check_local
{
	my $self     = shift;
	my $record   = new MARC::Record;
	my $warnings = MARCWarnings->new();
	( $record, $warnings, my $bib_id ) = @_;

	&_check_kapitel( $record, $warnings, $bib_id );
	&_check_zeitcode( $record, $warnings, $bib_id );
	&_check_language_of_record( $record, $warnings, $bib_id );
	&_check_ill( $record, $warnings, $bib_id );

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
	my $error = "Bibliographie";

	my @f998 = $record->field('998');
	if (@f998)
	{
		foreach my $f998 (@f998)
		{
			my @subfields = $f998->subfields();
			foreach my $subfield (@subfields)
			{
				my ( $code, $data ) = @$subfield;
				if ( $code eq 'c' )
				{
					unless ( grep( /$data/, @kapitel ) )
					{
						my $ind_or_sf = $code;
						my $tag       = '998';
						my $content   = $data;
						my $problem   = "Ungültiges Kapitel.";
						my @message = (
										$error, $bib_id, $tag, $ind_or_sf,
										$content, $problem
						);
						$warnings->add_warning( \@message );

					}
				}
			}

		}
	}

}

sub _check_ill
{

	my $record   = new MARC::Record;
	my $warnings = MARCWarnings->new();
	( $record, $warnings, my $bib_id ) = @_;

	my $error = "MARC";

	my $leader = $record->leader();
	my $bib_lvl = substr $leader, 7, 1;
	my $type_of_record = substr $leader, 6, 1;

	if (( $bib_lvl eq 'm' or $bib_lvl eq 'a' ) && $type_of_record eq 'a')
	{
		my $ill = $record->field('008')->as_string;
		$ill = substr $ill, 18, 4;

		my $field300 = $record->field('300');
		my $subfield_b;
		if ($field300)
		{
			$subfield_b = $field300->subfield('b');
		}
		if ( $ill eq 'a   ' )
		{
			if ( !$subfield_b )
			{
				my $ind_or_sf = 'b';
				my $tag       = '300';
				my $content   = '-';
				my $problem   = "In 008 'a   ', aber kein 300 \$b";
				my @message =
				  ( $error, $bib_id, $tag, $ind_or_sf, $content, $problem );
				$warnings->add_warning( \@message );

			}
		} elsif ( $ill eq '    ' )
		{
			if ($subfield_b)
			{
				my $ind_or_sf = 'b';
				my $tag       = '300';
				my $content   = $record->field('300')->subfield('b');
				my $problem   = "In 008 '    ', aber ein 300 \$b";
				my @message =
				  ( $error, $bib_id, $tag, $ind_or_sf, $content, $problem );
				$warnings->add_warning( \@message );

			}

		} else
		{
			my $ind_or_sf = '18-21';
			my $tag       = '008';
			my $content   = $ill;
			my $problem   = "Falsche Codierung ill.";
			my @message =
			  ( $error, $bib_id, $tag, $ind_or_sf, $content, $problem );
			$warnings->add_warning( \@message );

		}
		say $bib_lvl;
		say "'$ill'";

	}

}

sub _check_zeitcode
{
	my $record   = new MARC::Record;
	my $warnings = MARCWarnings->new();
	( $record, $warnings, my $bib_id ) = @_;

	my $error = "Bibliographie";

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
				if ( $code eq 'e' )
				{
					unless ( grep( /$data/, @kapitel ) )
					{
						my $ind_or_sf = $code;
						my $tag       = '998';
						my $content   = $data;
						my $problem   = "Ungültiger Zeitcode.";
						my @message = (
										$error, $bib_id, $tag, $ind_or_sf,
										$content, $problem
						);
						$warnings->add_warning( \@message );
					}
				}
			}
		}
	}
}

sub _check_language_of_record
{
	my $record   = new MARC::Record;
	my $warnings = MARCWarnings->new();
	( $record, $warnings, my $bib_id ) = @_;
	my $lang = $record->field('008')->as_string;
	$lang = substr $lang, 35, 3;
	my $error = "Sprache";

	my @fre = ( "Notes de bas de page", "Bibliogr.", "Bibliographie" );
	my @ger = ( "Fussnoten", "Literaturverz.", "Literaturverzeichnis" );
	my @ita = ( "Note a piè di pagina", "Bibliogr.", "Bibliografia" );
	my @f504 = $record->field('504');
	if (@f504)
	{
		foreach my $f504 (@f504)
		{
			my @subfields = $f504->subfields();
			foreach my $subfield (@subfields)
			{
				my ( $code, $data ) = @$subfield;
				if ( $code eq 'a' )
				{
					if ( $lang eq 'ita' )
					{
						unless ( grep( /$data/, @ita ) )
						{
							my $ind_or_sf = $code;
							my $tag       = '504';
							my $content   = $data;
							my $problem =
"Falsche Sprache (008:$lang) oder Typo in Fussnote.";
							my @message = (
									$error, $bib_id, $tag, $ind_or_sf, $content,
									$problem
							);
							$warnings->add_warning( \@message );
						}

					} elsif (    $lang eq 'fre'
							  || $lang eq 'frm'
							  || $lang eq 'lat'
							  || $lang eq 'spa'
							  || $lang eq 'cat'
							  || $lang eq 'glg'
							  || $lang eq 'por'
							  || $lang eq 'rum' )
					{
						unless ( grep( /$data/, @fre ) )
						{
							my $ind_or_sf = $code;
							my $tag       = '504';
							my $content   = $data;
							my $problem =
"Falsche Sprache (008:$lang) oder Typo in Fussnote.";
							my @message = (
									$error, $bib_id, $tag, $ind_or_sf, $content,
									$problem
							);
							$warnings->add_warning( \@message );
						}

					} else
					{
						unless ( grep( /$data/, @ger ) )
						{
							my $ind_or_sf = $code;
							my $tag       = '504';
							my $content   = $data;
							my $problem =
"Falsche Sprache (008:$lang) oder Typo in Fussnote.";
							my @message = (
									$error, $bib_id, $tag, $ind_or_sf, $content,
									$problem
							);
							$warnings->add_warning( \@message );
						}

					}
				}
			}
		}
	}

}

__PACKAGE__->meta->make_immutable;
1;
