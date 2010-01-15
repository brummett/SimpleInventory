package Inventory::Command::Print::PickList;

use strict;
use warnings;

use Inventory;

use IO::File;

class Inventory::Command::Print::PickList {
    is => 'Inventory::Command::Print',
    has => [
        'print' => { is => 'Boolean', default_value => 1, doc => 'Use lpr to print the list after it is generated' },
        file    => { is => 'String', default_value => 'pick_list.txt', doc => 'filename to save the list to' },
        _fh     => { is => 'IO::Handle', is_optional => 1, doc => 'handle for the output file' },
    ],
    doc => 'Generate a pick list based on all the PickList order records in the system',
};

sub execute {
    my $self = shift;

    my $output = IO::File->new($self->file, 'w');
    unless ($output) {
        $self->error_message("Can't open ".$self->file." for writing: $!");
        return;
    }
    $self->_fh($output);
 
    my @orders = Inventory::Order::PickList->get();
    $self->status_message("Generating a list for ".scalar(@orders). " orders");

    my %orders = ( standard => [], expedited => [] );
    foreach my $order ( @orders ) {
        if (my $attr = Inventory::OrderAttribute->get(order_id => $order->id, name => 'ship_service_level')) {
            my $level = lc($attr->value);
            $orders{$level} ||= [];
            push @{$orders{$level}}, $order;
        } else {
            push @{$orders{'standard'}}, $order;
        }
    }

    my $expedited_orders = delete $orders{'expedited'};
    my $standard_orders = delete $orders{'standard'};

    my(@filled, @unfilled);
    foreach my $order ( @$expedited_orders ) {
        my $is_filled = $self->can_fill_order($order);
        if ($is_filled) {
            push @filled, $order;
        } else {
            push @unfilled, $order;
        }
    }

    foreach my $key ( keys %orders ) {
        foreach my $order (@{$orders{$key}}) {
            my $is_filled = $self->can_fill_order($order);
            if ($is_filled) {
                push @filled, $order;
            } else {
                push @unfilled, $order;
            }
        }
    }

    foreach my $order ( @$standard_orders ) {
        my $is_filled = $self->can_fill_order($order);
        if ($is_filled) {
            push @filled, $order;
        } else {
            push @unfilled, $order;
        }
    }

    if (scalar(@filled)) {
        $output->print(scalar(@filled), " orders to fill:\n\n");
        foreach my $order ( @filled ) {
            $self->print_order($order);
        }
        $output->print("\n");
    }

    if (scalar(@unfilled)) {
        $output->print("\n" . '-' x 80 . "\n");

        $output->print("\cL\n", scalar(@unfilled), " orders we can't fill:\n\n");
        foreach my $order ( @unfilled ) {
            $self->print_order($order);
        }
    }

    $output->close();

    if ($self->print) {
        my $file = $self->file;
        if (-f $file && -s $file) {
            `lpr $file`;
        } else {
            $self->warning_message("Pick list file $file does not exist or has 0 size, not printing");
        }
    }
    
    return 1;
}


# Return true if there are enough remaining in inventory to fill all the
# items in an order.  If yes, then provisionally decrement the internal count
sub can_fill_order {
    my($self,$order) = @_;

    my $worked = 1;

    my %adjustments;
    my %items = map { $_->id => $_ } $order->items;
    foreach my $item ( values %items ) {
        unless (exists $self->{'_count_for_item'}->{$item->id}) {
            $self->{'_count_for_item'}->{$item->id} = $item->count;
        }

        my $adjustment = $order->count_for_item($item);
        if ($self->{'_count_for_item'}->{$item->id} + $adjustment < 0) {
            $worked = 0;
            $self->{'_short_orders'}->{$order->id}->{$item->id} = 1;
        }

        $adjustments{$item->id} ||= 0;
        $adjustments{$item->id} += $adjustment;
    }

    return 0 unless ($worked);

    # If we got this far, then all the counts were sufficient
    foreach my $item_id ( keys %adjustments ) {
        $self->{'_count_for_item'}->{$item_id} += $adjustments{$item_id};
    }

    return 1;
}

sub _is_item_short_for_order {
    my($self,$item,$order) = @_;

    return $self->{'_short_orders'}->{$order->id}->{$item->id};
}
        


sub print_order {
    my($self,$order) = @_;

    my $fh = $self->_fh;

    my $source = $order->source;
    my $order_number = $order->order_number;
    my @details = $order->item_details;

    my $items_count = 0;
    $items_count += $_->count foreach @details;

    my %items = map { $_->id => $_ } $order->items;

    my $shipping_total = 0;
    my $items_string = '';
    foreach my $item ( values %items ) {
        my $location = $item->attr_value('location','warehouse');
        # We need the detail record to get some of its attributes.
        # they should all have the same attributes stored, so just get the first one
        my $item_detail = ( Inventory::OrderItemDetail->get(order_id => $order->id,
                                                            item_id  => $item->id))[0];

        $items_string .= sprintf("\t(%3s) %3s %-10s \$%-6.2f\t %-50s %s\n",
                                abs($order->count_for_item($item)),
                                $self->_is_item_short_for_order($item,$order) ? 'OUT' : '',
                                $item->sku,
                                $item_detail->attr_value('item_price'),  # * count???
                                $item->desc,
                                $location || '',
                              );
        $shipping_total += $item_detail->attr_value('shipping_price');
    }


    my $ship_service = $order->attr_value('ship_service_level');
    $ship_service = uc($ship_service) if (lc($ship_service) eq 'expedited');
    $fh->printf("%s order number %s on %s   %s shipping \$%-6.2f\n",
                $source, $order_number, $order->attr_value('purchase_date'), $ship_service);
    $fh->printf("%-30s box number:            weight:          lb         oz\n",$order->attr_value('recipient_name'));
    $fh->printf("%-30s\n", $order->attr_value('ship_address_1'));
    $fh->printf("%-30s phone: %s  Invoice num:\n", $order->attr_value('ship_address_2'), $order->attr_value('ship_phone'));
    $fh->printf("%-30s\n", $order->attr_value('ship_address_3')) if ($order->attr_value('ship_address_3'));

    $fh->printf("%s, %s %s %s\n",
                $order->attr_value('ship_city'),
                $order->attr_value('ship_state'),
                $order->attr_value('ship_zip'),
                $order->attr_value('ship_country'),
              );

    $fh->print(abs($items_count), " total items:\n");

    $fh->print($items_string);
    $fh->printf("\n%s shipping \$%-6.2f\n", $ship_service, $shipping_total);

    $fh->print("\n" . '-' x 80 . "\n");

    return 1;
}


1;
