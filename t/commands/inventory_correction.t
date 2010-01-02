#!/usr/bin/perl

BEGIN {
    $ENV{'INVENTORY_TEST'} = 1;
}

use strict;
use warnings;

use Test::More;
use above 'Inventory';

plan tests => 26;

# Store that we have 3 item '1's and 2 item '2's and 2 item '3's
my $dbh = &setup_db();

# Say we now have 3 item 1s (correct), 1 item 2 
# 3 item 3s and 1 item 4
my $data = qq(1 
1
2
1
4
four
fourth
3
3
3
+++
N
);

# For this first time, reject the changes
my $cmd = Inventory::Command::PhysicalInventory->create(year => 1900);
ok($cmd, 'Instantiated command object');
$cmd->dump_warning_messages(0);
$cmd->dump_error_messages(0);
$cmd->queue_warning_messages(1);
$cmd->queue_error_messages(1);
close(STDIN);
open(STDIN,'<',\$data);
ok(! $cmd->execute(), 'execute correctly returned false');

ok(UR::Context->commit(), 'Commit DB');

# Check the orders table.  There should be no record of that inventory
my $order_data = $dbh->selectrow_hashref("select * from orders where order_number = '1900 inventory'");
ok(! $order_data, 'Correctly saw no order for new inventory');

$order_data = $dbh->selectrow_hashref("select * from orders where order_number = 'foo'");
ok($order_data, 'Original inventory order is still in there');


# Now, change the N at the end to a Y to accept the inventory
$cmd = Inventory::Command::PhysicalInventory->create(year => 1900);
ok($cmd, 'Instantiated command object');
$cmd->dump_warning_messages(0);
$cmd->dump_error_messages(0);
$cmd->queue_warning_messages(1);
$cmd->queue_error_messages(1);
# Note that we're not putting in the description for barcode 4, since it should
# still be in the system
my $data = qq(1 
1
2
1
4
3
3
3
+++
Y
);
close(STDIN);
open(STDIN,'<',\$data);


ok($cmd->execute(), 'execute returned true');

ok(UR::Context->commit(), 'Commit DB');

# check the orders table
$order_data = $dbh->selectrow_hashref("select * from orders where order_number = 'foo'");
ok($order_data, 'Original inventory order record is still there');
$order_data = $dbh->selectall_hashref("select * from order_item_detail where order_id = ".$order_data->{'order_id'}, 'item_id');
is(scalar(keys %$order_data), 3, '3 detail records from the original order still in there');
# keys are barcodes
my %expected = ( 1 => 3, 2 => 2, 3 => 2 );
foreach my $item_id ( keys %$order_data ) {
   my $barcode = Inventory::Item->get(item_id => $item_id)->barcode;
   is($order_data->{$item_id}->{'count'},  $expected{$barcode}, 'Original detail has correct count');
}
    

$order_data = $dbh->selectrow_hashref("select * from orders where order_number = '1900 inventory'");
ok($order_data, 'Got an order record for the inventory');
is($order_data->{'order_class'}, 'Inventory::Order::InventoryCorrection', 'It is of the correct type');
ok($order_data->{'date'}, 'it has a date');
my $order_id = $order_data->{'order_id'};

# The order_item_detail table
my $sth = $dbh->prepare('select * from order_item_detail where order_id = ?');
ok($sth->execute($order_id), 'getting order_item_detail data');
# keys are barcodes
my %expected_count = (2 => -1, 3 => 1, 4=> 1);
while(my $item_data = $sth->fetchrow_hashref()) {
    my $barcode = Inventory::Item->get(item_id => $item_data->{'item_id'})->barcode;
    is($item_data->{'count'}, $expected_count{$barcode}, 'correction is correct');
}

my @warnings = $cmd->warning_messages();
is(scalar(@warnings), 3, 'Got three warning messages from the command');
my $warnings = join("\n",@warnings);
like($warnings, qr/two barcode 2 previous count 2 scanned count 1 correction -1/,
     'Saw correction for item 2');
like($warnings, qr/three barcode 3 previous count 2 scanned count 3 correction 1/,
     'Saw correction for item 3');
like($warnings, qr/fourth barcode 4 previous count 0 scanned count 1 correction 1/,
    'Saw correction for item 4');
unlike($warnings, qr/one barcode/, 'Correctly saw no correction for item 1');

my @errors = $cmd->error_messages();
is(scalar(@errors), 0, 'Saw no error messages');


sub setup_db {
    my $dbh = Inventory::DataSource::Inventory->get_default_handle();

    my $sth = $dbh->prepare('insert into item (item_id, barcode, sku, desc) values (?,?,?,?)');
    foreach my $row ( [-1,1,1,'one'],
                      [-2,2,2,'two'],
                      [-3,3,3,'three'],
                    ) {
        $sth->execute(@$row);
    }
    $sth->finish;

    $sth = $dbh->do("insert into orders (order_id, order_number, order_class) values (-1, 'foo', 'Inventory::Order::InventoryCorrection')");

    $sth = $dbh->prepare('insert into order_item_detail (order_item_detail_id,order_id,item_id,count) values (?,?,?,?)');
    foreach my $row ( [-1,-1,-1,3],
                      [-2,-1,-2,2],
                      [-3,-1,-3,2],
                    ) {
        $sth->execute(@$row);
    }
    $dbh->commit();
    return $dbh;
}

