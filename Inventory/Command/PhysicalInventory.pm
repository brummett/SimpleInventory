package Inventory::Command::PhysicalInventory;

use strict;
use warnings;

use Inventory;

class Inventory::Command::PhysicalInventory {
    is => 'Inventory::Command::ItemTransaction',
    doc => 'Read in barcodes and record a physical inventory',
    has => [
        year => { is => 'Integer', doc => 'Inventory for this year - used as part of the order number'},
        batch => { is => 'Boolean', default_value => 1, doc => 'Read a batch of barcodes from STDIN.  Prompt for new barcodes at the end instead of during' },
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

sub resolve_order_number {
    my $self = shift;

    my $name = $self->year . ' inventory ';

    my $order_type = $self->_order_type_to_create();
    my $order = $order_type->get(order_number => $name);
    if ($order) {
        $self->status_message("Appending to existing inventory for ".$self->year);
    } else {
        $self->status_message("Starting a new inventory for ".$self->year);
        $order = $order_type->create(order_number => $name);
    }

    return $order;
}
    
    
    

1;

