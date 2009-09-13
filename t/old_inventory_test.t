#!/usr/bin/perl

use strict;
use warnings;

use Test::More tests => 20;
use File::Temp;

BEGIN { use_ok('Inventory'); }

my (undef,$db_file) = File::Temp::tempfile();
#my $db_file = '/tmp/inventory.sqlite3';

my $db = Inventory->connect($db_file);

ok($db, 'Created test DB');

my $item;
$item = $db->lookup_by_barcode('abcdef');
is($item, undef, 'Looking up by barcode with empty DB returns nothing');

$item = $db->lookup_by_sku('123456');
is($item, undef, 'Looking up by sku with empty DB returns nothing');

ok($db->create_item(barcode => 'abcdef', sku => '123456', desc => 'Test thing 1'), "Created first item");

$item = $db->lookup_by_barcode('abcdef');
ok($item, "Retrieved item by barcode");
is_deeply($item, { barcode => 'abcdef', sku => '123456', desc => 'Test thing 1', count => 0}, "Retrieved item is ok");

$item = $db->lookup_by_sku('123456');
ok($item, "Retrieved item by sku");
is_deeply($item, { barcode => 'abcdef', sku => '123456', desc => 'Test thing 1', count => 0}, "Retrieved item is ok");

ok($db->adjust_count_by_barcode('abcdef', 2), "adjusted item by barcode +2");
$item = $db->lookup_by_barcode('abcdef');
is_deeply($item, { barcode => 'abcdef', sku => '123456', desc => 'Test thing 1', count => 2}, "Retrieved item is ok");

# Doing this causes a Bus Error at the next create_item()'s execute()
#eval { $db->create_item(barcode=> 'abcdef', sku => '111111', desc => 'conflicting barcode'); };
#ok($@ =~ m/column barcode is not unique/, "Correctly can't create item with duplicate barcode");

ok($db->create_item(barcode => 'ghijkl', sku => '123456', desc => 'Test thing 2', count => 1), "Created second item");
ok($db->create_item(barcode => 'mnopqr', sku => '222222', desc => 'Test thing 3', count => 1), "Created third item");

$item = $db->lookup_by_barcode('aaaaaa');
ok(! $item, "Lookup with an unknown barcode correctly returns nothing");

$item = $db->lookup_by_barcode('abcdef');
is_deeply($item, { barcode => 'abcdef', sku => '123456', desc => 'Test thing 1', count => 2}, "Retrieved item is ok");

eval {$item = $db->lookup_by_sku('123456');};
ok($@ =~ m/scalar context/, "looking up multiple matching sku in scalar context correctly dies");

my @items = sort $db->lookup_by_sku('123456');
ok(@items == 2, "looking up multiple matching sku in list context returns 2 items");

is_deeply(\@items,
          [ { barcode => 'abcdef', sku => '123456', desc => 'Test thing 1', count => 2},
            { barcode => 'ghijkl', sku => '123456', desc => 'Test thing 2', count => 1}],
          "Both items are right");

ok($db->adjust_count_by_barcode('abcdef', -1), "adjusted item by barcode -1");
$item = $db->lookup_by_barcode('abcdef');
is_deeply($item, { barcode => 'abcdef', sku => '123456', desc => 'Test thing 1', count => 1}, "Retrieved item is ok");

$db->dbh->rollback;
$db->dbh->disconnect;

