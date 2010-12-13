#!/usr/bin/perl

BEGIN {
    $ENV{'INVENTORY_TEST'} = 1;
}

# Test generating a pick list from an amazon seller account orders file
use strict;
use warnings;

use Test::More;
use above 'Inventory';

plan tests => 64;

my $dbh = &setup_db();

my $cmd = Inventory::Command::ManualOrder->create();
ok($cmd, 'Instantiated manual order command object');
$cmd->dump_warning_messages(0);
$cmd->dump_error_messages(0);
$cmd->queue_warning_messages(1);
$cmd->queue_error_messages(1);
#
# Prompts are:
# order number
# order source
# recipient name
# buyer email
# ship_address1, 2, 3
# ship city
# ship state
# ship zip
# ship_phone
# ship country
# ship_service level
# shipping price for the whole order
# purchase date
# scan item
# item price

# 111-2222222-3333333 (expedited) 2 item 2222s
my $data = qq(111-2222222-3333333

Chuck Jones
example3\@example.net
999 Oak St


Nowhere
NY
22222-3333
555-123-4567

Expedited
1.99

2 2222
1.29
);

close(STDIN);
open(STDIN, '<', \$data);
ok($cmd->execute(), 'executed ok');
my @errors = $cmd->error_messages();
is(scalar(@errors), 0, 'There were no errors');
my @warnings = $cmd->warning_messages();
is(scalar(@warnings), 0, 'There were no warnings');




$cmd = Inventory::Command::ManualOrder->create();
ok($cmd, 'Instantiated manual order command object');
$cmd->dump_warning_messages(0);
$cmd->dump_error_messages(0);
$cmd->queue_warning_messages(1);
$cmd->queue_error_messages(1);
# 123-4567890-1234567 1 item 1111
$data = qq(123-4567890-1234567
ebay
Bob Smith
example\@example.net
123 Main St


Nowhere
FL
55443-3221
555-123-4567

Standard
1.99

1111
1.29
);

close(STDIN);
open(STDIN, '<', \$data);
ok($cmd->execute(), 'executed ok');
@errors = $cmd->error_messages();
is(scalar(@errors), 0, 'There were no errors');
@warnings = $cmd->warning_messages();
is(scalar(@warnings), 0, 'There were no warnings');




$cmd = Inventory::Command::ManualOrder->create();
ok($cmd, 'Instantiated manual order command object');
$cmd->dump_warning_messages(0);
$cmd->dump_error_messages(0);
$cmd->queue_warning_messages(1);
$cmd->queue_error_messages(1);
# 234-5678901-2345678 1 item 1111, 2 item 2222s
$data = qq(234-5678901-2345678
amazon
Bob Jones
example2\@example.net
456 Elm St


Somewhere
AK
11111-2222
555-123-4567
US
Standard
1.99

1111
1.29
2222
1.29
2222
1.29
);

close(STDIN);
open(STDIN, '<', \$data);
ok($cmd->execute(), 'executed ok');
@errors = $cmd->error_messages();
is(scalar(@errors), 0, 'There were no errors');
@warnings = $cmd->warning_messages();
is(scalar(@warnings), 0, 'There were no warnings');



$cmd = Inventory::Command::ManualOrder->create();
ok($cmd, 'Instantiated manual order command object');
$cmd->dump_warning_messages(0);
$cmd->dump_error_messages(0);
$cmd->queue_warning_messages(1);
$cmd->queue_error_messages(1);
# 222-3333333-4444444 2 item 1111s, 2 items 2222s - Unfulfilled: short an item 2222
$data = qq(222-3333333-4444444
web
John Johnson
example4\@example.net
111 Main St


Somewhere
NY
22222-3333
555-123-4567

Standard
1.99

2 1111
1.29
2 2222
1.29
);

close(STDIN);
open(STDIN, '<', \$data);
ok($cmd->execute(), 'executed ok');
@errors = $cmd->error_messages();
is(scalar(@errors), 0, 'There were no errors');
@warnings = $cmd->warning_messages();
is(scalar(@warnings), 0, 'There were no warnings');


