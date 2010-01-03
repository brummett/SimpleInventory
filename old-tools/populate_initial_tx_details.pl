#!/usr/bin/perl

use strict;
use warnings;

use Inventory;

my $db = Inventory->connect();

my $order = $db->create_order('Initial import after physical inventory', 'initial_import');

my $iter = $db->iterate_all_inventory();

my $count = 0;
while(my $item = $iter->()) {
    next unless ($item->{'count'});
    $order->receive_items_by_barcode($item->{'barcode'}, $item->{'count'});
    $count++;
}

$order->save;

print "Saving detail records for $count items\n";
$db->commit();

