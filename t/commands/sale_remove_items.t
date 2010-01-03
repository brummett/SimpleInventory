#!/usr/bin/perl

BEGIN {
    $ENV{'INVENTORY_TEST'} = 1;
}

use strict;
use warnings;

use Test::More;
use above 'Inventory';

plan tests => 30;

my $dbh = &setup_db();

my $cmd = Inventory::Command::Sale->create(order_number => 1234);
ok($cmd, 'Instantiated command object');
$cmd->dump_warning_messages(0);
$cmd->dump_error_messages(0);
$cmd->queue_warning_messages(1);
$cmd->queue_error_messages(1);
# Sell 2 item 1s and 1 item 2
my $data = qq(1 
1
1
2
);
close(STDIN);
open(STDIN,'<',\$data);
ok($cmd->execute(), 'executed ok');

ok(UR::Context->commit(), 'Commit DB');

# Try removing an item 3 - will die because there's no item 3s
$cmd = Inventory::Command::Sale->create(order_number => 1234, remove => 1);
ok($cmd, 'Created command to remove non-existent item from that sale');
$data = qq(3
);
$cmd->dump_warning_messages(0);
$cmd->dump_error_messages(0);
$cmd->queue_warning_messages(1);
$cmd->queue_error_messages(1);
close(STDIN);
open(STDIN,'<',\$data);
my $retval = eval { $cmd->execute() };
ok(! $retval, 'execute correctly returned false');
my @errors = $cmd->error_messages();
is(scalar(@errors),1, 'Got 1 error message');
like($errors[0], qr(Order 1234 has no item with barcode 3), 'Error reported no item 3');
like($@, qr/Exiting without saving/, 'Exception reported correctly');

ok(UR::Context->rollback, 'Rollback DB after failure');

# Try removing 2 item 2s - will die because there's only 1 item 2
$cmd = Inventory::Command::Sale->create(order_number => 1234, remove => 1);
ok($cmd, 'Created command to remove items too many items from that sale');
$data = qq(2
2
);
$cmd->dump_warning_messages(0);
$cmd->dump_error_messages(0);
$cmd->queue_warning_messages(1);
$cmd->queue_error_messages(1);
close(STDIN);
open(STDIN,'<',\$data);
$retval = eval { $cmd->execute() };
ok(! $retval, 'execute correctly returned false');
@errors = $cmd->error_messages();
is(scalar(@errors), 1, 'got 1 error message');
like($errors[0], qr(Tried to remove too many two from order 1234), 'Error reported too many item 2 removed');
like($@, qr/Exiting without saving/, 'Exception reported correctly');

ok(UR::Context->rollback, 'Rollback DB after failure');

# Now, remove an item 1 and an item 2
$cmd = Inventory::Command::Sale->create(order_number => 1234, remove => 1);
ok($cmd, 'Created command to properly remove items from that sale');
$data = qq(1
2
);
$cmd->dump_warning_messages(0);
$cmd->dump_error_messages(0);
$cmd->queue_warning_messages(1);
$cmd->queue_error_messages(1);
close(STDIN);
open(STDIN,'<',\$data);
ok($cmd->execute(), 'Removal executed successfully');

ok(UR::Context->commit(), 'Commit DB');

my $the_order = Inventory::Order->get(order_number => 1234);
ok($the_order, 'Got order object for order number 1234');

# check the orders table
my $sth = $dbh->prepare('select * from orders');
$sth->execute();
my $count = 0;
my $order_id;
my %expected = ( -1 => {order_number => 'foo', type => 'Inventory::Order::InventoryCorrection' },
                $the_order->id => { order_number => '1234', type => 'Inventory::Order::Sale' },
               );
while (my $row = $sth->fetchrow_hashref()) {
    $count++;
    is($row->{'order_number'},
       $expected{$row->{'order_id'}}->{'order_number'},
       'Order number is correct for that id');
    is($row->{'order_class'},
       $expected{$row->{'order_id'}}->{'type'},
       'order_class is correct');
}
is($count, 2, 'Saw 2 order records');
    

# The order_item_detail table
$sth = $dbh->prepare('select * from order_item_detail where order_id = ?');
ok($sth->execute($the_order->id), 'getting order_item_detail data');
my %count_for_item = ('1' => 0);
my $rows_read = 0;
while(my $item_data = $sth->fetchrow_hashref()) {
    $rows_read++;
    $count_for_item{$item_data->{'item_id'}} += $item_data->{'count'};
}
# From above: The total will now be 2 item 1s
is($rows_read, 2, 'Read 2 rows from the order_item_detail table');
is(scalar(keys %count_for_item), 1, 'order_item_detail shows 1 distinct barcode');
is($count_for_item{'1'}, -2, 'There were 2 item "1"s');

my @warnings = $cmd->warning_messages();
is(scalar(@warnings), 0, 'No warning messages');
my @errors = $cmd->error_messages();
is(scalar(@errors), 0, 'Saw no error messages');


sub setup_db {
    my $dbh = Inventory::DataSource::Inventory->get_default_handle();

    my $sth = $dbh->prepare('insert into item (item_id, barcode, sku, desc) values (?,?,?,?)');
    foreach my $row ( [1,1,1,'one'],
                      [2,2,2,'two'],
                      [3,3,3,'three'],
                    ) {
        $sth->execute(@$row);
    }
    $sth->finish;

    $sth = $dbh->do("insert into orders (order_id, order_number, order_class) values (-1, 'foo', 'Inventory::Order::InventoryCorrection')");

    $sth = $dbh->prepare('insert into order_item_detail (order_item_detail_id,order_id,item_id,count) values (?,?,?,?)');
    foreach my $row ( [-1,-1,1,5],
                      [-2,-1,2,5],
                      [-3,-1,3,5],
                    ) {
        $sth->execute(@$row);
    }
    return $dbh;
}

