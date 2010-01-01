package Inventory::Command::PhysicalInventory;

use strict;
use warnings;

use Inventory;

class Inventory::Command::PhysicalInventory {
    is => 'Inventory::Command::ItemTransaction',
    doc => 'Read in barcodes and record a physical inventory',
    has => [
        year => { is => 'Integer', doc => 'Inventory for this year - used as part of the order number'},
        batch => { is => 'Boolean', default_value => 0, doc => 'Read a batch of barcodes from STDIN.  Prompt for new barcodes at the end instead of during' },
    ],
};

sub should_interrupt_for_new_barcodes {
    my $self = shift;
    return ! $self->batch;
}

sub _order_type_to_create {
    return 'Inventory::Order::InventoryCorrection';
}

sub _count_for_order_item_detail {
    1;
}

# For inventories, let's just have 1 row per item with the real count in that column
sub add_item {
    my($self, $item) = @_;

    my $order = $self->order;
    my $detail = Inventory::OrderItemDetail->get_or_create(order_id => $order->id,
                                                           item_id  => $item->id);
    my $count = $detail->count() || 0;
    $detail->count($count+1);
    return $detail;
}

sub resolve_order_number {
    my $self = shift;

    my $order_number = $self->order_number;
    unless (defined $order_number) {
        $order_number = $self->year . ' inventory';
        $self->order_number($order_number);
    }
    return $order_number;

#    my $order_type = $self->_order_type_to_create();
#    my $order = $order_type->get(order_number => $name);
#    if ($order) {
#        $self->status_message("Appending to existing inventory for ".$self->year);
#    } else {
#        $self->status_message("Starting a new inventory for ".$self->year);
#        $order = $order_type->create(order_number => $name);
#    }
#
#    return $order->order_number;
}
    
    
    

1;

