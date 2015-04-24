#!/usr/bin/env perl

use utf8;
use strict;
use warnings;
use Getopt::Long;
use Time::Piece;

use GnuCash::Branch::Book::XML;
use GnuCash::Branch::FxRates;

=head1 NAME

translate_foreign_book.pl - Translate a GnuCash book that is measured in a foreign currency and export it into several QIF files.

=head1 SYNOPSIS

    translate_foreign_book.pl [--date-from=date] [--date-to=date] [--pr-crncy=currency] --fx-file=file file

=head1 DESCRIPTION

translate_foreign_book.pl translates a GnuCash book that is measured in a foreign currency and exports it into several QIF files.

=head1 EXAMPLE

    translate_foreign_book.pl --date-from=2014-01-01 --date-to=2014-12-31 --pr-crncy=USD --fx-file=fx.tsv my_book_in_eur.gnucash

=head1 AUTHOR

LiosK E<lt>contact@mail.liosk.netE<gt>

=cut

main();

sub main {
    my %conf = get_config();
    die 'Give a gnucash xml file as argument' if (!$ARGV[0]);
    my $book = GnuCash::Branch::Book::XML->new($ARGV[0]);
    my $accounts = $book->get_accounts;

    my $fx_rates = GnuCash::Branch::FxRates->load_tsv($conf{'fx-file'});
    $fx_rates->set_fraction($conf{'pr-crncy'});

    # walk through transactions
    my %qif = ();
    for my $x (@{$book->list_transactions}) {
        my $trn_date = Time::Piece->strptime(
            substr($x->findvalue('trn:date-posted/ts:date'), 0, 10), '%Y-%m-%d');
        my $trn_memo  = $x->findvalue('trn:description');
        my $trn_crncy = $x->findvalue('trn:currency/cmdty:id');
        die 'Assert currency for transaction measurement' if $x->findvalue('trn:currency/cmdty:space') ne 'ISO4217';

        # grep
        next if $conf{'date-from'} && ($trn_date < $conf{'date-from'});
        next if $conf{'date-to'}   && ($trn_date > $conf{'date-to'}); # XXX
        next if $conf{'closing-entries'} && ($trn_memo eq $conf{'closing-entries'});

        # collect splits by currency
        my %splits = ();
        for my $y ($x->getElementsByTagName('trn:split')) {
            my $sp_act   = $y->findvalue('split:account');
            my $sp_qty   = $y->findvalue('split:quantity');
            my $sp_value = $y->findvalue('split:value');
            my $sp_memo  = $y->findvalue('split:memo');

            # set up in accordance with account types
            die 'Assert account exists' if !exists $accounts->{$sp_act};
            my $act = $accounts->{$sp_act};
            my $sp_crncy  = $act->cmdty_id;
            my $src_crncy = $sp_crncy;
            my $src_value = $sp_qty;
            if (!$act->is_currency) {
                next if $act->is_template;
                $sp_crncy  = 'Commodity';
                $src_crncy = $trn_crncy;
                $src_value = $sp_value;
            } elsif ($act->is_pl) {
                $sp_crncy  = $conf{'pr-crncy'};
            }

            # translate foreign currency
            $sp_value = eval $src_value;
            if ($sp_crncy ne $src_crncy) {
                $sp_value = $fx_rates->convert($sp_value, $src_crncy, $trn_date->epoch);
                die $trn_date->ymd . " $src_crncy rate not found" if !defined $sp_value;
            }

            $splits{$sp_crncy} = [] if !exists $splits{$sp_crncy};
            push $splits{$sp_crncy}, {
                act => $act,
                memo => $sp_memo,
                qty => eval $sp_qty,
                value => $sp_value,
            };
        }

        # generate currency-by-currency qif
        for my $y (keys %splits) {
            if ($y eq 'Commodity') {
                $qif{$y} = [] if !exists $qif{$y};
                my $txt = '';
                for my $z (@{$splits{$y}}) {
                    die 'Assert investment account has a parent' if $z->{'act'}->is_toplevel;
                    push $qif{$y}, sprintf(
                        "!Account\nN%s\n^\n!Type:Invst\nD%s\nN%sX\nY%s\nQ%s\nT%s\nL%s:%s\nM%s\n^\n",
                        $z->{'act'}->parent->path,
                        $trn_date->ymd('/'),
                        ($z->{'qty'} > 0) ? 'Buy' : 'Sell',
                        $z->{'act'}->name,
                        abs($z->{'qty'}),
                        abs($z->{'value'}),
                        $conf{'transfer-account'},
                        $conf{'pr-crncy'},
                        $trn_memo,
                    );
                }
            } else {
                if (!exists $qif{$y}) {
                    $qif{$y} = [
                        sprintf("!Account\nN%s:%s\n^\n", $conf{'transfer-account'}, $y),
                    ];
                }

                my ($txt, $balance) = ('', 0);
                for my $z (@{$splits{$y}}) {
                    $txt .= sprintf "S%s\n\$%s\nE%s\n", $z->{'act'}->path, $z->{'value'}, $z->{'memo'};
                    $balance -= $z->{'value'};
                }

                push $qif{$y}, sprintf(
                    "!Type:Cash\nD%s\nM%s\nT%s\n%s^\n",
                    $trn_date->ymd('/'),
                    $trn_memo,
                    $balance,
                    $txt,
                );
            }
        }
    }

    # output qif files
    for my $x (keys %qif) {
        open my $fh, '>:utf8', $conf{'output-prefix'} . $x . '.qif' or die 'Write mode error';
        print $fh join('', @{$qif{$x}});
        close $fh;
    }
}


# Get configurations from command-line options etc.
sub get_config {
    my %conf =(
        'date-from' => '',
        'date-to' => '',
        'fx-file' => '',
        'output-prefix' => './',
        'pr-crncy' => 'USD',
        'transfer-account' => 'Equity:Translation Adjustments',
        'closing-entries' => 'Closing Entries',
    );

    Getopt::Long::GetOptions(
        \%conf,
        'date-from=s',
        'date-to=s',
        'fx-file=s',
        'output-prefix=s',
        'pr-crncy=s',
        'transfer-account=s',
        'closing-entries=s',
    );

    $conf{'date-from'} = Time::Piece->strptime($conf{'date-from'}, "%Y-%m-%d")->epoch;
    $conf{'date-to'}   = Time::Piece->strptime($conf{'date-to'},   "%Y-%m-%d")->epoch;

    return wantarray ? %conf : \%conf;
}
