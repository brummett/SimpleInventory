#!/usr/bin/perl

use Test::More;

use File::Temp;

use Inventory;

plan tests => 22;

my (undef,$db_file) = File::Temp::tempfile();
#my $db_file = '/tmp/inventory.sqlite3';

my $db = Inventory->connect($db_file);
ok($db, 'Connected to database');

my $dbh = $db->dbh;
$dbh->{'PrintError'} = 0;

ok($dbh->do("insert into inventory (barcode, sku, desc, count) values ('1234','5678','A Thing',3)"),
   'Inserted an item');

ok($dbh->do("insert into inventory (barcode, sku, desc, count) values ('2345','abcd','Another Thing',3)"),
   'Inserted another item');

my $order = $db->create_order('ordername');
ok($order, 'Created an order');

ok($order->add_item_by_barcode('1234'), 'Added to order');
ok($order->add_item_by_barcode('1234'), 'Added to order');
ok($order->add_item_by_barcode('2345'), 'Added to order');

#ok($order->verify_items(), 'Order verified');
ok($order->save(), 'Order saved');

$order_detail = $db->get_order_detail('ordername');
ok($order_detail, 'Got details for order');
is($order_detail->{'1234'}, -2, 'Count is correct for first item');
is($order_detail->{'2345'}, -1, 'Count is correct for second item');

$order = eval {$db->create_order('ordername') };
ok (! $order, 'Correctly could not create order with duplicate order number');
like($@, qr(column item_transaction_id is not unique), 'Exception says sales_order_id is not unique');


$order = $db->create_order('badorder');
ok($order, 'Created an order');

ok($order->add_item_by_barcode('1234'), 'Added to order');
ok($order->add_item_by_barcode('1234'), 'Added to order');

#ok(! $order->verify_items(), 'Order correctly did not verify items');

ok(! eval { $order->save }, 'Bad order correctly would not save');
is($@, "Count below 0 for barcode 1234\n", 'Exception says count below 0');


$order = $db->create_order('badorder2');
ok($order, 'Created an order');

ok($order->add_item_by_barcode('abcd'), 'Added to order');
ok(! eval { $order->save }, 'Bad order correctly would not save');
is($@, "No item with barcode abcd\n", 'Exception says no item with that barcode');



