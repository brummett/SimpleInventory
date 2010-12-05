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

sub get_order_object {
    my $self = shift;

    my $order = $self->SUPER::get_order_object();
    return unless $order;

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
    if ($barcode =~ m/(\d+)\s+(\S+)/) {
        my $count = $1;
        $barcode = $2;

        my @barcodes;
        while ($count--) {
            push @barcodes, $barcode;
        }
        return @barcodes;
    }
    return $barcode;
}


sub _prompt_and_get_answer {
    my($self,$prompt,$dfl_answer) = @_;

    $prompt .= " [$dfl_answer]" if $dfl_answer;
    $self->status_message($prompt . ': ');
    my $answer = <STDIN>;
    unless (length $answer) {
        return $dfl_answer;
    }
    return $answer;
}

1;
