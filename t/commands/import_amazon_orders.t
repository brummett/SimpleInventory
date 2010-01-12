#!/usr/bin/perl

BEGIN {
    $ENV{'INVENTORY_TEST'} = 1;
}

# Test generating a pick list from an amazon seller account orders file
use strict;
use warnings;

use Test::More;
use above 'Inventory';

plan tests => 49;

my $dbh = &setup_db();

my $data_fh = \*DATA;
my $cmd = Inventory::Command::Amazon::ImportOrders->create(file => $data_fh, 'print' => 0);
ok($cmd, 'Instantiated command object');
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

&check_first_order($dbh);
&check_second_order($dbh);
&check_third_order($dbh);
&check_fourth_order($dbh);

sub get_order_item_id_for_detail_id {
    my $detail_id = shift;

    my $attr_sth = $dbh->prepare_cached("select attr.value from order_item_detail d join order_item_detail_attribute attr on attr.order_item_detail_id = d.order_item_detail_id where d.order_item_detail_id = ? and name = 'order_item_id'");

    $attr_sth->execute($detail_id);
    my $row = $attr_sth->fetchrow_arrayref();
    my $id = $row->[0];
    $attr_sth->finish();
    return $id;
}


# 111-2222222-3333333 (expedited) 2 item 2
sub check_first_order {
    my $dbh = shift;

    my $order_data = $dbh->selectrow_hashref("select * from orders where order_number = '111-2222222-3333333'");
    ok($order_data, 'Got an order record for the first order');
    is($order_data->{'order_class'}, 'Inventory::Order::PickList', 'It is of the correct type');
    is($order_data->{'source'}, 'amazon', 'It has the correct source');
    ok($order_data->{'date'}, 'it has a date');
    my $order_id = $order_data->{'order_id'};

    # The order_item_detail table
    my $sth = $dbh->prepare('select * from order_item_detail where order_id = ?');
    ok($sth->execute($order_id), 'getting order_item_detail data');
    my %count_for_item;
    my %expected_item_id = (2 => 44444444444444);
    my $rows_read = 0;
    while(my $item_data = $sth->fetchrow_hashref()) {
        $rows_read++;
        $count_for_item{$item_data->{'item_id'}}++;
        is(get_order_item_id_for_detail_id($item_data->{'order_item_detail_id'}),
           $expected_item_id{$item_data->{'item_id'}},
           'order_item_id attribute matches');
    }
    is($rows_read, 2, 'Read 2 rows from the order_item_detail table');
    is(scalar(keys %count_for_item), 1, 'order_item_detail shows 1 distinct barcode');
    is($count_for_item{'2'}, 2, 'There were 2 item "2"s');
}

# 123-4567890-1234567 1 item 1
sub check_second_order {
    my $dbh = shift;

    my $order_data = $dbh->selectrow_hashref("select * from orders where order_number = '123-4567890-1234567'");
    ok($order_data, 'Got an order record for the second order');
    is($order_data->{'order_class'}, 'Inventory::Order::PickList', 'It is of the correct type');
    is($order_data->{'source'}, 'amazon', 'It has the correct source');
    ok($order_data->{'date'}, 'it has a date');
    my $order_id = $order_data->{'order_id'};

    # The order_item_detail table
    my $sth = $dbh->prepare('select * from order_item_detail where order_id = ?');
    ok($sth->execute($order_id), 'getting order_item_detail data');
    my %count_for_item;
    my %expected_item_id = (1 => 11111111111111);
    my $rows_read = 0;
    while(my $item_data = $sth->fetchrow_hashref()) {
        $rows_read++;
        $count_for_item{$item_data->{'item_id'}}++;
        is(get_order_item_id_for_detail_id($item_data->{'order_item_detail_id'}),
           $expected_item_id{$item_data->{'item_id'}},
           'order_item_id attribute matches');
    }
    is($rows_read, 1, 'Read 1 row from the order_item_detail table');
    is(scalar(keys %count_for_item), 1, 'order_item_detail shows 1 distinct barcode');
    is($count_for_item{'1'}, 1, 'There was 1 item "1"s');
}

# 234-5678901-2345678 1 item 1, 2 item 2s
sub check_third_order {
    my $dbh = shift;

    my $order_data = $dbh->selectrow_hashref("select * from orders where order_number = '234-5678901-2345678'");
    ok($order_data, 'Got an order record for the third order');
    is($order_data->{'order_class'}, 'Inventory::Order::PickList', 'It is of the correct type');
    is($order_data->{'source'}, 'amazon', 'It has the correct source');
    ok($order_data->{'date'}, 'it has a date');
    my $order_id = $order_data->{'order_id'};

    # The order_item_detail table
    my $sth = $dbh->prepare('select * from order_item_detail where order_id = ?');
    ok($sth->execute($order_id), 'getting order_item_detail data');
    my %count_for_item;
    my %expected_item_id = (1 => 22222222222222, 2 => 33333333333333);
    my $rows_read = 0;
    while(my $item_data = $sth->fetchrow_hashref()) {
        $rows_read++;
        $count_for_item{$item_data->{'item_id'}}++;
        is(get_order_item_id_for_detail_id($item_data->{'order_item_detail_id'}),
           $expected_item_id{$item_data->{'item_id'}},
           'order_item_id attribute matches');
    }
    is($rows_read, 3, 'Read 3 rows from the order_item_detail table');
    is(scalar(keys %count_for_item), 2, 'order_item_detail shows 2 distinct barcode');
    is($count_for_item{'1'}, 1, 'There was 1 item "1"s');
    is($count_for_item{'2'}, 2, 'There were 2 item "2"s');
}

# 222-3333333-4444444 1 item 2, 2 items 2s - Unfulfilled: short an item 2
sub check_fourth_order {
    my $dbh = shift;

    my $order_data = $dbh->selectrow_hashref("select * from orders where order_number = '222-3333333-4444444'");
    ok($order_data, 'Got an order record for the fourth order');
    is($order_data->{'order_class'}, 'Inventory::Order::PickList', 'It is of the correct type');
    is($order_data->{'source'}, 'amazon', 'It has the correct source');
    ok($order_data->{'date'}, 'it has a date');
    my $order_id = $order_data->{'order_id'};

    # The order_item_detail table
    my $sth = $dbh->prepare('select * from order_item_detail where order_id = ?');
    ok($sth->execute($order_id), 'getting order_item_detail data');
    my %count_for_item;
    my %expected_item_id = (1 => 66666666666666, 2 => 55555555555555);
    my $rows_read = 0;
    while(my $item_data = $sth->fetchrow_hashref()) {
        $rows_read++;
        $count_for_item{$item_data->{'item_id'}}++;
        is(get_order_item_id_for_detail_id($item_data->{'order_item_detail_id'}),
           $expected_item_id{$item_data->{'item_id'}},
           'order_item_id attribute matches');
    }
    is($rows_read, 4, 'Read 4 rows from the order_item_detail table');
    is(scalar(keys %count_for_item), 2, 'order_item_detail shows 2 distinct barcode');
    is($count_for_item{'1'}, 2, 'There was 2 item "1"s');
    is($count_for_item{'2'}, 2, 'There were 2 item "2"s');
}



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

