package F006;

use Modern::Perl '2017';
use autodie qw(:all);
use utf8::all;
use diagnostics;

use Moose;
use namespace::autoclean;
use String::Unquotemeta;

use Data::Dumper;

has 'data_file' => (
					 is      => 'ro',
					 isa     => 'Str',
					 lazy    => 1,
					 default => '006',
);

has 'codes' => (
				 is      => 'ro',
				 isa     => 'HashRef',
				 lazy    => 1,
				 builder => '_codes'
);

has 'positions' => (
					 is      => 'ro',
					 isa     => 'HashRef',
					 lazy    => 1,
					 builder => '_positions'
);

has 'form_of_material' => (
	is  => 'ro',
	isa => 'HashRef',

	#					 lazy    => 1,
	builder => '_set_form_of_material'
);

sub _codes
{
	my $self     = shift;
	my $config   = MyConfig->new();
	my $datafile = $config->datadir() . $self->data_file;
	my $fh       = IO::File->new( $datafile, '<:utf8' );
	if ( defined $fh )
	{
		my %table;
		while ( my $row = $fh->getline )
		{
			chomp $row;
			my @line = split /\t/, $row;
			push @{ $table{ $line[0] }{ $line[1] } }, $line[3];
		}
		undef $fh;
		return \%table;
	} else
	{
		say "Die Datei $datafile ist nicht vorhanden.";
		exit;
	}
}

sub _positions
{
	my $self     = shift;
	my $config   = MyConfig->new();
	my $datafile = $config->datadir() . $self->data_file . "_POSITIONS";
	my $fh       = IO::File->new( $datafile, '<:utf8' );
	if ( defined $fh )
	{
		my %table;
		while ( my $row = $fh->getline )
		{
			chomp $row;
			my @line = split /\t/, $row;
			push @{ $table{ $line[0] }{ $line[1] } }, ( $line[2], $line[3] );
		}
		undef $fh;
		return \%table;
	} else
	{
		say "Die Datei $datafile ist nicht vorhanden.";
		exit;
	}
}

sub _set_form_of_material
{
	my $self     = shift;
	my $code     = shift;
	my $config   = MyConfig->new();
	my $datafile = $config->datadir() . $self->data_file . "_FORM_OF_MATERIAL";
	my $fh       = IO::File->new( $datafile, '<:utf8' );
	if ( defined $fh )
	{
		my %table;
		while ( my $row = $fh->getline )
		{
			chomp $row;
			my ( $key, $value ) = split /\t/, $row;
			$table{$key} = $value;
		}
		undef $fh;
		return \%table;
	} else
	{
		say "Die Datei $datafile ist nicht vorhanden.";
		exit;
	}
}

sub _get_form_of_material
{
	my $self = shift;
	my $code = shift;
	my %hash = %{ $self->form_of_material };
	return $hash{$code};
}

sub check
{
	my $self = shift;
	my ( $bib_id, $field, $warnings ) = @_;

#	my $type_of_material = _get_form_of_material ($self, substr( $field->data(), 0, 1 ) );

	my %codes                = %{ $self->codes };
	my %positions            = %{ $self->positions };
	my $tag                  = $field->tag();
	my $default_length       = 18;
	my $code                 = substr( $field->data(), 0, 1 );
	my $default_values       = '-';
	my @default_values_array = ();
	my $pos                  = '-';
	my $length               = length( $field->data() );
	my $length_ok            = "JA";

	my $type_of_material = "INVALID";
	my %form_of_material = %{ $self->form_of_material };
	if ( $form_of_material{$code} )
	{
		$type_of_material = $form_of_material{$code};
	} else
	{
		foreach my $key ( keys %form_of_material )
		{
			push @default_values_array, $key;
		}
		$default_values = join( ", ", sort @default_values_array );
		$pos = "00";
		unless ( $length == $default_length ) {$length_ok = "NEIN"};
		my @message = (
						$bib_id,         $tag,            $pos,
						$code,           $default_values, $length,
						$default_length, $length_ok,      $type_of_material
		);
		$warnings->add_warning( \@message );
		return;
	}

	# Length of field
	unless ( $length == $default_length )
	{
		$code      = '-';
		$length_ok = 'NEIN';
		my @message = (
						$bib_id,         $tag,            $pos,
						$code,           $default_values, $length,
						$default_length, $length_ok,      $type_of_material
		);
		$warnings->add_warning( \@message );

	}

	my %position = %{ $positions{$type_of_material} };

	for ( my $i = 1 ; $i <= $length ; $i++ )
	{
		if ( defined $position{$i} )
		{
			( my $offset, $pos ) = @{ $position{$i} };
			if ( $i + $offset <= $length )
			{
				$code = substr( $field->data(), $i, $offset );
				$code =~ s/ /#/g;
				@default_values_array = @{ $codes{$type_of_material}{$pos} };
				$default_values = join( ", ", @default_values_array );
				if ( $type_of_material eq "VM" && $pos eq "01-03" )
				{
					my $pattern = '^[\d]{3}$|^\|{3}$|^\-{3}$|^n{3}$';
					unless ( $code =~ $pattern )
					{
						my @message = (
								  $bib_id, $tag,            $pos,
								  $code,   $default_values, $length,
								  $default_length, $length_ok, $type_of_material
						);
						$warnings->add_warning( \@message );
					}

				} else
				{
					$code = quotemeta $code;
					unless ( grep( /$code/, @default_values_array ) )
					{
						$code = unquotemeta($code);
						my @message = (
								  $bib_id, $tag,            $pos,
								  $code,   $default_values, $length,
								  $default_length, $length_ok, $type_of_material
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
