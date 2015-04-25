package GnuCash::Branch::QIF;

use utf8;
use strict;
use warnings;

sub new {
    return bless {
        _flg_account => 0,
        _transaction => undef,
        _lines => [],
    }, shift;
}

sub _put_line {
    my ($self, $letter, $value) = (@_, '');
    push $self->{'_lines'}, $letter          if $letter eq '^';
    push $self->{'_lines'}, $letter . $value if $value  ne '';
    return $self;
}

sub put_account {
    my $self = shift;
    die 'End transaction first' if defined $self->{'_transaction'};
    my %args = (name => '', type => '', description => '', @_);
    die 'Give valid argument: name' if $args{'name'} eq '';

    $self->{'_flg_account'} = 1;
    $self->_put_line('!', 'Account');
    $self->_put_line('N', $args{'name'});
    $self->_put_line('T', $args{'type'});
    $self->_put_line('D', $args{'description'});
    $self->_put_line('^');
    return $self;
}

sub put_investment {
    my $self = shift;
    die 'Put account first' if !$self->{'_flg_account'};
    die 'End transaction first' if defined $self->{'_transaction'};
    my %args = (
        date     => '',
        action   => '',
        security => '',
        qty      => '',
        memo     => '',
        transfer => '',
        amount   => '',
        @_,
    );

    $self->_put_line('!', 'Type:Invst');
    $self->_put_line('D', $args{'date'});
    $self->_put_line('N', $args{'action'});
    $self->_put_line('Y', $args{'security'});
    $self->_put_line('Q', $args{'qty'});
    $self->_put_line('M', $args{'memo'});
    $self->_put_line('L', $args{'transfer'});
    $self->_put_line('T', $args{'amount'});
    $self->_put_line('^');
    return $self;
}

sub begin_transaction {
    my $self = shift;
    die 'Put account first' if !$self->{'_flg_account'};
    die 'End transaction first' if defined $self->{'_transaction'};
    $self->{'_transaction'} = {
        type     => 'Bank',
        date     => '',
        number   => '',
        memo     => '',
        @_,
    };
    $self->{'_transaction'}{'balance'} = 0;
    $self->{'_transaction'}{'splits'}  = [];
    return $self;
}

sub add_split {
    my $self = shift;
    die 'Begin transaction first' if !defined $self->{'_transaction'};
    my $sp = { category => '', memo     => '', amount   => '', @_ };
    $self->{'_transaction'}{'balance'} -= $sp->{'amount'};
    push $self->{'_transaction'}{'splits'}, $sp;
    return $self;
}

sub end_transaction {
    my $self = shift;
    die 'Begin transaction first' if !defined $self->{'_transaction'};

    my $trn = $self->{'_transaction'};
    $self->_put_line('!', 'Type:' . $trn->{'type'});
    $self->_put_line('D', $trn->{'date'});
    $self->_put_line('T', $trn->{'balance'});
    $self->_put_line('N', $trn->{'number'});
    $self->_put_line('M', $trn->{'memo'});
    for my $sp (@{$trn->{'splits'}}) {
        $self->_put_line('S', $sp->{'category'});
        $self->_put_line('E', $sp->{'memo'});
        $self->_put_line('$', $sp->{'amount'});
    }
    $self->_put_line('^');

    $self->{'_transaction'} = undef;
    return $self;
}

sub to_string {
    my $self = shift;
    return join("\n", @{$self->{'_lines'}}) . "\n";
}

1;
