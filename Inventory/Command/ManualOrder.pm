package Inventory::Command::ManualOrder;

use strict;
use warnings;

use Inventory;

class Inventory::Command::ManualOrder {
    is => 'Inventory::Command::ItemTransaction',
    doc => 'Allow the user to input order details from the terminal and create a picklist order',
};

sub _order_type_to_create {
    return 'Inventory::Order::PickList';
}

sub _count_for_order_item_detail {
    -1;
}

sub should_interrupt_for_new_barcodes {
    1;
}

sub get_order_object {
    my $self = shift;

    my $order = $self->SUPER::get_order_object();
    return unless $order;

    # If it has changes, it's a new order object and we need to prompt for its attributes
    return $order unless ($order->__changes__);

    unless ($order->source) {
        my $source = $self->_prompt_and_get_answer('order source', 'web');
        $order->source($source);
    }

    foreach my $prompt ( qw(recipient_name buyer_email ship_address_1 ship_address_2 ship_address_3
                            ship_city ship_state ship_zip ship_phone ) ) {
        my $answer = $self->_prompt_and_get_answer($prompt,'');
        if (length $answer) {
            $order->add_attribute(name => $prompt, value => $answer);
        }
    }

    my $country = $self->_prompt_and_get_answer('ship_country', 'US');
    $order->add_attribute(name => 'ship_country', value => $country);

    my $ship_level = $self->_prompt_and_get_answer('ship_service_level', 'standard');
    $order->add_attribute(name => 'ship_service_level', value => $ship_level);
    
    my $shipping_price = $self->_prompt_and_get_answer('shipping_price','');
    $order->add_attribute(name => 'shipping_price', value => $shipping_price);
    
    my $date = $self->_prompt_and_get_answer('purchase_date', scalar(localtime));
    $order->add_attribute(name => 'purchase_date', value => $date);

    return $order;
}

sub get_barcode_from_user {
    my $self = shift;

    my $barcode = $self->SUPER::get_barcode_from_user();
    return unless $barcode;
    my $count = 1;
    if ($barcode =~ m/(\d+)\s+(\S+)/) {
        $count = $1;
        $barcode = $2;
    }

    my $item = Inventory::Item->get(sku => $barcode) || Inventory::Item->get(barcode => $barcode);
    return unless $item;

    $barcode = $item->barcode;

    while(1) {
        my $price = $self->_prompt_and_get_answer("Item price");
        unless (length $price) {
            $self->warning_message("Please enter a price for this item");
            next;
        }
        $self->{'_prices'}->{$item->id} = $price;  # Hack to save away the price until add_item
        last;
    }
    
    my @barcodes;
    while ($count--) {
        push @barcodes, $barcode;
    }
    return @barcodes;
}

sub add_item {
    my($self, $item) = @_;

    my $oid = $self->SUPER::add_item($item);

    unless (exists $self->{'_prices'}->{$item->id}) {
        $self->error_message("No item price info found for item sku ".$item->sku);
        return;
    }
        
    my $price = $self->{'_prices'}->{$item->id};
    $oid->add_attribute(name => 'item_price', value => $price);

    return $oid;
}


sub _prompt_and_get_answer {
    my($self,$prompt,$dfl_answer) = @_;

    $prompt .= " [$dfl_answer]" if $dfl_answer;
    $self->status_message($prompt . ': ');
    my $answer = <STDIN>;
    chomp($answer);
    unless (length $answer) {
        return $dfl_answer;
    }
    return $answer;
}

1;
