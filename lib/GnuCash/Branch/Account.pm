package GnuCash::Branch::Account;

use utf8;
use strict;
use warnings;

our $AUTOLOAD;
my %fields = (
    name        => undef,
    id          => undef,
    type        => undef,
    cmdty_space => undef,
    cmdty_id    => undef,
    code        => undef,
    description => undef,
    parent_id   => undef,
    path        => undef,
);

sub new {
    my ($class, $accounts, %args) = (@_, path => '');

    my $self = { _fs => {}, _parent => undef };
    for my $k (keys %fields) {
        die "Argument error: $k" if !defined $args{$k};
        $self->{'_fs'}{$k} = $args{$k};
    }

    my $pid = $self->{'_fs'}{'parent_id'};
    if ($pid ne '') {
        die 'Assert parent defined first' if !exists $accounts->{$pid};
        $self->{'_parent'} = $accounts->{$pid};
        $self->{'_fs'}{'path'}  = $self->{'_parent'}->path;
        $self->{'_fs'}{'path'} .= ($self->{'_fs'}{'path'} && ':') . $self->{'_fs'}{'name'};
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

sub is_root {
    my $self = shift;
    return !defined $self->{'_parent'};
}

sub parent {
    my $self = shift;
    return $self->{'_parent'};
}

sub is_toplevel {
    my $self = shift;
    return defined $self->{'_parent'} && $self->{'_parent'}->is_root;
}

sub is_pl {
    my $self = shift;
    my $type = $self->{'_fs'}{'type'};
    return $type eq 'INCOME' || $type eq 'EXPENSE';
}

sub is_currency {
    my $self = shift;
    return $self->{'_fs'}{'cmdty_space'} eq 'ISO4217';
}

sub is_template {
    my $self = shift;
    return $self->{'_fs'}{'cmdty_space'} eq 'template';
}

1;
