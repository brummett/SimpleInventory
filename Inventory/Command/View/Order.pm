package Inventory::Command::View::Order;

use strict;
use warnings;

use Inventory;

class Inventory::Command::View::Order {
    is => 'Inventory::Command::View',
    has_optional => [
        order_number => { is => 'String', doc => 'Order number to view' },
        order => { is => 'Inventory::Order', is_calculated => 1,
                   calculate => q( return Inventory::Order->get(order_number => $self->order_number) ) },
    ],
};

sub execute {
    my $self = shift;

    unless ($self->order_number) {
        $DB::single=1;
        my @params = $self->bare_args();
        $self->order_number($params[0]);
    }

    my $order = $self->order();
    unless ($order) {
        $self->error_message("Couldn't find an order with order number '" . $self->order_number . "'");
        return;
    }

    # FIXME - make this into a viewer...
    $self->status_message(sprintf("%s order on %s.  %d items (%d distinct)\n",
                                  $order->order_type_name,
                                  $order->date,
                                  $order->item_detail_count,
                                  $order->item_count));

    $self->status_message("Attributes:");
    my @attrs = $order->attributes();
    foreach my $attr ( @attrs ) {
        $self->status_message(sprintf("%s\t=> %s\n", $attr->name, $attr->value));
    }

    $self->status_message("Items:");
    my %items = map { $_->id => $_ } $order->items;
    foreach my $item ( values %items ) {
        $self->status_message(sprintf("\t(%2d)  %s\t%s\n",
                                      $item->count_for_order($order),
                                      $item->barcode,
                                      $item->desc));
    }
    return 1;
}

1;

