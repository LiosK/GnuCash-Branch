package GnuCash::Branch::Book::Xml;

use utf8;
use strict;
use warnings;
use XML::LibXML;
use GnuCash::Branch::Account;

sub new {
    my ($class, $file) = @_;
    return bless {
        _dom => XML::LibXML->load_xml(location => $file),
    }, $class;
}

sub get_accounts {
    my ($self, $accounts) = (shift, {});
    for my $e ($self->{'_dom'}->getElementsByTagName('gnc:account')) {
        my $id = $e->findvalue('act:id');
        die 'Assert unique account IDs' if exists $accounts->{$id};
        $accounts->{$id} = GnuCash::Branch::Account->new(
            $accounts,
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
    return $accounts;
}

sub list_transactions {
    my $self = shift;
    return $self->{'_dom'}->getElementsByTagName('gnc:transaction');
}

1;
