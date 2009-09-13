#!/usr/bin/perl

use Test::More;

use File::Temp;

use Inventory;

plan tests => 20;

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

my $order = $db->create_order('ordername','receive');
ok($order, 'Created an order');

ok($order->receive_item_by_barcode('1234'), 'Added to received');
ok($order->receive_item_by_barcode('1234'), 'Added to received');
ok($order->receive_item_by_barcode('2345'), 'Added to received');

ok($order->save(), 'Order saved');


$order_detail = $db->get_order_detail('ordername');
ok($order_detail, 'Got details for order');
is($order_detail->{'1234'}, 2, 'Count is correct for first item');
is($order_detail->{'2345'}, 1, 'Count is correct for second item');

$order = eval {$db->create_order('ordername','receive') };
ok (! $order, 'Correctly could not create order with duplicate order number');
like($@, qr(column item_transaction_id is not unique), 'Exception says sales_order_id is not unique');


$order = $db->create_order('badorder','receive');
ok($order, 'Created an order');

ok($order->receive_item_by_barcode('abcd'), 'Added to received');
ok(! eval { $order->save }, 'Bad order correctly would not save');
is($@, "No item with barcode abcd\n", 'Exception says no item with that barcode');


$order = $db->create_order('badorder2','receive');
ok($order, 'Created an order');
ok(! eval { $order->sell_item_by_barcode('1234') }, 'Correctly cannot sell items in a receive order');
is($@, "Tried to sell barcode 1234 and order type was receive\n", 'Exception was correct');



