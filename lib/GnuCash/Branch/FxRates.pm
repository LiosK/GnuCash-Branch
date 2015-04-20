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

    return bless { _dates => $dates, _prices => $prices, _memo => {} }, $class;
}

sub load_tsv {
    my ($class, $file) = @_;
    my %hash = ();
    open my $fh, '<:encoding(utf-8)', $file or die "Couldn't open the FX file";
    while (<$fh>) {
        chomp;
        next if $_ eq '';
        my ($crncy, $date, $price) = split "\t";

        warn "Invalid currency: $_" if $crncy !~ /^[A-Z]{3}$/;
        $hash{$crncy} = {} if !exists $hash{$crncy};

        if ($date =~ /^(\d{4})[-\/](\d\d?)[-\/](\d\d?)$/) {
            my $epoch = timegm(0, 0, 0, $3, $2 - 1, $1);
            if (exists $hash{$crncy}->{$epoch}) {
                warn "Skipped duplicated date: $_";
            } else {
                $hash{$crncy}->{$epoch} = 0 + $price;
            }
        } else {
            warn "Skipped invalid date: $_";
        }
    }
    close $fh;
    return $class->_init( hash => \%hash );
}

sub get_latest {
    my ($self, $crncy, $date) = @_;
    $date ||= int(time / 86400) * 86400; # XXX 00:00:00 UTC

    return if !exists $self->{'_dates'}->{$crncy};
    my $dates = $self->{'_dates'}->{$crncy};
    return if $date < $dates->[0];
    return $self->{'_memo'}->{$crncy, $date} if exists $self->{'_memo'}->{$crncy, $date};

    my $i = @$dates - 1;
    $i -= 1024 while ($i > 1023) && ($date < $dates->[$i - 1023]);
    $i -= 32   while ($i > 31)   && ($date < $dates->[$i - 31]);
    --$i       while ($i > 0)    && ($date < $dates->[$i]);

    return $self->{'_memo'}->{$crncy, $date} = $self->{'_prices'}->{$crncy}->[$i];
}

1;
