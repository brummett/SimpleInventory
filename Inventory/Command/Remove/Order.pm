package Inventory::Command::Remove::Order;

use strict;
use warnings;

use Inventory;

class Inventory::Command::Remove::Order {
    is => 'Inventory::Command::Remove',
    has_optional => [
        order_number => { is => 'String', doc => 'Order number to remove' },
    ],
};

sub execute {
    my $self = shift;

    unless ($self->order_number) {
        my @order = $self->bare_args;
        $self->order_number($order[0]);
    }

    my $order = Inventory::Order->get(order_number => $self->order_number);
    unless ($order) {
        $self->error_message("There is no order record with order number '" . $self->order_number . "'");
        return;
    }

    my @attrs = $order->attributes();
    $_->delete foreach @attrs;

    my @details = $order->item_details;
    $self->status_message("Removing ".scalar(@details)." line items from order");

    $_->delete foreach @details;
    $order->delete;

    $self->status_message("Removed.");
    return 1;
};

1;

