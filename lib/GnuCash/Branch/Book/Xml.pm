package GnuCash::Branch::Book::Xml;

use utf8;
use strict;
use warnings;
use Time::Piece;
use XML::LibXML;

use GnuCash::Branch::Account;

sub new {
    my ($class, $file) = @_;
    my $self = bless {
        _dom => XML::LibXML->load_xml(location => $file),
        _account_table => {},
    }, $class;
    return $self->_init_account_table;
}

sub get_accounts { my $self = shift; return $self->{'_account_table'}; }

sub _init_account_table {
    my $self = shift;
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
    return $self;
}

sub list_transactions {
    my $self = shift;
    my %args = (from => undef, to => undef, skip_desc => undef, @_);

    return \@{$self->{'_dom'}->getElementsByTagName('gnc:transaction')};

    my $transactions = [];
    for my $e ($self->{'_dom'}->getElementsByTagName('gnc:transaction')) {
        my $trn_memo  = $e->findvalue('trn:description');
        next if defined $args{'skip_desc'} && $trn_memo eq $args{'skip_desc'};
    }

    return @$transactions;
}

1;
