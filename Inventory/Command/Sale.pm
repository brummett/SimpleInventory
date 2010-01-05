package Inventory::Command::Sale;

use strict;
use warnings;

use Inventory;

class Inventory::Command::Sale {
    is => 'Inventory::Command::ItemTransaction',
    doc => 'Record a sales transaction',
};

sub _order_type_to_create {
    return 'Inventory::Order::Sale';
}

sub _count_for_order_item_detail {
    -1;
}


sub execute {
    my $self = shift;

    my $order_number = $self->resolve_order_number();

    my $picklist = Inventory::Order::PickList->get(order_number => $order_number);
    if ($picklist) {
        # Delegate to the fill pick list command...
        my $cmd = Inventory::Command::FillPickList->create(order_number => $picklist->order_number);
        unless ($cmd) {
            $self->error_message("Couldn't start up a Fill Pick List Command");
            return;
        }
        return $cmd->execute();
    }

    $self->order_number($order_number);

    my $super = $self->super_can('_execute_body');
    return $super->($self);
}

1;
