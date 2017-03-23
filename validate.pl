#!/usr/bin/env perl
use Modern::Perl '2017';
use autodie qw(:all);
use utf8::all;
use diagnostics;

# MARC
use MARC::File::USMARC;
use MARC::Record;
use MARC::Field;

# lib modules
use lib 'lib';
use StandardBibId;
use BsgBibId;
use SbBibId;

# Marc file
my $marcfile = shift;
$marcfile = "mrc/$marcfile";
my $rule = shift;
my @rules = ( "Standard", "Bsg", "Sb" );
unless ( grep /^$rule$/, @rules )
{
	say "Usage: 'perl validate.pl [filename].mrc Standard|Sb|Bsg'";
	exit -1;
}

# Warnings
my $bib_id    = "BIB_ID";
my $tag       = "TAG";
my $ind_or_sf = "IND/SF";
my $problem   = "PROBLEM";
my @warnings;
my @warnings_heading = ( $bib_id, $tag, $ind_or_sf, $problem );
my $fh_warnings = IO::File->new( $rule . "_warnings.txt", '>:utf8' );
say $fh_warnings join "\t", @warnings_heading;

my $i       = 1;
my $records = MARC::File::USMARC->in($marcfile);
while ( my $record = $records->next() )
{

	my $bib_id = "${\$rule}BibId"->new();
	@warnings = $bib_id->set_bib_id( $record->field('001')->as_string() );
	say "Record no $i: BibId " . $bib_id->bib_id;
	if (@warnings) { say $fh_warnings join "\t", @warnings; }

	$i++;
}
