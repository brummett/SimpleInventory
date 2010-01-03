#!/usr/bin/perl
use strict;
use warnings;

use Inventory;
use IO::File;

my $db = Inventory->connect();
unless ($db) {
    print STDERR "Can't create/connect to DB inventory.sqlite3: ".$DBI::errstr."\n";
    exit 1;
}

my $froogle = IO::File->new(">froogle.csv") || die "Can't open froogle.csv for writing: $!";
my $amazon = IO::File->new(">amazon.csv") || die "Can't open amazon.csv for writing: $!";

my $first_line = <>;
chomp($first_line);
my @first_line = split /\t/,$first_line;
unless ($first_line[3] eq 'price' and $first_line[6] eq 'offer_id' and $first_line[10] eq 'upc') {
    print STDERR "Input file has bad layout, expected 'price' ion column D, 'offer_id' in column G and 'upc' in column K\n";
    print STDERR "Got: ",$first_line[3],", ",$first_line[6]," and ",$first_line[10],"\n";
    $db->disconnect;
    exit;
}
$froogle->print($first_line,"\tcondition\n");
$amazon->print("product-id\tproduct-id-type\titem-condition\tprice\tsku\tquantity\tadd-delete\twill-ship-internationally\texpedited-shipping\titem-note\n");

while(<>) {
    chomp;
    my @fields = split /\t/;

    if ($fields[10]) {
        print STDERR "Item on line $. already has a barcode?!\n";
        next;
    }
 
    my $sku = $fields[6];
    unless ($sku) {
        print STDERR "Item on line $. has no sku\n";
        next;
    }

    my $item = $db->lookup_by_sku($sku);
    unless ($item) {
        print STDERR "Item on line $. has sku $sku but is not in the inventory DB\n";
        next;
    }

    my $barcode = $item->{'barcode'};
    unless ($barcode) {
        print STDERR "Item on line $. has sku $sku, but no barcode in the inventory DB\n";
        next;
    }

    $fields[10] = $barcode;

    push(@fields,'new');
    $froogle->print(join("\t", @fields),"\n");

    if ($item->{'count'} > 0) {
        $amazon->print(join("\t", $barcode,
                                  '3',    # 3 = upc
                                  '11',   # 11 = new
                                  $fields[3], # price
                                  $sku,
                                  $item->{'count'},
                                  'a',    # a = add
                                  'n',    # will ship intl
                                  'y',    # expidited shipping
                                  '',     # item note
                                 ), "\n");
    }
 
}

$db->disconnect;
