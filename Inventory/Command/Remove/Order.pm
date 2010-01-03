package Inventory::Command::Remove::Order;

use strict;
use warnings;

use Inventory;

class Inventory::Command::Remove::Order {
    is => 'Inventory::Command::Remove',
    has => [
        order_number => { is => 'String', doc => 'Order number to remove' },
    ],
};

sub execute {
    my $self = shift;

    my $order = Inventory::Order->get(order_number => $self->order_number);
    unless ($order) {
        $self->error_message("There is no order record with that order number");
        return;
    }

    my @details = $order->item_details;
    $self->status_message("Removing ".scalar(@details)." line items from order");

    $_->delete foreach @details;
    $order->delete;

    $self->status_message("Removed.");
    return 1;
};

1;

