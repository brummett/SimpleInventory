#!/usr/bin/perl

BEGIN {
    $ENV{'INVENTORY_TEST'} = 1;
}

use strict;
use warnings;

use Test::More;
use above 'Inventory';

plan tests => 16;

my $dbh = &setup_db();

my $cmd = Inventory::Command::Sale->create(order_number => 1234);
ok($cmd, 'Instantiated command object');
$cmd->dump_warning_messages(0);
$cmd->dump_error_messages(0);
$cmd->queue_warning_messages(1);
$cmd->queue_error_messages(1);
# Insert 3 item 1s and 2 item 2s
my $data = qq(1 
1
2
2
2
);
close(STDIN);
open(STDIN,'<',\$data);
ok($cmd->execute(), 'executed ok');

ok(UR::Context->commit(), 'Commit DB');



# check the orders table
my $order_data = $dbh->selectrow_hashref("select * from orders where order_number = '1234'");
ok($order_data, 'Got an order record for the inventory');
is($order_data->{'order_class'}, 'Inventory::Order::Sale', 'It is of the correct type');
ok($order_data->{'date'}, 'it has a date');
my $order_id = $order_data->{'order_id'};

# The order_item_detail table
my $sth = $dbh->prepare('select * from order_item_detail where order_id = ?');
ok($sth->execute($order_id), 'getting order_item_detail data');
my %count_for_item = ('1' => 0, '2' => 0);
my $rows_read = 0;
while(my $item_data = $sth->fetchrow_hashref()) {
    $rows_read++;
    $count_for_item{$item_data->{'item_id'}}++;
}
is($rows_read, 5, 'Read 5 rows from the order_item_detail table');
is(scalar(keys %count_for_item), 2, 'order_item_detail shows 2 distinct barcodes');
is($count_for_item{'1'}, 2, 'There were 2 item "1"s');
is($count_for_item{'2'}, 3, 'There were 3 item "2"s');

my @warnings = $cmd->warning_messages();
is(scalar(@warnings), 1, 'Got one warning message from the command');
like($warnings[0], qr/Item count below 0 \(-1\):\s+two/, 'Saw warning about item two below zero');
like($warnings[0], qr/Inventorycorrection order foo on .*:\s+2/, 'Saw history for inventory');
like($warnings[0], qr/Sale order 1234 on .*:\s+-3/, 'Saw history for sale');

my @errors = $cmd->error_messages();
is(scalar(@errors), 0, 'Saw no error messages');


sub setup_db {
    my $dbh = Inventory::DataSource::Inventory->get_default_handle();

    my $sth = $dbh->prepare('insert into item (item_id, barcode, sku, desc) values (?,?,?,?)');
    foreach my $row ( [1,1,1,'one'],
                      [2,2,2,'two'],
                    ) {
        $sth->execute(@$row);
    }
    $sth->finish;

    $sth = $dbh->do("insert into orders (order_id, order_number, order_class) values (-1, 'foo', 'Inventory::Order::InventoryCorrection')");

    $sth = $dbh->prepare('insert into order_item_detail (order_item_detail_id,order_id,item_id,count) values (?,?,?,?)');
    foreach my $row ( [-1,-1,1,3],
                      [-2,-1,2,2],
                    ) {
        $sth->execute(@$row);
    }
    return $dbh;
}

