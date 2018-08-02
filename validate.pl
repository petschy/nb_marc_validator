#!/usr/bin/env perl
use Modern::Perl '2017';
use autodie qw(:all);
use utf8::all;
use diagnostics;

use Data::Dumper;

# MARC
use MARC::File::USMARC;
use MARC::Record;
use MARC::Field;

# lib modules
use lib 'lib';
use BsgMARC;
use SbMARC;
use NbMARC;
use F001;
use MARCWarnings;
use MyConfig;
use StandardMARC;
use FixedFieldsWarnings;
use F006;
use F008;

my $f001                  = F001->new();
my $f006                  = F006->new();
my $f008                  = F008->new();
my $warnings              = MARCWarnings->new();
my $warnings_fixed_fields = FixedFieldsWarnings->new();
my @header =
  ( 'FEHLER', 'BIB_ID', 'FELD', 'IND/UF/POS', 'FELDINHALT', 'HINWEIS' );

$warnings->add_warning( \@header );

@header = (
			'BIB_ID',         'FELD',
			'POS',            'WERT',
			'ERLAUBT',        'FELDLÄNGE_SOLL',
			'FELDLÄNGE_IST', 'FELDLÄNGE_OK',
			'TYPE_OF_MATERIAL'
);
$warnings_fixed_fields->add_warning( \@header );

my $config = MyConfig->new();

# Marc file
my $marcfile = shift;
chomp $marcfile;
my $rules = shift;
chomp $rules;
my @rules_defined = ( "Standard", "Bsg", "Sb", "Nb" );
if ( defined $marcfile && defined $rules )
{
	my @rules_defined = ( "Standard", "Bsg", "Sb", "Nb" );
	unless ( grep /^$rules$/, @rules_defined )
	{
		say "Usage: 'perl validate.pl [filename].mrc Standard|Nb|Sb|Bsg'";
		exit -1;
	}
} else
{
	say "Usage: 'perl validate.pl [filename].mrc Standard|Nb|Sb|Bsg'";
	exit -1;

}
$marcfile = $config->marcdir . $marcfile;
chomp $marcfile;
my $warningsfile = $config->warningsdir . "Warnings_" . $rules . ".txt";
chomp $warningsfile;
my $warningsfile_fixed_fields =
  $config->warningsdir . "Warnings_fixed-fields_" . $rules . ".txt";
chomp $warningsfile_fixed_fields;

my $fh_warnings = IO::File->new( $warningsfile, '>:utf8' );
my $fh_warnings_fixed_fields =
  IO::File->new( $warningsfile_fixed_fields, '>:utf8' );
my $fh_marc = IO::File->new( $marcfile, '<:utf8' );

my $file = $config->datadir() . "ARTIKEL";
my $fh = IO::File->new( $file, '<:utf8' );
my @article;
while (<$fh>)
{
	chomp;
	push @article, $_;
}

my $marc_rule = "${\$rules}MARC"->new();
my %marc      = %{ $marc_rule->tags };

