package GnuCash::Branch::Split;

use utf8;
use strict;
use warnings;

our $AUTOLOAD;
my %fields = (
    account   => undef,
    qty       => undef,
    value     => undef,
    memo      => undef,
    action    => undef,
    st_rec    => undef,
    id        => undef,
    val_crncy => undef,
);

sub new {
    my ($class, %args) = @_;

    my $self = { _fs => {} };
    for my $k (keys %fields) {
        die "Argument error: $k" if !defined $args{$k};
        $self->{'_fs'}{$k} = $args{$k};
    }

    return bless $self, $class;
}

sub AUTOLOAD {
    my $self = shift;
    my $field = $AUTOLOAD;
    $field =~ s/.*:://;
    die "Can't access '$AUTOLOAD'" if !exists $self->{'_fs'}{$field};
    return $self->{'_fs'}{$field};
}

1;
