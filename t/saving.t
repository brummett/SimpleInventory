#!/usr/bin/perl

use strict;
use warnings;

use Test::More tests => 19;

use File::Temp;

use Inventory;

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

my $order = $db->create_order('test data import', 'initial_import');
ok($order, 'Create order for import');

ok($order->receive_items_by_barcode('1234',3), 'Imported items');
ok($order->receive_items_by_barcode('2345', 3), 'Imported items');

ok($order->save, 'Import order saved');


$order = $db->create_order('ordername','sale');
ok($order, 'Created an order');

ok($order->sell_item_by_barcode('1234'), 'Added to order');
ok($order->sell_item_by_barcode('1234'), 'Added to order');
ok($order->sell_item_by_barcode('2345'), 'Added to order');

ok($order->save(), 'Order saved');

ok($db->commit(), 'Committed DB');
ok($db->disconnect(),' Disconnected');

$db = Inventory->connect($db_file);
ok($db, 'reconnected to database');

my $item = $db->lookup_by_barcode('1234');
is($item->{'count'}, 1, 'Item count is correct');

$item = $db->lookup_by_barcode('2345');
is($item->{'count'}, 2, 'Item count is correct');


my $sth = $db->dbh->prepare('select sum(count) from item_transaction_detail where barcode = ?');

$sth->execute('1234');
my @row = $sth->fetchrow_array();
is($row[0], 1, 'detail for item is correct');
$sth->finish;

$sth->execute('2345');
@row = $sth->fetchrow_array();
is($row[0], 2, 'detail for item is correct');

