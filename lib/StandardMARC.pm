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

sub _tags
{
	my $self = shift;
	my @tag_array;
	my %tag_hash;
	local $/ = "\n\n";
	my $data_file = $self->valid_data_file;
	open my $data_fh, "<:utf8", $data_file;

	while ( my $block = <$data_fh> )
	{
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
		foreach my $line (@block)
		{
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

sub ind_value
{
	my $self      = shift;
	my $ind_value = shift;
	my @ind_array;
	$ind_value =~ s/^blank$/ /;
	$ind_value =~ s/b/ /;
	if ( $ind_value =~ /^(\d)-(\d)$/ )
	{
		my $from  = substr $ind_value, 0, 1;
		my $until = substr $ind_value, 2, 1;
		for ( my $a = $from ; $a <= $until ; $a++ )
		{
			push @ind_array, $a;
		}
		return @ind_array;
	}

	@ind_array = split '', $ind_value;
	return @ind_array;
}

sub _set_valid_data_file
{
	my $config = MyConfig->new();
	return $config->datadir() . "STANDARD_MARC";
}

sub check_local
{
	my $self = shift;

}

sub check_language
{
	my $self     = shift;
	my $record   = new MARC::Record;
	my $warnings = MARCWarnings->new();
	( $record, $warnings, my $bib_id ) = @_;

	my $config = MyConfig->new();
	my $file   = $config->datadir() . "LANGUAGE_CODES";
	my $fh     = IO::File->new( $file, '<:utf8' );
	my @lang;
	while (<$fh>)
	{
		chomp;
		push @lang, $_;
	}

	my $lang1 = $record->field('008')->as_string;
	$lang1 = substr $lang1, 35, 3;
	unless ( grep( /$lang1/, @lang ) )
	{
		my $ind_or_sf = '35-37';
		my $tag       = '008';
		my $content   = $lang1;
		my $problem   = "Ungültiger Sprachencode.";
		my @message   = ( $bib_id, $tag, $ind_or_sf, $content, $problem );
		$warnings->add_warning( \@message );
	}

	my @lang2;
	my @f041 = $record->field('041');
	if (@f041)
	{
		foreach my $f041 (@f041)
		{
			my @subfields = $f041->subfields();
			foreach my $subfield (@subfields)
			{
				my ( $code, $data ) = @$subfield;
				if ( $code eq 'a' )
				{
					push @lang2, $data;
					unless ( grep( /$data/, @lang ) )
					{
						my $ind_or_sf = $code;
						my $tag       = '041';
						my $content   = $data;
						my $problem   = "Ungültiger Sprachencode.";
						my @message =
						  ( $bib_id, $tag, $ind_or_sf, $content, $problem );
						$warnings->add_warning( \@message );
					}
				}
			}
		}
		unless ( grep( /$lang1/, @lang2 ) )
		{
			my $ind_or_sf = "-";
			my $tag       = '041';
			my $content   = "'$lang1'/'@lang2'";
			my $problem   = "Sprachencode in 008 nicht in 041a.";
			my @message   = ( $bib_id, $tag, $ind_or_sf, $content, $problem );
			$warnings->add_warning( \@message );
		}
	}
}

sub non_printable_characters
{
	my $self = shift;

	#	my $field = new MARC::Field;
	my $warnings = MARCWarnings->new();
	( my $field, $warnings, my $bib_id ) = @_;

	my $field_as_string = $field->as_string;

	my $regex = '(?![\x{0098}|\x{009C}])\p{C}';

	my @characters = split //, $field_as_string;

	my $print_warning = 0;
	foreach my $character (@characters)
	{
		if ( $character =~ /$regex/g )
		{
			$print_warning = 1;
			my $replace = "[" . charnames::viacode( ord($character) ) . "]";
			$field_as_string =~ s/$character/$replace/;
		}
	}
	if ($print_warning)
	{
		my $ind_or_sf = '-';
		my $tag       = $field->tag;
		my $content   = $field_as_string;
		my $problem   = "Feld enthält nicht druckbare Zeichen.";
		my @message   = ( $bib_id, $tag, $ind_or_sf, $content, $problem );
		$warnings->add_warning( \@message );
	}

	# Feld auf nicht druckbare Zeichen überprüfen
	#	if ( $field_as_string =~ m/(?![\x{0098}|\x{009C}])\p{C}/g )
	#	{
	#		$field_as_string =~ s/\p{C}/¬/g;
	#		my $ind_or_sf = '-';
	#		my $tag       = $field->tag;
	#		my $content   = $field_as_string;
	#		my $problem   = "Feld enthält nicht druckbare Zeichen.";
	#		my @message   = ( $bib_id, $tag, $ind_or_sf, $content, $problem );
	#		$warnings->add_warning( \@message );
	#
	#	}

}

__PACKAGE__->meta->make_immutable;
1;
