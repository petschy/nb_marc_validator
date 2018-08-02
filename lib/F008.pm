package F008;

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
					 default => '008',
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

has 'country_codes' => (
						 is      => 'ro',
						 isa     => 'ArrayRef',
						 lazy    => 1,
						 builder => '_country_codes'
);

has 'country_codes_deprecated' => (
									is      => 'ro',
									isa     => 'ArrayRef',
									lazy    => 1,
									builder => '_country_codes_deprecated'
);

has 'language_codes' => (
						  is      => 'ro',
						  isa     => 'ArrayRef',
						  lazy    => 1,
						  builder => '_language_codes'
);

has 'language_codes_deprecated' => (
									 is      => 'ro',
									 isa     => 'ArrayRef',
									 lazy    => 1,
									 builder => '_language_codes_deprecated'
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

sub _country_codes
{
	my $self     = shift;
	my $config   = MyConfig->new();
	my $datafile = $config->datadir() . "COUNTRY_CODES";
	my $fh       = IO::File->new( $datafile, '<:utf8' );
	if ( defined $fh )
	{
		my @country_codes;
		while ( my $row = $fh->getline )
		{
			chomp $row;
			push @country_codes, $row;
		}
		undef $fh;

		return \@country_codes;
	} else
	{
		say "Die Datei $datafile ist nicht vorhanden.";
		exit;
	}
}

sub _country_codes_deprecated
{
	my $self     = shift;
	my $config   = MyConfig->new();
	my $datafile = $config->datadir() . "COUNTRY_CODES_DEPRECATED";
	my $fh       = IO::File->new( $datafile, '<:utf8' );
	if ( defined $fh )
	{
		my @country_codes_deprecated;
		while ( my $row = $fh->getline )
		{
			chomp $row;
			push @country_codes_deprecated, $row;
		}
		undef $fh;

		return \@country_codes_deprecated;
	} else
	{
		say "Die Datei $datafile ist nicht vorhanden.";
		exit;
	}
}

sub _language_codes
{
	my $self     = shift;
	my $config   = MyConfig->new();
	my $datafile = $config->datadir() . "LANGUAGE_CODES";
	my $fh       = IO::File->new( $datafile, '<:utf8' );
	if ( defined $fh )
	{
		my @language_codes;
		while ( my $row = $fh->getline )
		{
			chomp $row;
			push @language_codes, $row;
		}
		undef $fh;

		return \@language_codes;
	} else
	{
		say "Die Datei $datafile ist nicht vorhanden.";
		exit;
	}
}

sub _language_codes_deprecated
{
	my $self     = shift;
	my $config   = MyConfig->new();
	my $datafile = $config->datadir() . "LANGUAGE_CODES_DEPRECATED";
	my $fh       = IO::File->new( $datafile, '<:utf8' );
	if ( defined $fh )
	{
		my @language_codes_deprecated;
		while ( my $row = $fh->getline )
		{
			chomp $row;
			push @language_codes_deprecated, $row;
		}
		undef $fh;

		return \@language_codes_deprecated;
	} else
	{
		say "Die Datei $datafile ist nicht vorhanden.";
		exit;
	}
}

sub check
{
	my $self = shift;
	my ( $bib_id, $field, $warnings, $type_of_material ) = @_;

	my %codes                = %{ $self->codes };
	my %positions            = %{ $self->positions };
	my $tag                  = $field->tag();
	my $default_length       = 40;
	my $code                 = substr( $field->data(), 0, 1 );
	my $default_values       = '-';
	my @default_values_array = ();
	my $pos                  = '-';
	my $length               = length( $field->data() );
	my $length_ok            = "JA";
	my $type                 = $type_of_material;
	my %position;
	my $pattern;

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

	for ( my $i = 0 ; $i <= $length ; $i++ )
	{
		if ( $i < 18 || $i > 34 )
		{
			$type_of_material = "ALL";
			%position         = %{ $positions{$type_of_material} };
		} else
		{
			$type_of_material = $type;
			%position         = %{ $positions{$type_of_material} };
		}
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

	# ALL: 00-05 - Date entered on file
	$pos            = "00-05";
	$default_values = "6-stellige Zahl";
	$code           = quotemeta substr( $field->data(), 0, 6 );
	$pattern        = '^\d{6}$';
	unless ( $code =~ $pattern )
	{
		$code = unquotemeta($code);
		$code =~ tr/ /#/;
		my @message = (
						$bib_id,         $tag,            $pos,
						$code,           $default_values, $length,
						$default_length, $length_ok,      $type_of_material
		);
		$warnings->add_warning( \@message );
	}

	# ALL: 07-10 - Date 1
	$pos            = "07-10";
	$default_values = "4 Positionen mit Zahl, Leerschlag oder u; oder ||||";
	$code           = substr( $field->data(), 7, 4 );
	$pattern        = '^[\du ]{4}$|^\|{4}$';
	unless ( $code =~ $pattern )
	{
		$code =~ tr/ /#/;
		my @message = (
						$bib_id,         $tag,            $pos,
						$code,           $default_values, $length,
						$default_length, $length_ok,      $type_of_material
		);
		$warnings->add_warning( \@message );
	}

	# ALL: 11-14 - Date 2
	$pos            = "11-14";
	$default_values = "4 Positionen mit Zahl, Leerschlag oder u; oder ||||";
	$code           = substr( $field->data(), 11, 4 );
	$pattern        = '^[\du ]{4}$|^\|{4}$';
	unless ( $code =~ $pattern )
	{
		$code =~ tr/ /#/;
		my @message = (
						$bib_id,         $tag,            $pos,
						$code,           $default_values, $length,
						$default_length, $length_ok,      $type_of_material
		);
		$warnings->add_warning( \@message );
	}

	# ALL: 15-17 - Place of publication, production, or execution
	$pos                  = "15-17";
	$code                 = quotemeta substr( $field->data(), 15, 3 );
	@default_values_array = @{ $self->country_codes };
	$default_values       = "Code List for Countries";
	unless ( grep( /$code/, @default_values_array ) )
	{
		$code = unquotemeta($code);
		$code =~ tr/ /#/;
		my @message = (
						$bib_id,         $tag,            $pos,
						$code,           $default_values, $length,
						$default_length, $length_ok,      $type_of_material
		);
		$warnings->add_warning( \@message );
	}
	@default_values_array = @{ $self->country_codes_deprecated };
	$code                 = quotemeta substr( $field->data(), 15, 3 );
	$default_values       = "Deprecated Code List for Countries";
	if ( grep( /$code/, @default_values_array ) )
	{
		$code = unquotemeta($code);
		$code =~ tr/ /#/;
		my @message = (
						$bib_id,         $tag,            $pos,
						$code,           $default_values, $length,
						$default_length, $length_ok,      $type_of_material
		);
		$warnings->add_warning( \@message );
	}

	# ALL: 35-37 - Language
	$pos                  = "35-37";
	$code                 = quotemeta substr( $field->data(), 35, 3 );
	@default_values_array = @{ $self->language_codes };
	$default_values       = "Code List for Languages";
	unless ( grep( /$code/, @default_values_array ) )
	{
		$code = unquotemeta($code);
		$code =~ tr/ /#/;
		my @message = (
						$bib_id,         $tag,            $pos,
						$code,           $default_values, $length,
						$default_length, $length_ok,      $type_of_material
		);
		$warnings->add_warning( \@message );
	}
	@default_values_array = @{ $self->language_codes_deprecated };
	$code                 = quotemeta substr( $field->data(), 35, 3 );
	$default_values       = "Deprecated Code List for Languages";
	if ( grep( /$code/, @default_values_array ) )
	{
		$code = unquotemeta($code);
		$code =~ tr/ /#/;
		my @message = (
						$bib_id,         $tag,            $pos,
						$code,           $default_values, $length,
						$default_length, $length_ok,      $type_of_material
		);
		$warnings->add_warning( \@message );
	}

	# VM: 18-20 - Date 2
	if ( $type_of_material eq "VM" )
	{
		$pos            = "18-20";
		$default_values = "000-999, ---, nnn";
		$code           = substr( $field->data(), 18, 3 );
		$pattern = '^[\d]{3}$|^\|{3}$|^\-{3}$|^n{3}$';
		unless ( $code =~ $pattern )
		{
			$code =~ tr/ /#/;
			my @message = (
							$bib_id,         $tag,            $pos,
							$code,           $default_values, $length,
							$default_length, $length_ok,      $type_of_material
			);
			$warnings->add_warning( \@message );
		}
	}

}

__PACKAGE__->meta->make_immutable;
1;
