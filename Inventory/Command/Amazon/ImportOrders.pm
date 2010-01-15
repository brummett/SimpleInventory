package Inventory::Command::Amazon::ImportOrders;

use strict;
use warnings;

use Inventory;

use IO::File;

class Inventory::Command::Amazon::ImportOrders {
    is => 'Inventory::Command::Amazon',
    has => [
        file => { is => 'String', doc => 'Pathname to the amazon order tab-delimited file' },
        'print' => { is => 'Boolean', default_value => 1, doc => 'Automaticly run the pick list printer after importing' },
    ],
    doc => 'Import an amazon orders file and generate pick list records for those orders',
};

sub execute {
    my $self = shift;

    my $file = $self->file;
    my $input;
    if (ref($file) and (ref($file) eq 'GLOB' or $file->can('getline'))) {
        $input = $file;
    } else {
        $input = IO::File->new($self->file, 'r');
    }

    unless ($input) {
        $self->error_message("Can't open input file ".$self->file.": $!");
        return;
    }

    my @first_line = split(/\t/, $input->getline());
  
    unless ($first_line[0] eq 'order-id' and $first_line[1] eq 'order-item-id' and
            $first_line[7] eq 'sku' and $first_line[9] eq 'quantity-purchased') { 
        $self->error_message("Input file format incorrect.\n" .
                             "Expected 'order-id', 'order-item-id','sku' and 'quantity-purchased' in columns 0,1,7 and 9");
        $self->error_message("Got '" . join("', '", @first_line[0,1,7,9]) . "'");
        return;
    }

    my %order_for_number;
    my @parsed_lines;

    FILE_LINE:
    while (my $line = $input->getline) {
        chomp $line;
        next unless $line;

        my %this_line;
        @this_line{qw(order_number order_item_id purchase_date payments_date buyer_email
                      buyer_name buyer_phone sku product_name quantity currency item_price
                      item_tax shipping_price shipping_tax ship_service_level recepient_name
                      ship_addr_1 ship_addr_2 ship_addr_3 ship_city ship_state ship_zip ship_country
                      ship_phone delivery_start_date delivery_end_date delivery_time_zone
                      delivery_instructions)} = split(/\t/,$line);

        my $order_number = $this_line{'order_number'};
        my %warned;
        unless ($order_for_number{$order_number}) {
            my $order = Inventory::Order->get(order_number => $order_number);
            if ($order and !$warned{$order_number}) {
                $self->warning_message("Skipping already processed order $order_number");
                $warned{$order_number} = 1;
                next FILE_LINE;
            }
            $order = Inventory::Order::PickList->create(order_number => $order_number,
                                                        source => 'amazon');
            unless ($order) {
                $self->error_message("Couldn't create order record for order number $order_number");
                die "Exiting without saving";
            }
            $order_for_number{$order_number} = $order;

            $order->add_attribute(name => 'recipient_name', value => $this_line{'recepient_name'});
            $order->add_attribute(name => 'buyer_email', value => $this_line{'buyer_email'});
            $order->add_attribute(name => 'ship_address_1', value => $this_line{'ship_addr_1'});
            $order->add_attribute(name => 'ship_address_2', value => $this_line{'ship_addr_2'});
            $order->add_attribute(name => 'ship_address_3', value => $this_line{'ship_addr_3'});
            $order->add_attribute(name => 'ship_city', value => $this_line{'ship_city'});
            $order->add_attribute(name => 'ship_state', value => $this_line{'ship_state'});
            $order->add_attribute(name => 'ship_zip', value => $this_line{'ship_zip'});
            $order->add_attribute(name => 'ship_country', value => $this_line{'ship_country'});
            $order->add_attribute(name => 'ship_phone', value => $this_line{'ship_phone'});
            $order->add_attribute(name => 'ship_service_level', value => $this_line{'ship_service_level'});
            $order->add_attribute(name => 'purchase_date', value => $this_line{'purchase_date'});

        }

        push @parsed_lines, \%this_line;
    }

    foreach my $line ( @parsed_lines ) {
        my $order_number = $line->{'order_number'};
        my $order = $order_for_number{$order_number};
        unless ($order) {
            $self->error_message("Could not recall order record for order number $order_number");
            die "Exiting without saving";
        }

        my $sku = $line->{'sku'};
        my $item = Inventory::Item->get(sku => $sku);
        unless ($item) {
            $self->error_message("Couldn't find item with sku $sku for order number $order_number");
            die "Exiting without saving";
        }

        
        for (my $i = 0; $i < $line->{'quantity'}; $i++) {
if (! $ENV{'INVENTORY_TEST'} and $line->{'quantity'} > 1) {
die "Quantity greater than 1 on order $order_number order_item_id " . $line->{'order_item_id'} . "!!  Check the item_price column and adjust PrintPickList->print_order!!!"
}
            my $detail = $order->add_item($item);
            unless ($detail) {
                $self->error_message("Couldn't add item with sku $sku to order $order_number");
                die "Exiting without saving";
            }
            # Used later to create the file to upload to amazon confirming the orders shipping out
            $detail->add_attribute(name => 'order_item_id', value => $line->{'order_item_id'});
            $detail->add_attribute(name => 'item_price', value => $line->{'item_price'});
            $detail->add_attribute(name => 'shipping_price', value => $line->{'shipping_price'});
        }

    }

    $self->status_messages("Created pick list order for ".scalar(keys %order_for_number) . " orders\n");

    if ($self->print) {
        my $cmd = Inventory::Command::Print::PickList->create();
        if ($cmd) {
            unless ($cmd->execute()) {
                $self->error_message("Couldn't print pick list");
            }
        } else {
            $self->error_message("Couldn't create print pick list command");
        }
    }
           
    return 1;
}

1;
