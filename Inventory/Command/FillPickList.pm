package Inventory::Command::FillPickList;

use strict;
use warnings;

use Inventory;

class Inventory::Command::FillPickList {
    is => 'Inventory::Command::ItemTransaction',
    doc => 'Turn a perviously generated pick list into a sales order',
    has_optional => [
        _sale => { is => 'Inventory::Order::Sale' },
    ],
    has => [
        order => { is => 'Inventory::Order::PickList',
                   calculate => q( my $order_number = $self->order_number;
                                   my $order = Inventory::Order::PickList->get(order_number => $order_number);
                                   return $order ),
                 },
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
        $self->warning_message("Found a Sale order with that order number.  Make sure this is really a subsequent shipment!");
    } else {
        $sale = $order_type->create(order_number => $order_number, source => $picklist->source);
        # Copy any attributes from the picklist over to the sale
        my @attrs = $picklist->attributes();
        foreach my $attr ( @attrs ) {
            $sale->add_attribute(name => $attr->name, value => $attr->value);
        }
    }
    $self->_sale($sale);

    my $count = $picklist->item_detail_count;
    $self->status_message("This PickList has $count items to fill");
    unless ($count) {
        return;
    }

    $self->status_message("Filling pick list order $order_number");

    return $picklist;
}
    

sub add_item {
    my($self,$item) = @_;

    my $picklist = $self->order;
    my $sale = $self->_sale;

    my $expected_count = $self->_count_for_order_item_detail;
    my $detail = (Inventory::OrderItemDetail->get(order_id => $picklist->id, item_id => $item->id))[0];
    unless ($detail) {
        my @already_scanned = Inventory::OrderItemDetail->get(order_id => $sale->id, item_id => $item->id);
        if (@already_scanned) {
            $self->error_message(sprintf("Item %s barcode %s: Pick list called for %d, this is number %d",
                                         $item->desc,
                                         $item->barcode,
                                         scalar(@already_scanned),
                                         scalar(@already_scanned) + 1));
        } else {
            $self->error_message(sprintf("Item %s barcode %s was not part of this pick list",
                                         $item->desc, $item->barcode));
        }
        Inventory::Util->play_sound('error');
        die "Exiting without saving\n";
    }

    if ($detail->count == $expected_count) {
        $detail->order_id($sale->id);  # move it to the sale order

    } elsif ($detail->count >= 0) {
        $self->error_message("Found an order item with non-negative count!?");
        $self->error_message(sprintf("order %s detail id %d", $picklist->order_number, $detail->id));
        die "Exiting without saving\n";

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

    $self->warning_message("Some items still have not been applied to the sale");
    foreach my $item ( @$problem_items ) {
        $self->warning_message(sprintf("\tbarcode %s sku %s short %d %s\n",
                                       $item->barcode, $item->sku, abs($item->count_for_order($order)), $item->desc));
    }
    1;
}


sub execute {
    my $self = shift;

    my $super_execute = $self->super_can('_execute_body');
    my $ret = $super_execute->($self,@_);

    my $picklist = $self->order;
    my $sale = $self->_sale;

    unless ($ret) {
        die "Filling order failed.  Exiting without saving\n";
    }

    unless ($picklist and $sale) {
        die "picklist or sale were missing :(.  Exiting without saving\n";
    }

    my @items = $picklist->items();
    unless (@items) {
        $self->status_message("PickList has been completely filled");
        $picklist->delete();
    }
    
    $self->status_message("Saving changes!");

    return $ret;
}

1;
