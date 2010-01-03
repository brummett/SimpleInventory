use Test::More;
use above 'Inventory';

plan tests => 19;

my $ds = Inventory::DataSource::Inventory->get();
ok($ds, 'Got inventory datasource');

my $dbh = $ds->get_default_handle();
ok($dbh, 'Got db handle');

&cleanup_db($dbh);

END { &cleanup_db($dbh) };

&setup_db($dbh);

my $order = Inventory::Order::Sale->create(order_number => '123');
ok($order, 'Created sale order');

my $item1 = Inventory::Item->get(barcode => '123456');
ok($item1, 'Got item with barcode 123456');
my $item2 = Inventory::Item->get(barcode => '234567');
ok($item1, 'Got item with barcode 234567');

ok($order->add_item($item1), 'Added item 123456 to the sale');
ok($order->add_item($item1), 'Added item 123456 to the sale again');
ok($order->add_item($item2), 'Added item 234567 to the sale');

is($order->item_detail_count, 3, 'There are three detail items in the order');
is($order->item_count, 2, 'There are three distinct items in the order');

is($item1->count, 1, 'Item 123456 now has 1 left in the inventory');
is($item2->count, 0, 'Item 234567 now has 0 left in the inventory');



sub setup_db {
    my $dbh = shift;

    # Put an order in 
    ok( $dbh->do("insert into item (item_id, barcode, sku, desc) values (-1, '123456', '123456', 'item 1')"),
        "insert an item");
    ok( $dbh->do("insert into item (item_id, barcode, sku, desc) values (-2, '234567', '234567', 'item 2')"),
        "insert another item");
    ok($dbh->do("insert into orders (order_id, order_number, order_class) values (-1, '123', 'Inventory::Order::Purchase')"),
        "insert a received transaction (order)");
    ok($dbh->do("insert into order_item_detail (order_item_detail_id, order_id, item_id, count) values (-1, -1, -1, 1)"),
        "Insert a received item");
    ok($dbh->do("insert into order_item_detail (order_item_detail_id, order_id, item_id, count) values (-2, -1, -1, 1)"),
        "Insert a received item 2");
    ok($dbh->do("insert into order_item_detail (order_item_detail_id, order_id, item_id, count) values (-3, -1, -1, 1)"),
        "Insert a received item 3");
    ok($dbh->do("insert into order_item_detail (order_item_detail_id, order_id, item_id, count) values (-4, -1, -2, 1)"),
        "Insert a received item 4");

}

sub cleanup_db {
    my $dbh = shift;

    $dbh->do("delete from order_item_detail where order_item_detail_id < 0");
    $dbh->do("delete from orders where order_id < 0");
    $dbh->do("delete from order_item_detail where order_item_detail_id < 0");

}
