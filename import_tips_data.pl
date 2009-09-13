#!/usr/bin/perl

use strict;
use warnings;

use Inventory;
my $db = Inventory->connect();
unless ($db) {
    die "Couldn't connect to DB";
}

while(<>) { 
    chomp;
    my($count,$barcode,$desc) = split(/\s+/, $_, 3);

    unless ($count && $barcode && $desc) {
        $db->rollback;
        die "Error on line $., got count $count barcode $barcode desc $desc";
    }

    my $item = $db->lookup_by_sku($barcode) || $db->lookup_by_barcode($barcode);
    if ($item) {
        if ($item->{'count'}) {
            print "line $. Item $desc barcode $barcode is already in the DB with count ",$item->{'count'},"\n";
            next;
        }
        $db->set_count_by_barcode($barcode,$count);
    } else {
        unless ($db->create_item(barcode => $barcode, sku => $barcode, desc => $desc, count => $count)) {
            $db->rollback;
            die "Problem creating item barcode $barcode on line $.";
        }
    }

}

$db->dbh->commit();
$db->dbh->disconnect;
