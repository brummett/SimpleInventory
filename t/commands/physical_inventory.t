#!/usr/bin/perl

BEGIN {
    $ENV{'INVENTORY_TEST'} = 1;
}

use strict;
use warnings;

use Test::More;
use above 'Inventory';

plan tests => 22;

my $cmd = Inventory::Command::PhysicalInventory->create(year => 1900);
ok($cmd, 'Instantiated command object');
$cmd->dump_warning_messages(0);
$cmd->dump_error_messages(0);
$cmd->dump_status_messages(0);
$cmd->queue_warning_messages(1);
$cmd->queue_error_messages(1);
$cmd->queue_status_messages(1);
# Insert 3 item 1s and 2 item 2s
my $data = qq(1 
one
first
1
1
2
two
second
2
+++
Y
);
close(STDIN);
open(STDIN,'<',\$data);
ok($cmd->execute(), 'executed ok');

ok(UR::Context->commit(), 'Commit DB');

my @errors = $cmd->error_messages();
is(scalar(@errors), 0, 'Command produced no error messages');
my @warnings = $cmd->warning_messages();
is(scalar(@warnings), 2, 'Got 2 warning messages');
is($warnings[0],
   'first barcode 1 previous count 0 scanned count 3 correction 3',
   'Saw message about inventory correction for item 1');
is($warnings[1],
   'second barcode 2 previous count 0 scanned count 2 correction 2',
   'Saw message about inventory correction for item 2');


my $dbh = Inventory::DataSource::Inventory->get_default_handle();
my $sth;

$sth = $dbh->prepare('select * from item order by barcode');
$sth->execute();
my(%barcode_to_item_id,%items_by_item_id,%items_by_barcode);

# Check the items table
while(my $data = $sth->fetchrow_hashref) {
    my %this_row = %$data;
    $items_by_barcode{$data->{'barcode'}} = \%this_row;
    $items_by_item_id{$data->{'item_id'}} = \%this_row;
    $barcode_to_item_id{$data->{'barcode'}} = $data->{'item_id'};
}

is(scalar(keys %items_by_item_id), 2, 'items table has 2 items');
foreach my $expected ( [1, { barcode => 1, sku => 'one', desc => 'first' } ],
                       [2, { barcode => 2, sku => 'two', desc => 'second' } ] ) {
    foreach my $key ( keys %{$expected->[1]} ) {
        my $barcode = $expected->[0];
        is($items_by_barcode{$barcode}->{$key}, 
           $expected->[1]->{$key},
           sprintf("Item with barcode %s key %s is correct", $barcode, $key));
    }
}

# check the orders table
my $order_data = $dbh->selectrow_hashref("select * from orders where order_number = '1900 inventory'");
ok($order_data, 'Got an order record for the inventory');
is($order_data->{'order_class'}, 'Inventory::Order::InventoryCorrection', 'It is of the correct type');
ok($order_data->{'date'}, 'it has a date');
my $order_id = $order_data->{'order_id'};

# The order_item_detail table
$sth = $dbh->prepare('select * from order_item_detail where order_id = ?');
ok($sth->execute($order_id), 'getting order_item_detail data');
my %count_for_barcode = ('1' => 0, '2' => 0);
my $rows_read = 0;
while(my $item_data = $sth->fetchrow_hashref()) {
    $rows_read++;
    my $barcode = $items_by_item_id{$item_data->{'item_id'}}->{'barcode'};
    $count_for_barcode{$barcode}+= $item_data->{'count'};
}
is($rows_read, 2, 'Read 5 rows from the order_item_detail table');
is(scalar(keys %count_for_barcode), 2, 'order_item_detail shows 2 distinct barcodes');
is($count_for_barcode{'1'}, 3, 'There were 3 item "1"s');
is($count_for_barcode{'2'}, 2, 'There were 2 item "2"s');


