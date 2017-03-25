package StandardMARC;

use Modern::Perl '2017';
use autodie qw(:all);
use utf8::all;
use diagnostics;

use Moose;
use namespace::autoclean;

use String::Util qw(trim);
use Data::Dumper;

has 'tags' => (
				is      => 'ro',
				isa     => 'HashRef',
				lazy    => 1,
				builder => '_tags'
);

has 'marcfile' => (
				is      => 'ro',
				isa     => 'Str',
				lazy    => 1,
				builder => '_set_marcfile'
);

sub _tags
{
	my $self = shift;
	my @tag_array;
	my %tag_hash;
	local $/ = "\n\n";
#	my $data_file = "data/STANDARD_MARC";
my $data_file = $self->marcfile;
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

sub _ind_value
{
	my $ind_value = shift;

	#	say "-----------------> 1: |$ind_value|";
	$ind_value =~ s/^blank$/ /;

	#	say "-----------------> 2: |$ind_value|";
	$ind_value =~ s/b/ /;

	#	say "-----------------> 3: |$ind_value|";
	my @ind_array = split '', $ind_value;

	#			say "------------------ ind_array:> ".join('',@ind_array);
	return @ind_array;
}

sub _set_marcfile {
	return "data/STANDARD_MARC";
}

__PACKAGE__->meta->make_immutable;
1;