$cmd = Inventory::Command::ManualOrder->create();
ok($cmd, 'Instantiated manual order command object');
$cmd->dump_warning_messages(0);
$cmd->dump_error_messages(0);
$cmd->queue_warning_messages(1);
$cmd->queue_error_messages(1);
# 999999 item 4444, 2 5555s.  Both are new items
$data = qq(999999
web
Test Testerson
example5\@example.net
222 Main St


Somewhere
NY
22222-3333
555-123-4567

Standard
1.99

4444
12345678
Some Thingy
1.29
2 5555
234567890
Some other thing
1.29
);

close(STDIN);
open(STDIN, '<', \$data);
ok($cmd->execute(), 'executed ok');
@errors = $cmd->error_messages();
is(scalar(@errors), 0, 'There were no errors');
@warnings = $cmd->warning_messages();
is(scalar(@warnings), 0, 'There were no warnings');


ok(UR::Context->commit(), 'Commit DB');

$DB::single=1;
&check_first_order($dbh);
&check_second_order($dbh);
&check_third_order($dbh);
&check_fourth_order($dbh);
&check_fifth_order($dbh);

#sub get_order_item_id_for_detail_id {
#    my $detail_id = shift;
#
#    my $attr_sth = $dbh->prepare_cached("select attr.value from order_item_detail d join order_item_detail_attribute attr on attr.order_item_detail_id = d.order_item_detail_id where d.order_item_detail_id = ? and name = 'order_item_id'");
#
#    $attr_sth->execute($detail_id);
#    my $row = $attr_sth->fetchrow_arrayref();
#    my $id = $row->[0];
#    $attr_sth->finish();
#    return $id;
#}


# 111-2222222-3333333 (expedited) 2 item 2
sub check_first_order {
    my $dbh = shift;

    my $order_data = $dbh->selectrow_hashref("select * from orders where order_number = '111-2222222-3333333'");
    ok($order_data, 'Got an order record for the first order');
    is($order_data->{'order_class'}, 'Inventory::Order::PickList', 'It is of the correct type');
    is($order_data->{'source'}, 'web', 'It has the correct source');
    ok($order_data->{'date'}, 'it has a date');
    my $order_id = $order_data->{'order_id'};

    # The order_item_detail table
    my $sth = $dbh->prepare('select * from order_item_detail where order_id = ?');
    ok($sth->execute($order_id), 'getting order_item_detail data');
    my %count_for_item;
    my $rows_read = 0;
    while(my $item_data = $sth->fetchrow_hashref()) {
        $rows_read++;
        $count_for_item{$item_data->{'item_id'}}++;
    }
    is($rows_read, 2, 'Read 2 rows from the order_item_detail table');
    is(scalar(keys %count_for_item), 1, 'order_item_detail shows 1 distinct barcode');
    is($count_for_item{'20'}, 2, 'There were 2 item "2"s');
}

# 123-4567890-1234567 1 item 1
sub check_second_order {
    my $dbh = shift;

    my $order_data = $dbh->selectrow_hashref("select * from orders where order_number = '123-4567890-1234567'");
    ok($order_data, 'Got an order record for the second order');
    is($order_data->{'order_class'}, 'Inventory::Order::PickList', 'It is of the correct type');
    is($order_data->{'source'}, 'ebay', 'It has the correct source');
    ok($order_data->{'date'}, 'it has a date');
    my $order_id = $order_data->{'order_id'};

    # The order_item_detail table
    my $sth = $dbh->prepare('select * from order_item_detail where order_id = ?');
    ok($sth->execute($order_id), 'getting order_item_detail data');
    my %count_for_item;
    my $rows_read = 0;
    while(my $item_data = $sth->fetchrow_hashref()) {
        $rows_read++;
        $count_for_item{$item_data->{'item_id'}}++;
    }
    is($rows_read, 1, 'Read 1 row from the order_item_detail table');
    is(scalar(keys %count_for_item), 1, 'order_item_detail shows 1 distinct barcode');
    is($count_for_item{'10'}, 1, 'There was 1 item "1"s');
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
    my $rows_read = 0;
    while(my $item_data = $sth->fetchrow_hashref()) {
        $rows_read++;
        $count_for_item{$item_data->{'item_id'}}++;
    }
    is($rows_read, 3, 'Read 3 rows from the order_item_detail table');
    is(scalar(keys %count_for_item), 2, 'order_item_detail shows 2 distinct barcode');
    is($count_for_item{'10'}, 1, 'There was 1 item "1"s');
    is($count_for_item{'20'}, 2, 'There were 2 item "2"s');
}

