package Inventory::Command::FillPickList;

use strict;
use warnings;

use Inventory;

class Inventory::Command::Sale {
    is => 'Inventory::Command::ItemTransaction',
    doc => 'Turn a perviously generated pick list into a sales order',
    has => [
        _sale => { is => 'Inventory::Order::Sale' },
    ],
};

sub _order_type_to_create {
    return 'Inventory::Order::Sale';
}

sub _count_for_order_item_detail {
    -1;
}


sub get_order_object {
    my $self = shift;

    if ($self->append || $self->remove) {
        $self->error_message("appending or removing from a pick list is not supported");
        return;
    }

    my $order_number = $self->resolve_order_number();

    my $picklist = Inventory::Order::PickList->get(order_number => $order_number);
    unless ($picklist) {
        $self->error_message("Couldn't find a pick list order with order number $order_number");
        return;
    }


    my $order_type = $self->_order_type_to_create();
    my $sale = $order_type->get(order_number => $order_number);
    if ($sale) {
        $self->error_message("Found a Sale order with order_number!?  That's not right!");
        return;
    }

    # Temporarily, there'll be more than 1 order with the same order_number
    $sale = $order_type->create(order_number => $order_number, source => $picklist->source);
    $self->status_message("Filling pick list order $order_number");

    $self->_sale($sale);

    return $picklist;
}
    

sub add_item {
    my($self,$item) = @_;

    my $picklist = $self->order;
    my $sale = $self->_sale;

    my $expected_count = $self->_count_for_order_item_detail;
    my $detail = (Inventory::OrderItemDetail->get(order_id => $picklist->id, item_id => $item->id))[0];
    unless ($detail) {
        $self->error_message(sprintf("Item %s barcode %s was not part of this pick list",
                                     $item->desc, $item->barcode));
        Inventory::Util->play_sound('error');
        return;
    }

    if ($detail->count == $expected_count) {
        $detail->order_id($sale->id);  # move it to the sale order

    } elsif ($detail->count >= 0) {
        $self->error_message("Found an order item with non-negative count!?");
        $self->error_message(sprintf("order %s detail id %d", $picklist->order_number, $detail->id));
        die "Exiting without saving";

    } else {
        my $count = $detail->count();
        $detail->count($count - 1);
        $detail = $sale->add_item_detail(item_id => $item->id, count => $expected_count);
        unless ($detail) {
            $self->error_message("Couldn't create item detail record for order ".$self->order_number);
            Inventory::Util->play_sound('error');
            return;
        }
    }

    return $detail;
}

sub remove_item {
    die __PACKAGE__ . " does not support remove_item()";
}


sub check_order_for_items_below_zero_count {
    my($self, $order) = @_;

    my %items = map { $_->id => $_ } $order->items();
    my @items = values %items;

    return @items;
}

sub orders_report_on_items {
    my($self,$problem_items) = @_;

    my $order = $self->order;

    $self->error_message("Some items still have not been applied to the sale");
    foreach my $item ( @$problem_items ) {
        $self->status_message(sprintf("\tbarcode %s sku %s short %d %s\n",
                                      $item->barcode, $item->sku, $item->count_for_order($order)));
    }
    die "Exiting without saving";
}


sub execute {
    my $self = shift;

    my $super_execute = $self->super_can('_execute_body');
    my $ret = $super_execute->($self,@_);

    if ($ret) {
        my $picklist = $self->order;
        my $sale = $self->_sale;
        unless ($picklist and $sale) {
            die "picklist or sale were missing :(.  Exiting without saving";
        }
        
        $self->status_message("Saving changes!");
        $picklist->delete();
    }

    return $ret;
}

1;
