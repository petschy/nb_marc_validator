package StandardMARC;

use Modern::Perl '2017';
use autodie qw(:all);
use utf8::all;
use diagnostics;

use Moose;
use namespace::autoclean;

use String::Util qw(trim);
use Data::Dumper;

# MARC
use MARC::File::USMARC;
use MARC::Record;
use MARC::Field;

# lib modules
use lib 'lib';
use StandardMARC;
use BsgMARC;
use SbMARC;
use NbMARC;

use F001;
use MARCWarnings;
use MyConfig;

has 'tags' => (
	is      => 'ro',
	isa     => 'HashRef',
	lazy    => 1,
	builder => '_tags'
);

has 'valid_data_file' => (
	is      => 'ro',
	isa     => 'Str',
	lazy    => 1,
	builder => '_set_valid_data_file'
);

sub _tags {
	my $self = shift;
	my @tag_array;
	my %tag_hash;
	local $/ = "\n\n";
	my $data_file = $self->valid_data_file;
	open my $data_fh, "<:utf8", $data_file;

	while ( my $block = <$data_fh> ) {
		my @_tag_array;
		my $tag;
		my $repeatable;
		my ( $column_1, $column_2 );
		chomp $block;

		# Zeilen in Array
		my @block = split "\n", $block;

		# Erste Zeile mit Feldnummer.
		# $column_1: Feldnummer
		# $column_2: R/NR
		my $firstline = shift @block;
		my @columns = split( /\s+/, $firstline, 3 );
		$tag = $column_1 = $columns[0];
		$column_2 = $columns[1];
		trim($tag);
		trim($column_1);
		trim($column_2);
		push @_tag_array, $column_1, $column_2;

		# Restliche Zeilen mit Indikatoren/Unterfeldern
		# $column_1: ind1/ind2 oder Unterfeld-Code
		# $column_2: Wert für Indikatoren oder R/NR für Unterfelder
		foreach my $line (@block) {
			@columns  = split( /\s+/, $line, 3 );
			$column_1 = $columns[0];
			$column_2 = $columns[1];
			if (
				length $column_1 !=
				0 )    # Keine leere Schlüsselwerte übernehmen
			{
				push @_tag_array, $column_1, $column_2;
				my %_tag_hash = @_tag_array;
				push @tag_array, $tag, \%_tag_hash;
			}
		}
	}

	%tag_hash = @tag_array;

	#	say Dumper \%tag_hash;
	return \%tag_hash;
}

sub ind_value {
	my $self      = shift;
	my $ind_value = shift;
	my @ind_array;
	$ind_value =~ s/^blank$/ /;
	$ind_value =~ s/b/ /;
	if ( $ind_value =~ /^(\d)-(\d)$/ ) {
		my $from  = substr $ind_value, 0, 1;
		my $until = substr $ind_value, 2, 1;
		for ( my $a = $from ; $a <= $until ; $a++ ) {
			push @ind_array, $a;
		}
		return @ind_array;
	}

	@ind_array = split '', $ind_value;
	return @ind_array;
}

sub _set_valid_data_file {
	my $config = MyConfig->new();
	return $config->datadir() . "STANDARD_MARC";
}

sub check_local {
	my $self = shift;

}

