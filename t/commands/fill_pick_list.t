#!/usr/bin/perl

use Test::More tests => 25;

BEGIN {
    $ENV{'INVENTORY_TEST'} = 1;
}

# Test filling a picklist to change it into a Sale order
use strict;
use warnings;

use File::Temp;
use above 'Inventory';

my $dbh = &setup_db();

my $data_fh = \*DATA;
my $cmd = Inventory::Command::Amazon::ImportOrders->create(file => $data_fh, 'print' => 0);
ok($cmd, 'Create amazon import order command object to create some orders to fill');
$cmd->dump_warning_messages(0);
$cmd->dump_error_messages(0);
$cmd->queue_warning_messages(1);
$cmd->queue_error_messages(1);
ok($cmd->execute(), 'executed ok');

ok(UR::Context->commit(), 'Commit DB');

my @errors = $cmd->error_messages();
is(scalar(@errors), 0, 'There were no errors');
my @warnings = $cmd->warning_messages();
is(scalar(@errors), 0, 'There were no warnings');


# We now have a few picklist orders to fill


# First try inputting an order number that doesn't exist
$cmd = Inventory::Command::FillPickList->create();
ok($cmd, 'created fill picklist command object');
$cmd->dump_warning_messages(0);
$cmd->dump_error_messages(0);
$cmd->queue_warning_messages(1);
$cmd->queue_error_messages(1);
my $data = qq(not_an_order_number
);
close(STDIN);
open(STDIN, '<', \$data);
my $ret = eval { $cmd->execute };
ok(! $ret, 'Inputting a non-existent order number failed execute');
is($@, "Filling order failed.  Exiting without saving\n", 'exception was correct');
my $order =  Inventory::Order->get(order_number => 'not_an_order_number');
ok(!$order, 'Correctly did not create an order object');
@warnings = $cmd->warning_messages;
is(scalar(@warnings), 0, 'generated no warning messages');
@errors = $cmd->error_messages;
is(scalar(@errors), 2, '2 error messages');
my @expected_errors = ("Couldn't find a pick list order with order number NOT_AN_ORDER_NUMBER",
                       "Could not create order record for this transaction.  Exiting...");
is_deeply(\@errors, \@expected_errors, 'Error messages are as expected');

# prompts are:
# Order Number:
# Scan:
# Scan:
# ...

$cmd = Inventory::Command::FillPickList->create();
ok($cmd, 'Create FillPickList command for order 123-4567890-1234567');
$cmd->dump_warning_messages(0);
$cmd->dump_error_messages(0);
$cmd->queue_warning_messages(1);
$cmd->queue_error_messages(1);

# The order with a single item 1
$data = qq(123-4567890-1234567
1
);
close(STDIN);
open(STDIN, '<', \$data);

$ret = eval { $cmd->execute };
ok($ret, 'execute for order 123-4567890-1234567');
is($@, '', 'No exceptions');
$order = Inventory::Order->get(order_number => '123-4567890-1234567');
ok($order, 'After filling order, retrieved the order object');
isa_ok($order, 'Inventory::Order::Sale');
@warnings = $cmd->warning_messages();
is(scalar(@warnings), 0, 'No warning messages');
@errors = $cmd->error_messages();
is(scalar(@errors), 0, 'No error messages');


# Try filling that same order again
$cmd = Inventory::Command::FillPickList->create();
ok($cmd, 'Create another FillPickList command for order 123-4567890-1234567');
$cmd->dump_warning_messages(0);
$cmd->dump_error_messages(0);
$cmd->queue_warning_messages(1);
$cmd->queue_error_messages(1);

$data = qq(123-4567890-1234567
);
close(STDIN);
open(STDIN, '<', \$data);

$ret = eval { $cmd->execute() };
ok(! $ret, 'Trying to fill the same order again did not execute');
is($@, "Filling order failed.  Exiting without saving\n", 'exception was correct');
@warnings = $cmd->warning_messages;
is(scalar(@warnings), 0, 'No warning messages');
@errors = $cmd->error_messages();
is(scalar(@errors), 2, '2 error messages');
@expected_errors = ("Couldn't find a pick list order with order number 123-4567890-1234567",
                    "Could not create order record for this transaction.  Exiting...");
