#!/usr/bin/perl

use strict;
use warnings;

use Test::More tests => 9;

use File::Temp;

use Inventory;

my (undef,$db_file) = File::Temp::tempfile();
#my $db_file = '/tmp/inventory.sqlite3';

my $db = Inventory->connect($db_file);
ok($db, 'Connected to database');

my $dbh = $db->dbh;
$dbh->{'PrintError'} = 0;

ok($dbh->do("insert into inventory (barcode, sku, desc, count) values ('1234','5678','A Thing',1)"),
   'Inserted an item');

ok($dbh->do("insert into inventory (barcode, sku, desc, count) values ('2345','abcd','Another Thing',1)"),
   'Inserted another item');

ok($dbh->do("insert into inventory (barcode, sku, desc, count) values ('6789','zywx','Third Thing',0)"),
   'Inserted another item');

$dbh->commit();  # saved to the DB

my $order = $db->create_order('ordername','sale');
ok($order, 'Created an order');

ok($order->sell_item_by_barcode('1234'), 'Added to order');
ok($order->sell_item_by_barcode('2345'), 'Added to order');
ok($order->sell_item_by_barcode('6789'), 'Added to order');  # will go below 0

until ( eval { $order->save() } ) {
    if ($@) { 
        if ($@ =~ m/Count below 0 for barcode 6789/) {
            ok(1, 'Detected count below 0 for barcode 6789');
            $order->remove_barcode(6789);
        } else {
            ok(0, "Detected unknown error: $@");
            my ($bad_barcode) = ($@ =~ m/barcode (\S+)/);
            $order->remove_barcode($bad_barcode);
        }
        $dbh->rollback();
    }
}


