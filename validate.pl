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
use StandardMARC;
use StandardBibId;
use BsgMARC;
use BsgBibId;
use SbMARC;
use SbBibId;
use NbMARC;
use NbBibId;

# Marc file
my $marcfile = shift;
$marcfile = "mrc/$marcfile";
my $rule = shift;
my @rules = ( "Standard", "Bsg", "Sb", "Nb" );
unless ( grep /^$rule$/, @rules )
{
	say "Usage: 'perl validate.pl [filename].mrc Standard|Nb|Sb|Bsg'";
	exit -1;
}

# Warnings
my $bib_id    = "BIB_ID";
my $tag       = "TAG";
my $ind_or_sf = "IND/SF";
my $content = "CONTENT";
my $problem   = "PROBLEM";
my @warnings  = ( $bib_id, $tag, $ind_or_sf, $content, $problem );

#my @warnings_heading = ( $bib_id, $tag, $ind_or_sf, $problem );
my $fh_warnings = IO::File->new( $rule . "_warnings.txt", '>:utf8' );
say $fh_warnings join "\t", @warnings;

my $i       = 1;
my $records = MARC::File::USMARC->in($marcfile);
while ( my $record = $records->next() )
{

	my $ctr_no = "${\$rule}BibId"->new();
	@warnings = $ctr_no->set_bib_id( $record->field('001')->as_string() );
	$bib_id   = $ctr_no->bib_id;
	say "Record no $i: BibId " . $ctr_no->bib_id;
	if (@warnings) { say $fh_warnings join "\t", @warnings; }

	###############################
	my $marc_rule = "${\$rule}MARC"->new();
	my %marc      = %{ $marc_rule->tags };

	#	say Dumper %marc{'245'};
	my @fields = $record->fields();

	foreach my $field (@fields)
	{
		$tag = $field->tag();
		if ( exists $marc{$tag}{$tag} )
		{
			my @_tags = $record->field($tag);
			if ( $marc{$tag}{$tag} eq 'NR' && scalar @_tags > 1 )
			{
				$ind_or_sf = '-';
				$problem   = "Feld $tag ist nicht wiederholbar.";
				@warnings  = ( $bib_id, $tag, $ind_or_sf, $content, $problem );
				say $fh_warnings join "\t", @warnings;
			}

			# ohne Kontrollfelder
			unless ( $tag < 10 )
			{
				my @subfields = $field->subfields();

				#				say Dumper @subfields;
				foreach my $subfield (@subfields)
				{
					my ( $code, $data ) = @$subfield;
					my @_sf = $field->subfield($code);
					if ( exists $marc{$tag}{$code} )
					{
						if ( $marc{$tag}{$code} eq 'NR' && scalar @_sf > 1 )
						{
							$ind_or_sf = $code;
							$content = $data;
							$problem = "Unterfeld $code ist nicht wiederholbar";
							@warnings = ( $bib_id, $tag, $ind_or_sf, $content, $problem );
							say $fh_warnings join "\t", @warnings;

						}
					} else
					{
						$ind_or_sf = $code;
						$content = $data;
						$problem   = "Unterfeld $code ist nicht definiert.";
						@warnings  = ( $bib_id, $tag, $ind_or_sf, $content,$problem );
						say $fh_warnings join "\t", @warnings;
					}
				}
			}

			#			say $tag . ", ind2: ".$marc{$tag}{'ind2'};
		} else
		{
			$ind_or_sf = '-';
			$content = $field->as_string();
			$problem   = "Feld $tag ist nicht definiert";
			@warnings  = ( $bib_id, $tag, $ind_or_sf, $content, $problem );
			say $fh_warnings join "\t", @warnings;
		}

	}

	$i++;
}

say '____________________________________________';
say $i-1 ." ". $rule . "-Datensätze validiert.";
say "Siehe " . $rule."_warnings.txt für die einzelnen Fehlermeldungen.";

#TODO ps: Feld 034 $a hat feste Werte
#TODO ps: Feldinhalte auf nichtdruckbare Zeichen überprüfen