my $i       = 1;
my $records = MARC::File::USMARC->in($fh_marc);
while ( my $record = $records->next() )
{
	$f001->set_bib_id( $record->field('001')->as_string, $warnings );
	say "Record no $i: BibId " . $f001->bib_id;

	my @fields = $record->fields();

	foreach my $field (@fields)
	{
		my $error     = '-';
		my $tag       = $field->tag();
		my $ind_or_sf = '-';
		my $content   = '-';
		my $problem   = '-';
		my @message;

		$marc_rule->non_printable_characters( $field, $warnings,
											  $f001->bib_id );

		if ( exists $marc{$tag}{$tag} )
		{
			my @_tags = $record->field($tag);
			if ( $marc{$tag}{$tag} eq 'NR' && scalar @_tags > 1 )
			{
				$error     = "MARC";
				$ind_or_sf = '-';
				$problem   = "Feld $tag ist nicht wiederholbar.";
				my @message = (
					 $error, $f001->bib_id, $tag, $ind_or_sf, $content, $problem
				);
				$warnings->add_warning( \@message );
			}

			# ohne Kontrollfelder
			unless ( $tag < 10 )
			{
				my @subfields  = $field->subfields();
				my $sf_counter = 1;
				foreach my $subfield (@subfields)
				{
					my ( $code, $data ) = @$subfield;
					my @_sf = $field->subfield($code);
					if ( exists $marc{$tag}{$code} )
					{
						if ( $marc{$tag}{$code} eq 'NR' && scalar @_sf > 1 )
						{
							$error     = "MARC";
							$ind_or_sf = $code;
							$content   = $data;
							$problem = "Unterfeld $code ist nicht wiederholbar";
							my @message = (
										$error, $f001->bib_id, $tag, $ind_or_sf,
										$content, $problem
							);
							$warnings->add_warning( \@message );
						}
					} else
					{
						$error     = "MARC";
						$ind_or_sf = $code;
						$content   = $data;
						$problem   = "Unterfeld $code ist nicht definiert.";
						my @message = (
							  $error, $f001->bib_id, $tag, $ind_or_sf, $content,
							  $problem
						);
						$warnings->add_warning( \@message );
					}
					$sf_counter++;
				}

				# Indikatoren
				my $ind1      = $field->indicator(1);
				my $ind2      = $field->indicator(2);
				my @ind_array = $marc_rule->ind_value( $marc{$tag}{'ind1'} );
				my $valid_ind = join ', ', @ind_array;
				$valid_ind =~ s/^ $/blank/;
				unless ( grep( /^$ind1/, @ind_array ) )
				{
					$error     = "MARC";
					$ind_or_sf = 'I1';
					$content   = $ind1;
					$content =~ s/^ $/blank/;
					$problem =
"Indikator 1 ist: '$content'. Gültige Werte: '$valid_ind'";
					my @message = (
							  $error, $f001->bib_id, $tag, $ind_or_sf, $content,
							  $problem
					);
					$warnings->add_warning( \@message );
				}

				@ind_array = $marc_rule->ind_value( $marc{$tag}{'ind2'} );
				$valid_ind = join ', ', @ind_array;
				$valid_ind =~ s/^ $/blank/;
				unless ( grep( /^$ind2/, @ind_array ) )
				{
					$error     = "MARC";
					$ind_or_sf = 'I2';
					$content   = $ind2;
					$content =~ s/^ $/blank/;
					$problem =
"Indikator 2 ist: '$content'. Gültige Werte: '$valid_ind'";
					my @message = (
							  $error, $f001->bib_id, $tag, $ind_or_sf, $content,
							  $problem
					);
					$warnings->add_warning( \@message );

				}
			}
		} else
		{
			$error     = "MARC";
			$ind_or_sf = '-';
			$content   = $field->as_string();
			$problem   = "Feld $tag ist nicht definiert";
			my @message =
			  ( $error, $f001->bib_id, $tag, $ind_or_sf, $content, $problem );
			$warnings->add_warning( \@message );
		}

	}

	my $type_of_material =
	  $marc_rule->get_type_of_material( $record->leader() );
	$marc_rule->check_leader( $record->leader(),      $type_of_material,
							  $warnings_fixed_fields, $f001->bib_id );
#	$marc_rule->check_008( $record, $type_of_material, $warnings_fixed_fields,
#						   $f001->bib_id );

	$marc_rule->check_language( $record, $warnings, $f001->bib_id );
	$marc_rule->check_245( $record, $warnings, $f001->bib_id, @article );
	$marc_rule->check_264( $record, $warnings, $f001->bib_id );

	#	$marc_rule->check_leader( $record, $warnings, $f001->bib_id );
	#	$marc_rule->check_006( $record, $warnings, $f001->bib_id );
	#	$marc_rule->check_008( $record, $warnings, $f001->bib_id );
	$marc_rule->check_local( $record, $warnings, $f001->bib_id );

	my @fields006 = $record->field('006');
	if (@fields006)
	{
		foreach my $field (@fields006)
		{
			$f006->check( $f001->bib_id, $field, $warnings_fixed_fields )
			  ;

		}

	}

	my @fields008 = $record->field('008');
	if (@fields008)
	{
		foreach my $field (@fields008)
		{
			$f008->check( $f001->bib_id, $field, $warnings_fixed_fields, $type_of_material )
			  ;

		}

	}

	$i++;
}

for my $x ( @{ $warnings->warnings } )
{
	say $fh_warnings join( "\t", @{$x} );
}

for my $x ( @{ $warnings_fixed_fields->warnings } )
{
	say $fh_warnings_fixed_fields join( "\t", @{$x} );
}

say '____________________________________________';
say '';
say "Marc File: $marcfile";
say "Data Dir: " . $marc_rule->valid_data_file;
say "Warnings: $warningsfile, $warningsfile_fixed_fields";
say '____________________________________________';
say $i- 1 . " " . $rules . "-Datensätze validiert.";