sub check_language {
	my $self     = shift;
	my $record   = new MARC::Record;
	my $warnings = MARCWarnings->new();
	( $record, $warnings, my $bib_id ) = @_;

	my $config = MyConfig->new();
	my $file   = $config->datadir() . "LANGUAGE_CODES";
	my $fh     = IO::File->new( $file, '<:utf8' );
	my @lang;
	while (<$fh>) {
		chomp;
		push @lang, $_;
	}

	my $lang1 = $record->field('008')->as_string;
	$lang1 = substr $lang1, 35, 3;
	unless ( grep( /$lang1/, @lang ) ) {
		my $error     = "Sprache";
		my $ind_or_sf = '35-37';
		my $tag       = '008';
		my $content   = $lang1;
		my $problem   = "Ungültiger Sprachencode.";
		my @message = ( $error, $bib_id, $tag, $ind_or_sf, $content, $problem );
		$warnings->add_warning( \@message );
	}

	my @lang2;
	my @f041 = $record->field('041');
	if (@f041) {
		foreach my $f041 (@f041) {
			my @subfields = $f041->subfields();
			foreach my $subfield (@subfields) {
				my ( $code, $data ) = @$subfield;
				if ( $code eq 'a' ) {
					push @lang2, $data;
					unless ( grep( /$data/, @lang ) ) {
						my $error     = "Sprache";
						my $ind_or_sf = $code;
						my $tag       = '041';
						my $content   = $data;
						my $problem   = "Ungültiger Sprachencode.";
						my @message   = (
							$error, $bib_id, $tag, $ind_or_sf, $content,
							$problem
						);
						$warnings->add_warning( \@message );
					}
				}
			}
		}
		unless ( grep( /$lang1/, @lang2 ) ) {
			my $error     = "Sprache";
			my $ind_or_sf = "-";
			my $tag       = '041';
			my $content   = "'$lang1'/'@lang2'";
			my $problem   = "Sprachencode in 008 nicht in 041a.";
			my @message =
			  ( $error, $bib_id, $tag, $ind_or_sf, $content, $problem );
			$warnings->add_warning( \@message );
		}
	}
}

sub non_printable_characters {
	my $self = shift;

	#	my $field = new MARC::Field;
	my $warnings = MARCWarnings->new();
	( my $field, $warnings, my $bib_id ) = @_;

	my $field_as_string = $field->as_string;

	my $regex = '(?![\x{0098}|\x{009C}])\p{C}';

	my @characters = split //, $field_as_string;

	my $print_warning = 0;
	foreach my $character (@characters) {
		if ( $character =~ /$regex/g ) {
			$print_warning = 1;
			my $replace = "[" . charnames::viacode( ord($character) ) . "]";
			$field_as_string =~ s/$character/$replace/;
		}
	}
	if ($print_warning) {
		my $error     = "Zeichensatz";
		my $ind_or_sf = '-';
		my $tag       = $field->tag;
		my $content   = $field_as_string;
		my $problem   = "Feld enthält nicht druckbare Zeichen.";
		my @message = ( $error, $bib_id, $tag, $ind_or_sf, $content, $problem );
		$warnings->add_warning( \@message );
	}

}