# 222-3333333-4444444 1 item 2, 2 items 2s - Unfulfilled: short an item 2
sub check_fourth_order {
    my $dbh = shift;

    my $order_data = $dbh->selectrow_hashref("select * from orders where order_number = '222-3333333-4444444'");
    ok($order_data, 'Got an order record for the fourth order');
    is($order_data->{'order_class'}, 'Inventory::Order::PickList', 'It is of the correct type');
    is($order_data->{'source'}, 'web', 'It has the correct source');
    ok($order_data->{'date'}, 'it has a date');
    my $order_id = $order_data->{'order_id'};

    # The order_item_detail table
    my $sth = $dbh->prepare('select * from order_item_detail where order_id = ?');
    ok($sth->execute($order_id), 'getting order_item_detail data');
    my %count_for_item;
    my $rows_read = 0;
    while(my $item_data = $sth->fetchrow_hashref()) {
        $rows_read++;
        $count_for_item{$item_data->{'item_id'}}++;
    }
    is($rows_read, 4, 'Read 4 rows from the order_item_detail table');
    is(scalar(keys %count_for_item), 2, 'order_item_detail shows 2 distinct barcode');
    is($count_for_item{'10'}, 2, 'There was 2 item "1"s');
    is($count_for_item{'20'}, 2, 'There were 2 item "2"s');
}


# 999999 item 4444, 2 5555s.  Both are new items
sub check_fifth_order {
    my $dbh = shift;

    my $order_data = $dbh->selectrow_hashref("select * from orders where order_number = '999999'");
    ok($order_data, 'Got an order record for the fifth order');
    is($order_data->{'order_class'}, 'Inventory::Order::PickList', 'It is of the correct type');
    is($order_data->{'source'}, 'web', 'It has the correct source');
    ok($order_data->{'date'}, 'it has a date');
    my $order_id = $order_data->{'order_id'};

    # The order_item_detail table
    my $sth = $dbh->prepare('select * from order_item_detail oid join item i on i.item_id = oid.item_id where order_id = ?');
    ok($sth->execute($order_id), 'getting order_item_detail data');
    my %count_for_item;
    my $rows_read = 0;
    while(my $item_data = $sth->fetchrow_hashref()) {
        $rows_read++;
        $count_for_item{$item_data->{'sku'}}++;
    }
    is($rows_read, 3, 'Read 3 rows from the order_item_detail table');
    is(scalar(keys %count_for_item), 2, 'order_item_detail shows 2 distinct barcode');
    is($count_for_item{'4444'}, 1, 'There was 1 item with sku 4444');
    is($count_for_item{'5555'}, 2, 'There were 2 item with sku 5555');
}



sub setup_db {
    my $dbh = Inventory::DataSource::Inventory->get_default_handle();

    my $sth = $dbh->prepare('insert into item (item_id, barcode, sku, desc) values (?,?,?,?)');
    foreach my $row ( [10,1,1111,'item one'],
                      [20,2,2222,'item two'],
                      [30,3,3333,'item three'],
                    ) {
        $sth->execute(@$row);
    }
    $sth->finish;

    $sth = $dbh->do("insert into orders (order_id, order_number, order_class) values (-1, 'foo', 'Inventory::Order::InventoryCorrection')");

    $sth = $dbh->prepare('insert into order_item_detail (order_item_detail_id,order_id,item_id,count) values (?,?,?,?)');
    foreach my $row ( [-1,-1,10,3],
                      [-2,-1,20,5],
                    ) {
        $sth->execute(@$row);
    }
    return $dbh;
}

