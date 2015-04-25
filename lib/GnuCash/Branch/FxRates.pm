package GnuCash::Branch::FxRates;

use utf8;
use strict;
use warnings;
use Time::Local;


# private constructor
sub _init {
    my ($class, %args) = @_;

    my ($dates, $prices) = ({}, {});
    if (exists $args{'dates'} && exists $args{'prices'}) {
        ($class, %args) = ($args{'dates'}, $args{'prices'});
    } elsif (exists $args{'hash'}) {
        for my $crncy (keys %{$args{'hash'}}) {
            my %pairs  = %{$args{'hash'}->{$crncy}};
            my @dates  = sort { $a <=> $b } keys %pairs;
            my @prices = map { $pairs{$_} } @dates;
            $dates->{$crncy}  = \@dates;
            $prices->{$crncy} = \@prices;
        }
    }

    return bless {
        _dates  => $dates,
        _prices => $prices,
        _memo   => {},
        _format => '%.2f',
    }, $class;
}

sub load_tsv {
    my ($class, $file) = @_;
    my $hash = {};
    open my $fh, '<:encoding(utf-8)', $file or die "Couldn't open the FX file";
    while (<$fh>) {
        chomp;
        next if $_ eq '';
        my ($crncy, $date, $price) = split "\t";

        warn "Invalid currency: $_" if $crncy !~ /^[A-Z]{3}$/;
        $hash->{$crncy} = {} if !exists $hash->{$crncy};

        if ($date =~ /^(\d{4})([-\/\.])(\d\d?)\2(\d\d?)$/) {
            my $epoch = timegm(0, 0, 0, $4, $3 - 1, $1);
            if (exists $hash->{$crncy}{$epoch}) {
                warn "Skipped duplicated date: $_";
            } else {
                $hash->{$crncy}{$epoch} = 0 + $price;
            }
        } else {
            warn "Skipped invalid date: $_";
        }
    }
    close $fh;
    return $class->_init( hash => $hash );
}

sub get_latest {
    my ($self, $crncy, $date) = @_;
    $date = int(time / 86400) * 86400 if !defined $date; # XXX 00:00:00 UTC

    return if !exists $self->{'_dates'}{$crncy};
    my $dates = $self->{'_dates'}{$crncy};
    return if $date < $dates->[0];
    return $self->{'_memo'}{$crncy, $date} if exists $self->{'_memo'}{$crncy, $date};

    my $i = @$dates - 1;
    $i -= 1024 while $i > 1023 && $date < $dates->[$i - 1023];
    $i -= 32   while $i > 31   && $date < $dates->[$i - 31];
    --$i       while $i > 0    && $date < $dates->[$i];

    return $self->{'_memo'}{$crncy, $date} = $self->{'_prices'}{$crncy}[$i];
}

my %fractions = (
    0   => 0, 1   => 1, 2   => 2, 3   => 3, 4   => 4, 5   => 5, 6   => 6, 7   => 7, 8   => 8,
    BHD => 3, BIF => 0, BYR => 0, CLF => 4, CLP => 0, DJF => 0, GNF => 0, IQD => 3, ISK => 0,
    JOD => 3, JPY => 0, KMF => 0, KRW => 0, KWD => 3, LYD => 3, OMR => 3, PYG => 0, RWF => 0,
    TND => 3, UGX => 0, UYI => 0, VND => 0, VUV => 0, XAF => 0, XOF => 0, XPF => 0,
);

sub set_fraction {
    my ($self, $f) = @_;
    $self->{'_format'} = '%.' . (defined $fractions{$f} ? $fractions{$f} : 2) . 'f';
    return $self;
}

sub convert {
    my $self = shift;
    my $qty  = shift;
    my $rate = $self->get_latest(@_);
    return defined $rate ? sprintf $self->{'_format'}, $qty * $rate : undef;
}

1;