is_deeply(\@errors, \@expected_errors, 'Error messages were correct');



1;
sub setup_db {
    my $dbh = Inventory::DataSource::Inventory->get_default_handle();

    my $sth = $dbh->prepare('insert into item (item_id, barcode, sku, desc) values (?,?,?,?)');
    foreach my $row ( [1,1,1,'item one'],
                      [2,2,2,'item two'],
                      [3,3,3,'item three'],
                    ) {
        $sth->execute(@$row);
    }
    $sth->finish;

    $sth = $dbh->do("insert into orders (order_id, order_number, order_class) values (-1, 'foo', 'Inventory::Order::InventoryCorrection')");

    $sth = $dbh->prepare('insert into order_item_detail (order_item_detail_id,order_id,item_id,count) values (?,?,?,?)');
    foreach my $row ( [-1,-1,1,3],
                      [-2,-1,2,5],
                    ) {
        $sth->execute(@$row);
    }
    return $dbh;
}


# The amazon order file
# The order the items get filled:
# 111-2222222-3333333 (expedited) 2 item 2
# 123-4567890-1234567 1 item 1
# 234-5678901-2345678 1 item 1, 2 item 2s
# 222-3333333-4444444 2 item 1s, 2 items 2s - Unfulfilled: short an item 2
__DATA__
order-id	order-item-id	purchase-date	payments-date	buyer-email	buyer-name	buyer-phone-number	sku	product-name	quantity-purchased	currency	item-price	item-tax	shipping-price	shipping-tax	ship-service-level	recipient-name	ship-address-1	ship-address-2	ship-address-3	ship-city	ship-state	ship-postal-code	ship-country	ship-phone-number	delivery-start-date	delivery-end-date	delivery-time-zone	delivery-Instructions
123-4567890-1234567	11111111111111	2009-01-01T10:50:49-08:00	2009-01-05T10:50:49-08:00	example@example.net	Bob Smith	555-123-4567	1	item one	1	USD	1.29	0.00	1.99	0.00	Standard	Bob Smith	123 Main St			Nowhere	FL	55443-3221	US	555-123-4567				
234-5678901-2345678	22222222222222	2009-01-01T10:50:49-08:00	2009-01-05T10:50:49-08:00	example2@example.net	Bob Jones	555-123-4567	1	item one	1	USD	1.29	0.00	1.99	0.00	Standard	Bob Jones	456 Elm St			Somewhere	AK	11111-2222	US	555-123-4567				
234-5678901-2345678	33333333333333	2009-01-01T10:50:49-08:00	2009-01-05T10:50:49-08:00	example2@example.net	Bob Jones	555-123-4567	2	item two	2	USD	1.29	0.00	1.99	0.00	Standard	Bob Jones	456 Elm St			Somewhere	AK	11111-2222	US	555-123-4567				
111-2222222-3333333	44444444444444	2009-01-01T10:50:49-08:00	2009-01-05T10:50:49-08:00	example3@example.net	Chuck Jones	555-123-4567	2	item two	2	USD	1.29	0.00	1.99	0.00	Expedited	Chuck Jones	999 Oak St			Somewhere	NY	22222-3333	US	555-123-4567				
222-3333333-4444444	55555555555555	2009-01-01T10:50:49-08:00	2009-01-05T10:50:49-08:00	example4@example.net	John Johnson	555-123-4567	2	item two	2	USD	1.29	0.00	1.99	0.00	Standard	John Johnson	111 Main St			Somewhere	NY	22222-3333	US	555-123-4567				
222-3333333-4444444	66666666666666	2009-01-01T10:50:49-08:00	2009-01-05T10:50:49-08:00	example4@example.net	John Johnson	555-123-4567	1	item one	2	USD	1.29	0.00	1.99	0.00	Standard	John Johnson	111 Main St			Somewhere	NY	22222-3333	US	555-123-4567				

