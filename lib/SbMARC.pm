package SbMARC;

use Modern::Perl '2017';
use autodie qw(:all);
use utf8::all;
use diagnostics;

use Moose;
use namespace::autoclean;


{
	extends 'StandardMARC';

}

sub _set_valid_data_file {
	my $config = MyConfig->new();
	return $config->datadir() . "SB_MARC";

}

sub check_local {
	my $self     = shift;
	my $record   = new MARC::Record;
	my $warnings = MARCWarnings->new();
	( $record, $warnings, my $bib_id ) = @_;

	&_check_sachgruppen( $record, $warnings, $bib_id );

}


sub _check_sachgruppen {
	my $record   = new MARC::Record;
	my $warnings = MARCWarnings->new();
	( $record, $warnings, my $bib_id ) = @_;

	my $config = MyConfig->new();
	my $file   = $config->datadir() . "SB_SACHGRUPPEN";
	my $fh     = IO::File->new( $file, '<:utf8' );
	my @sg;
	while (<$fh>) {
		chomp;
		push @sg, $_;
	}

	my @a082;
	my @a993;
	my @f993 = $record->field('993');
	if (@f993) {
		foreach my $f993 (@f993) {
			my @subfields = $f993->subfields();
			foreach my $subfield (@subfields) {
				my ( $code, $data ) = @$subfield;
				if ( $code eq 'c' ) {
					push @a993, $data;
					unless ( grep( /$data/, @sg ) ) {
						my $error = "Sachgruppe";
						my $ind_or_sf = $code;
						my $tag       = '993';
						my $content   = $data;
						my $problem   = "Ungültige Sachgruppe.";
						my @message =
						  ( $error, $bib_id, $tag, $ind_or_sf, $content, $problem );
						$warnings->add_warning( \@message );

					}
				}
			}

		}
	}

	my @f082 = $record->field('082');
	if (@f082) {
		foreach my $f082 (@f082) {
			if ( $f082->indicator(1) eq '7' && $f082->indicator(2) eq '4' ) {
				my @subfields = $f082->subfields();
				foreach my $subfield (@subfields) {
					my ( $code, $data ) = @$subfield;
					if ( $code eq 'a' ) {
						push @a082, $data;
						unless ( grep( /$data/, @sg ) ) {
							my $error = "Sachgruppe";
							my $ind_or_sf = $code;
							my $tag       = '082';
							my $content   = $data;
							my $problem   = "Ungültige Sachgruppe.";
							my @message =
							  ( $error, $bib_id, $tag, $ind_or_sf, $content, $problem );
							$warnings->add_warning( \@message );
						}
					}
				}
			}
		}
	}

	unless ( @a082 eq @a993 ) {
		my $error = "Sachgruppe";
		my $ind_or_sf = '-';
		my $tag       = '082/993';
		my $content   = "'@a082'/'@a993'";
		my $problem   = "Unterschiedliche Sachgruppen in 082 und 993";
		my @message   = ( $error, $bib_id, $tag, $ind_or_sf, $content, $problem );
		$warnings->add_warning( \@message );
	}
}

__PACKAGE__->meta->make_immutable;
1;
