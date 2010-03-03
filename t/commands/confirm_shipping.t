#!/usr/bin/perl

BEGIN {
    $ENV{'INVENTORY_TEST'} = 1;
}

# Test generating a pick list from an amazon seller account orders file
use strict;
use warnings;

use Test::More;
use File::Temp;
use above 'Inventory';

plan tests => 19;

my $dbh = &setup_db();

my $data_fh = \*DATA;
my $cmd = Inventory::Command::Amazon::ImportOrders->create(file => $data_fh, 'print' => 0);
ok($cmd, 'Create amazon import order command object');
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


# Amazon::ImportOrders made picklists.  Convert them to regular sales orders
# as would have been done if we completed a regular sales order...
my @picklists = Inventory::Order::PickList->get(order_number => ['111-2222222-3333333','123-4567890-1234567','234-5678901-2345678']);
is(scalar(@picklists), 3, 'Retrieved 3 picklists');
foreach my $pick ( @picklists) {
    my @items = $pick->item_details;
    my $sale = Inventory::Order::Sale->create(order_number => $pick->order_number, source => $pick->source);
    ok($sale, 'Converting picklist to sale order');
    $_->order_id($sale->order_id) foreach @items;
    $pick->delete();
}
    

##my($tmpfh,$tmpfile) = File::Temp::tempfile();
##$tmpfh->close;
#my $tmpfile = '/tmp/pick_list.txt';
#$cmd = Inventory::Command::PrintPickList->create(file => $tmpfile, 'print' => 0);
#ok($cmd, 'Created picklist command');
#$cmd->dump_warning_messages(0);
#$cmd->dump_error_messages(0);
#$cmd->queue_warning_messages(1);
#$cmd->queue_error_messages(1);
#ok($cmd->execute(), 'executed ok');

my($tmpfh,$amazon_upload_file) = File::Temp::tempfile();
$tmpfh->close;
#my $amazon_upload_file = '/tmp/amazon_confirm_upload.txt';
$cmd = Inventory::Command::ConfirmShipping->create(amazon_file => $amazon_upload_file);
ok($cmd, 'Created confirm shipping command');
$cmd->dump_warning_messages(0);
$cmd->dump_error_messages(0);
$cmd->queue_warning_messages(1);
$cmd->queue_error_messages(1);
$cmd->dump_status_messages(0);
$cmd->queue_status_messages(1);
my $input = q(111-2222222-3333333
tracking1


234-5678901-2345678
tracking3
UPS
ground
);
close(STDIN);
open(STDIN,'<',\$input);
ok($cmd->execute(), 'executed ok');

my @messages = $cmd->error_messages();
is(scalar(@messages), 0, 'Saw no error messages');
@messages = $cmd->warning_messages();
is(scalar(@messages), 0, 'Saw no warning messages');
@messages = $cmd->status_messages();
is(scalar(@messages), 3, 'Saw 3 status messages');
like($messages[0], qr/There are still 1 unconfirmed shipments/, 'Says there is one unconfirmed shipment');
like($messages[1], qr/123-4567890-1234567/, 'mentioned the right order number');
like($messages[2], qr/Saving changes/, 'Says it is aving changes');

# Check the contents of the amazon upload file
ok(-f $amazon_upload_file, 'Amazon upload file exists');
my $date_str = POSIX::strftime("%F", localtime());  # yyyy-mm-dd
my @expected = (
['order-id','order-item-id','quantity','ship-date','carrier-code','carrier-name','tracking-number','ship-method'],
['111-2222222-3333333','44444444444444','2',$date_str,'USPS','tracking1','priority'],
['234-5678901-2345678','22222222222222','1',$date_str,'UPS','tracking3','ground'],
['234-5678901-2345678','33333333333333','2',$date_str,'UPS','tracking3','ground'],
);
&compare_amazon_file_contents($amazon_upload_file, \@expected);

1;


sub compare_amazon_file_contents {
    my($amazon_upload_file, $expected_data) = @_;

    my $fh = IO::File->new($amazon_upload_file);
    my $file_data = [];
    while(my $line = $fh->getline()) {
        chomp $line;
        my @line = split(/\s+/,$line);
        push @$file_data, \@line;
    }

    is_deeply($file_data, $expected_data, 'Amazon file contents is expected');
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

