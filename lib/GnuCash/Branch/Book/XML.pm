package GnuCash::Branch::Book::XML;

use utf8;
use strict;
use warnings;
use Time::Piece;
use XML::LibXML;

use GnuCash::Branch::Account;
use GnuCash::Branch::Transaction;
use GnuCash::Branch::Split;

sub new {
    my ($class, $file) = @_;
    my $self = bless {
        _dom => XML::LibXML->load_xml(location => $file),
        _account_table => undef,
    }, $class;
    return $self;
}

sub get_accounts {
    my $self = shift;
    $self->{'_account_table'} ||= $self->_build_account_table;
    return wantarray ? %{$self->{'_account_table'}} : $self->{'_account_table'};
}

sub _build_account_table {
    my $self = shift;
    $self->{'_account_table'} = {};
    for my $e ($self->{'_dom'}->getElementsByTagName('gnc:account')) {
        my $id = $e->findvalue('act:id');
        die 'Assert unique account IDs' if exists $self->{'_account_table'}{$id};
        $self->{'_account_table'}{$id} = GnuCash::Branch::Account->new(
            $self->{'_account_table'},
            id          => $id,
            name        => $e->findvalue('act:name'),
            type        => $e->findvalue('act:type'),
            cmdty_space => $e->findvalue('act:commodity/cmdty:space'),
            cmdty_id    => $e->findvalue('act:commodity/cmdty:id'),
            code        => $e->findvalue('act:code'),
            description => $e->findvalue('act:description'),
            parent_id   => $e->findvalue('act:parent'),
        );
    }
    return $self->{'_account_table'};
}

sub list_transactions {
    my $self = shift;
    my %args = (from => undef, to => undef, skip_desc => undef, @_);

    my $transactions = [];
    my $accounts = $self->get_accounts;
    for my $x ($self->{'_dom'}->findnodes('//gnc:book/gnc:transaction')) {
        # grep by description
        my $trn_desc  = $x->findvalue('trn:description');
        next if defined $args{'skip_desc'} && $trn_desc eq $args{'skip_desc'};

        # grep by date
        my $trn_date = Time::Piece->strptime(
            substr($x->findvalue('trn:date-posted/ts:date'), 0, 10), '%Y-%m-%d');
        next if defined $args{'from'} && $trn_date < $args{'from'};
        next if defined $args{'to'}   && $trn_date > $args{'to'};  # XXX assert 00:00:00 UTC

        die 'Assert currency for transaction measurement' if (
            $x->findvalue('trn:currency/cmdty:space') ne 'ISO4217');

        my $trn = GnuCash::Branch::Transaction->new(
            date        => $trn_date,
            description => $trn_desc,
            number      => $x->findvalue('trn:num'),
            currency    => $x->findvalue('trn:currency/cmdty:id'),
        );

        # collect splits
        for my $y ($x->getElementsByTagName('trn:split')) {
            my $sp_act   = $y->findvalue('split:account');
            die 'Assert account exists' if !defined $accounts->{$sp_act};

            my ($qty_n, $qty_d) = ($y->findvalue('split:quantity') =~ /^(-?\d+)\/(\d+)$/);
            my ($val_n, $val_d) = ($y->findvalue('split:value')    =~ /^(-?\d+)\/(\d+)$/);

            $trn->add_split(
                GnuCash::Branch::Split->new(
                    account   => $accounts->{$sp_act},
                    qty       => $qty_n / $qty_d,
                    value     => $val_n / $val_d,
                    memo      => $y->findvalue('split:memo'),
                    action    => $y->findvalue('split:action'),
                    st_rec    => $y->findvalue('split:reconciled-state'),
                    id        => $y->findvalue('split:id'),
                    val_crncy => $trn->currency,
                )
            );
        }

        push $transactions, $trn;
    }

    return wantarray ? @$transactions : $transactions;
}

1;
