#!/usr/bin/perl

use Test::More;

use File::Temp;

use Inventory;

plan tests => 30;

my ($db_fh,$db_file) = File::Temp::tempfile();
$db_fh->close();
#my $db_file = '/tmp/inventory.sqlite3';

my $db = Inventory->connect($db_file);
ok($db, 'Connected to database');

my $dbh = $db->dbh;

ok($dbh->do("insert into inventory (barcode, sku, desc, count) values ('1234','5678','A Thing',3)"),
   'Inserted an item');

ok($dbh->do("insert into inventory (barcode, sku, desc, count) values ('2345','abcd','Another Thing',0)"),
   'Inserted another item');

my $item = $db->lookup_by_barcode('1234');
ok($item, "Got an item by barcode");
is($item->{'barcode'}, '1234', 'It had the right barcode');
is($item->{'sku'}, '5678', 'It had the right sku');
is($item->{'desc'}, 'A Thing', 'It had the right desc');
is($item->{'count'}, 3, 'It had the right count');

$item = $db->lookup_by_sku('abcd');
ok($item, 'Got an item by sku');
is($item->{'barcode'}, '2345', 'It had the right barcode');
is($item->{'sku'}, 'abcd', 'It had the right sku');
is($item->{'desc'}, 'Another Thing', 'It had the right desc');
is($item->{'count'}, 0, 'It had the right count');

$item = $db->create_item(barcode => '1928', sku => '1122', desc => 'New item', count => 1);
ok($item, 'Created a new item');

ok($db->adjust_count_by_barcode('2345', 2), 'Adjusted item count by +2');
$item = $db->lookup_by_barcode('2345');
is($item->{'count'}, 2, 'Count is correct');


ok($db->adjust_count_by_barcode('2345', -1), 'Adjusted item count by -1');
$item = $db->lookup_by_barcode('2345');
is($item->{'count'}, 1, 'Count is correct');

ok($db->set_count_by_barcode('2345',0), 'Set item count to 0');
$item = $db->lookup_by_barcode('2345');
is($item->{'count'}, 0, 'Count is correct');

my $all_items = $db->get_all_inventory();
is(scalar(@$all_items), 3, 'Got all 3 items from inventory');

my %expected_barcodes = map { $_ => 1 } qw( 1234 2345 1928 );
foreach my $item ( @$all_items ) {
    ok(delete $expected_barcodes{$item->{'barcode'}}, 'Found an expecte barcode');
}
is(scalar(keys %expected_barcodes), 0, 'All expected barcodes seen');

$item = $db->lookup_by_barcode('not there');
ok(! $item, "lookup by non-existent barcode correctly returned nothing");

ok (! eval { $db->adjust_count_by_barcode('not there', 123) }, "Adjusting count of a non-existent barcode correctly doesn't work");
is($@, "No item with barcode not there\n", 'And generated the currect exception');

ok (! eval { $db->set_count_by_barcode('still not there', 123) }, "Setting count of a non-existent barcode correctly doesn't work");
is($@, "No item with barcode still not there\n", 'And generated the currect exception');


