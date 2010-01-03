#!/usr/bin/perl

BEGIN {
    $ENV{'INVENTORY_TEST'} = 1;
}

use strict;
use warnings;

use Test::More;
use above 'Inventory';

plan tests => 11;

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


$cmd = Inventory::Command::Sale->create(order_number => 1234);
ok($cmd, 'Instantiated command object');
$cmd->dump_warning_messages(0);
$cmd->dump_error_messages(0);
$cmd->queue_warning_messages(1);
$cmd->queue_error_messages(1);
# Insert 3 item 1s and 2 item 2s
$data = qq(1
);
close(STDIN);
open(STDIN,'<',\$data);
ok(! $cmd->execute(), "Correctly couldn't create a transaction with duplicate order number");

my @errors = $cmd->error_messages();
is(scalar(@errors), 2, 'Saw two error messages');
is($errors[0], 'A(n) Inventory::Order::Sale already exists with that order number', 'The message was correct');
is($errors[1], 'Could not create order record for this transaction.  Exiting...', 'message 2 is correct');

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

