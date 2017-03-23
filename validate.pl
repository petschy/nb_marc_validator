#!/usr/bin/env perl
use Modern::Perl '2017';
use autodie qw(:all);
use utf8::all;
use diagnostics;

# MARC
use MARC::File::USMARC;
use MARC::Record;
use MARC::Field;

# @ARGV
# Marc file
my $marcfile = shift;
my @rules    = ( "Standard", "Bsg", "SB" );
my $rule     = shift;
unless ( grep /^$rule$/, @rules )
{
	say "Usage: 'perl validate.pl [filename].mrc Standard|Sb|Bsg'";
	exit -1;
}

# Warnings
my $bib_id      = "BIB_ID";
my $tag         = "TAG";
my $ind_or_sf   = "IND/SF";
my $problem     = "PROBLEM";
my @warnings    = ( $bib_id, $tag, $ind_or_sf, $problem );
my $fh_warnings = IO::File->new( "warnings.txt", "w" );
say $fh_warnings join "\t", @warnings;    # Write headings to warnings file

