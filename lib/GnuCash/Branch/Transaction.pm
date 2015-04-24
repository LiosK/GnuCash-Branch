package GnuCash::Branch::Transaction;

use utf8;
use strict;
use warnings;

our $AUTOLOAD;
my %fields = (
    date        => undef,
    description => undef,
    number      => undef,
    currency    => undef,
);

sub new {
    my ($class, %args) = @_;

    my $self = { _fs => {}, _splits => [] };
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

sub add_split {
    my $self = shift;
    push $self->{'_splits'}, @_;
    return $self;
}

sub splits {
    my $self = shift;
    return $self->{'_splits'};
}

1;
