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

$DB::single=1;
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

    my $prior_order = Inventory::Order->get(order_number => $first_line[0]);
    next if ($prior_order);  # We've already done something with this order
                                         
#    my @lines_to_process;
#    while (my $line = $input->getline) {
#        chomp $line;
#        last unless ($line);
#
#        my @line = split(/\t/, $line);
#        # Expediteds get filled first
#        if ($line[15] =~ m/expedited/i) {
#            unshift(@lines_to_process, \@line);
#        } else {
#            push(@lines_to_process, \@line);
#        }
#    }

    my $count = 0;
    while (my $line = $input->getline) {
        chomp $line;
        next unless $line;

        my @this_line = split(/\t/,$line);

        my($order_number, $order_item_id, $purchase_date, $payments_date, $buyer_email,
           $buyer_name, $buyer_phone, $sku, $product_name, $quantity, $currency, $item_price,
           $item_tax, $shipping_price, $shipping_tax, $ship_service_level, $recepient_name,
           $ship_addr_1, $ship_addr_2, $ship_addr_3, $ship_city, $ship_state, $ship_zip, $ship_country,
           $ship_phone, $delivery_start_date, $delivery_end_date, $delivery_time_zone,
           $delivery_instructions) = @this_line;

        my $order = Inventory::Order::PickList->get(order_number => $order_number);
        unless ($order) {
            $count++;
            $order = Inventory::Order::PickList->create(order_number => $order_number,
                                                        source => 'amazon');
            unless ($order) {
                $self->error_message("Couldn't create order record for order number $order_number");
                die "Exiting without saving";
            }

            $order->add_attribute(name => 'recipient_name', value => $recepient_name);
            $order->add_attribute(name => 'ship_address_1', value => $ship_addr_1);
            $order->add_attribute(name => 'ship_address_2', value => $ship_addr_2);
            $order->add_attribute(name => 'ship_address_3', value => $ship_addr_3);
            $order->add_attribute(name => 'ship_city', value => $ship_city);
            $order->add_attribute(name => 'ship_state', value => $ship_state);
            $order->add_attribute(name => 'ship_zip', value => $ship_zip);
            $order->add_attribute(name => 'ship_country', value => $ship_country);
            $order->add_attribute(name => 'ship_phone', value => $ship_phone);
            $order->add_attribute(name => 'ship_service_level', value => $ship_service_level);
        }

        my $item = Inventory::Item->get(sku => $sku);
        unless ($item) {
            $self->error_message("Couldn't find item with sku $sku for order number $order_number");
            die "Exiting without saving";
        }

        for (my $i = 0; $i < $quantity; $i++) {
            my $detail = $order->add_item($item);
            unless ($detail) {
                $self->error_message("Couldn't add item with sku $sku to order $order_number");
                die "Exiting without saving";
            }
            $detail->add_attribute(name => 'order_item_id', value => $order_item_id);
        }

        # Used later to create the file to upload to amazon confirming the orders shipping out
    }

    $self->status_messages("Created pick list order for $count orders\n");

    if ($self->print) {
        my $cmd = Inventory::Command::PrintPickList->create();
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