sub check_245 {
	my $self     = shift;
	my $warnings = MARCWarnings->new();
	( my $record, $warnings, my $bib_id, my @article ) = @_;

	# Feld 245
	my $field = $record->field('245');
	my $ind2  = $field->indicator(2);
	my $ind1  = $field->indicator(1);
	my $title = $record->title;

	########################
	# Artikel
	########################

	my $lang = $record->field('008')->as_string;
	$lang = substr $lang, 35, 3;
	my $regex = "^\\w* \|^\\w*'\|^\\w*-";

	if ( $title =~ m/$regex/g ) {
		my $position = pos($title);
		my $art      = lc substr( $title, 0, $position );
		my $key      = trim( $lang . "_" . $art );
		if ( grep ( /^$key$/, @article ) ) {
			if ( $ind2 == 0 ) {
				my $error     = "Artikel";
				my $ind_or_sf = "I2";
				my $tag       = $field->tag;
				my $content   = $ind2;
				my $problem =
"Möglicherweise ist '$art' ein Artikel für Sprache '$lang' ($title)";
				my @message =
				  ( $error, $bib_id, $tag, $ind_or_sf, $content, $problem );
				$warnings->add_warning( \@message );
			}
			elsif ( $ind2 != $position ) {
				my $error     = "Artikel";
				my $ind_or_sf = "I2";
				my $tag       = $field->tag;
				my $content   = $ind2;
				my $problem =
				  "'$art' hat Länge $position, aber Ind. 2 = $ind2 ($title)";
				my @message =
				  ( $error, $bib_id, $tag, $ind_or_sf, $content, $problem );
				$warnings->add_warning( \@message );

			}
		}
		else {
			unless ( $ind2 == 0 ) {
				my $error     = "Artikel";
				my $ind_or_sf = "I2";
				my $tag       = $field->tag;
				my $content   = $ind2;
				my $problem =
"Titel beginnt nicht mit Artikel ('$art' / $lang), aber Ind. 2 = $ind2. ($title)";
				my @message =
				  ( $error, $bib_id, $tag, $ind_or_sf, $content, $problem );
				$warnings->add_warning( \@message );

			}
		}

	}

	##########################
	# 1. Indikator
	##########################

	my @field1XX = $record->field('1..');
	if ( $ind1 eq '0' and @field1XX ) {

		my $error     = "Indikator";
		my $ind_or_sf = "I1";
		my $tag       = $field->tag;
		my $content   = $ind1;
		my $problem =
		  "Indikator 1 hat den Wert 0, es ist aber ein Feld 1XX vorhanden.";
		my @message = ( $error, $bib_id, $tag, $ind_or_sf, $content, $problem );
		$warnings->add_warning( \@message );
	}
	elsif ( $ind1 eq '1' and !@field1XX ) {
		my $error     = "Indikator";
		my $ind_or_sf = "I1";
		my $tag       = $field->tag;
		my $content   = $ind1;
		my $problem =
		  "Indikator 1 hat den Wert 1, es ist aber kein Feld 1XX vorhanden.";
		my @message = ( $error, $bib_id, $tag, $ind_or_sf, $content, $problem );
		$warnings->add_warning( \@message );

	}

	##########################
	# Interpunktion
	##########################

	my @subfields = $field->subfields();

	for ( my $index = 0 ; $index <= $#subfields ; $index += 1 ) {

# Das Unterfeld vor Unterfeld $b muss enden mit Leerschlag Doppelpunkt, Leerschlat Strichpunkt, Leerschlag Gleichheitszeichen oder mit Punkt
		if (   $subfields[$index][0] eq 'b'
			&& $subfields[ $index - 1 ][1] !~ /( [:;=]|\.)$/ )
		{
			my $error     = "Interpunktion";
			my $ind_or_sf = $subfields[$index][0];
			my $tag       = $field->tag;
			my $content   = $subfields[$index][1];
			my $problem =
"Falsche Interpunktion vor Unterfeld \$b: \$$subfields[$index-1][0] $subfields[$index-1][1] \$$subfields[$index][0] $subfields[$index][1]";
			my @message =
			  ( $error, $bib_id, $tag, $ind_or_sf, $content, $problem );
			$warnings->add_warning( \@message );

		}

		#D Das Unterfeld vor Unterfeld $c muss enden mit Schrägstrich
		if (   $subfields[$index][0] eq 'c'
			&& $subfields[ $index - 1 ][1] !~ /\s\/$/ )
		{
			my $error     = "Interpunktion";
			my $ind_or_sf = $subfields[$index][0];
			my $tag       = $field->tag;
			my $content   = $subfields[$index][1];
			my $problem =
"Falsche Interpunktion vor Unterfeld \$c: \$$subfields[$index-1][0] $subfields[$index-1][1] \$$subfields[$index][0] $subfields[$index][1]";
			my @message =
			  ( $error, $bib_id, $tag, $ind_or_sf, $content, $problem );
			$warnings->add_warning( \@message );

		}

		# Initialen in Unterfeld $c dürfen keine Leerschläge enthalten
		if (   $subfields[$index][0] eq 'c'
			&& $subfields[$index][1] =~ /\b\w\. \b\w\./ )
		{
			my $error     = "Interpunktion";
			my $ind_or_sf = $subfields[$index][0];
			my $tag       = $field->tag;
			my $content   = $subfields[$index][1];
			my $problem =
"Initialen in Unterfeld \$c dürfen keine Leerschläge enthalten: $subfields[$index][1]";
			my @message =
			  ( $error, $bib_id, $tag, $ind_or_sf, $content, $problem );
			$warnings->add_warning( \@message );

		}

		# Das Feld vor Unterfeld $n muss mit einem Punkt enden
		if (   $subfields[$index][0] eq 'n'
			&& $subfields[$index][1] =~ /(\S\.$)|(\-\- \.$)/ )
		{
			my $error     = "Interpunktion";
			my $ind_or_sf = $subfields[$index][0];
			my $tag       = $field->tag;
			my $content   = $subfields[$index][1];
			my $problem =
"Das Feld vor Unterfeld \$n muss mit einem Punkt enden: \$$subfields[$index-1][0] $subfields[$index-1][1] \$$subfields[$index][0] $subfields[$index][1]";
			my @message =
			  ( $error, $bib_id, $tag, $ind_or_sf, $content, $problem );
			$warnings->add_warning( \@message );

		}

# Das Feld vor Unterfeld $p muss mit einem Komma ohne Leerschlag enden, wenn es ein Unterfeld $n ist,
# sonst sonst mit einem Punkt ohne Leerschlag oder mit Bindestrich Leerschlag Punkt
		if ( $subfields[$index][0] eq 'p' ) {
			if (   $subfields[ $index - 1 ][0] eq 'n'
				&& $subfields[ $index - 1 ][1] !~ /(\S,$)|(\-\- ,$)/ )
			{
				my $error     = "Interpunktion";
				my $ind_or_sf = $subfields[$index][0];
				my $tag       = $field->tag;
				my $content   = $subfields[$index][1];
				my $problem =
"Das Feld vor Unterfeld \$p muss mit einem mit einem Komma ohne Leerschlag enden, wenn es ein Unterfeld \$n ist: \$$subfields[$index-1][0] $subfields[$index-1][1] \$$subfields[$index][0] $subfields[$index][1]";
				my @message =
				  ( $error, $bib_id, $tag, $ind_or_sf, $content, $problem );
				$warnings->add_warning( \@message );

			}
			elsif ($subfields[ $index - 1 ][0] ne 'n'
				&& $subfields[ $index - 1 ][1] !~ /(\S\.$)|(\-\- \.$)/ )
			{
				my $error     = "Interpunktion";
				my $ind_or_sf = $subfields[$index][0];
				my $tag       = $field->tag;
				my $content   = $subfields[$index][1];
				my $problem =
"Das Feld vor Unterfeld \$p muss mit einem mit einem einem Punkt ohne Leerschlag oder mit Bindestrich Leerschlag Punkt enden, wenn es kein Unterfeld \$n ist: \$$subfields[$index-1][0] $subfields[$index-1][1] \$$subfields[$index][0] $subfields[$index][1]";
				my @message =
				  ( $error, $bib_id, $tag, $ind_or_sf, $content, $problem );
				$warnings->add_warning( \@message );

			}
		}
	}

}

sub check_264 {
	# Wenn in Feld 264 der 2. Indikator gleich 4 ist, ist nur Unterfeld $c erlaubt
	
	my $self = shift;
	( my $record, my $warnings, my $bib_id ) = @_;
	my @f264 = $record->field('264');
	if (@f264) {
		foreach my $field (@f264) {
			if ( $field->indicator(2) eq '4' ) {
				my @subfields = $field->subfields();
				my @codes;
				foreach my $subfield (@subfields) {
					my ( $code, $data ) = @$subfield;
					unless ( $code eq 'c' ) {
						my $error     = "MARC";
						my $ind_or_sf = $code;
						my $tag       = '264';
						my $content   = $field->as_string();
						my $problem =
						  "Nur Unterfeld c ist erlaubt (2. Indikator = 4).";
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

__PACKAGE__->meta->make_immutable;
1;
