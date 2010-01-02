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
}
    

# Instead of creating order details directly, we want to just record the
# cases where there's a difference between the previous count and the scanned
#  count
sub apply_barcodes_to_order {
    my($self, $order, $barcodes) = @_;

    my %count_for_barcode;
    foreach my $barcode ( @$barcodes ) {
        $count_for_barcode{$barcode}++;
    }

    my $correction_count = 0;
    my $iter = Inventory::Item->create_iterator();
    while(my $item = $iter->next()) {
        my $count = $item->count();
        my $scanned = $count_for_barcode{$item->barcode};
        if ($count != $scanned) {
            $correction_count++;
            my $correction = Inventory::OrderItemDetail->create(order_id => $order->id,
                                                                item_id  => $item->id,
                                                                count    => $scanned - $count);
            $self->warning_message(sprintf("%s barcode %s previous count %d scanned count %d correction %d",
                                   $item->desc,
                                   $item->barcode,
                                   $count, $scanned, $correction->count));
        }
    }

    $self->status_message("There are $correction_count inventory corrections");
    my $ans;
    while (1) {
        print "Apply these changes (Y or N)? " unless ($ENV{'INVENTORY_TEST'});
        chomp($ans = <STDIN>);
        $ans = uc($ans);
        last if ($ans eq 'Y' or $ans eq 'N');
    }
 
    if ($ans eq 'Y') {
        return 1;
    } else {
        $_->delete foreach $order->item_details();
        $order->delete();
        return 0;
    }
}
    

1;

