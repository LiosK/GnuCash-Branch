#!/usr/bin/env perl

use utf8;
use strict;
use warnings;
use Getopt::Long;
use Time::Piece;

use GnuCash::Branch::Book::XML;
use GnuCash::Branch::FxRates;
use GnuCash::Branch::QIF;

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
    my $transactions = $book->list_transactions(
        from      => ($conf{'date-from'}       ne '') ? $conf{'date-from'}         : undef,
        to        => ($conf{'date-to'}         ne '') ? $conf{'date-to'}           : undef,
        skip_desc => ($conf{'closing-entries'} ne '') ? $conf{'closing-entries'}   : undef,
    );

    my $fx_rates = GnuCash::Branch::FxRates->load_tsv($conf{'fx-file'});
    $fx_rates->set_fraction($conf{'pr-crncy'});

    # walk through transactions
    my %qif = ();
    for my $trn (@$transactions) {
        # collect splits by currency
        my %splits = ();
        for my $sp ($trn->splits) {
            # translate foreign currency
            my $act = $sp->account;
            my $sp_crncy = $act->cmdty_id;
            my $sp_value = $sp->qty;
            if (!$act->is_currency) {
                $sp_crncy = 'Commodity_' . $trn->currency; # TODO
                $sp_value = $sp->value;
            } elsif ($act->is_pl && $sp_crncy ne $conf{'pr-crncy'}) {
                $sp_value = $fx_rates->convert($sp_value, $sp_crncy, $trn->date->epoch);
                die $trn->date->ymd . " $sp_crncy rate not found" if !defined $sp_value;
                $sp_crncy = $conf{'pr-crncy'};
            }

            $splits{$sp_crncy} = [] if !exists $splits{$sp_crncy};
            push $splits{$sp_crncy}, {
                act => $act,
                memo => $sp->memo,
                qty => $sp->qty,
                value => $sp_value,
            };
        }

        # generate currency-by-currency qif
        for my $y (keys %splits) {
            if ($y =~ /^Commodity_(.+)$/) {
                $qif{$y} = GnuCash::Branch::QIF->new if !exists $qif{$y};
                for my $z (@{$splits{$y}}) {
                    die 'Assert investment account has a parent' if $z->{'act'}->is_toplevel;
                    $qif{$y}->put_account(name => $z->{'act'}->parent->path);
                    $qif{$y}->put_investment(
                        date     => $trn->date->ymd('/'),
                        action   => ($z->{'qty'} > 0) ? 'BuyX' : 'SellX',
                        security => $z->{'act'}->name,
                        qty      => abs($z->{'qty'}),
                        memo     => $trn->description,
                        transfer => '[' . $conf{'transfer-account'} . ':' . $1 . ']',
                        amount   => abs($z->{'value'}),
                    );
                }
            } else {
                if (!exists $qif{$y}) {
                    $qif{$y} = GnuCash::Branch::QIF->new;
                    $qif{$y}->put_account(name => $conf{'transfer-account'} . ':' . $y);
                }

                $qif{$y}->begin_transaction(
                    date     => $trn->date->ymd('/'),
                    number   => $trn->number,
                    memo     => $trn->description,
                );
                for my $z (@{$splits{$y}}) {
                    $qif{$y}->add_split(
                        category => $z->{'act'}->path,
                        memo     => $z->{'memo'},
                        amount   => $z->{'value'},
                    );
                }
                $qif{$y}->end_transaction;
            }
        }
    }

    # write qif files
    for my $x (keys %qif) {
        open my $fh, '>:utf8', $conf{'output-prefix'} . $x . '.qif' or die 'Write mode error';
        print $fh $qif{$x}->to_string;
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
        'transfer-account' => 'Equity:Transfer',
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
