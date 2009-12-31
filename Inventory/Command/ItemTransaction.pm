package Inventory::Command::ItemTransaction;

use strict;
use warnings;

use Inventory;

use IO::Handle;

class Inventory::Command::ItemTransaction {
    is => 'Inventory::Command',
    doc => 'Parent class for commands like sale, purchase, expire, etc',
    is_abstract => 1,
    has_optional => [
        order_number => { is => 'String', doc => 'Order number to put this sale under' },
        append => { is => 'Boolean', doc => 'If true, this will add items to an existing transaction', },
        remove => { is => 'Boolean', doc => 'If true, this will remove items from an existing transaction' },
    ],
    has => [
        order => { is_calculated => 1,
                   calculate => q( my $order_number = $self->order_number;
                                   my $order = Inventory::Order->get(order_number => $order_number);
                                   return $order ),
                 },
    ],
};

# Subclasses can override this and then the system will pause for info
# about new items right after they're scanned instead of waiting until all
# the barcodes are done scanning
sub should_interrupt_for_new_barcodes {
    0;
}

# When an OrderItemDetail record is created, this is the count.
# For example, for a sale, this will be -1, for purchase +1
sub _count_for_order_item_detail {
    my $class = shift;
    $class = ref($class) || $class;
    die "Class $class didn't implement _count_for_order_item_detail";
}

sub add_item {
    my($self, $item) = @_;
    
    my $count = $self->_count_for_order_item_detail;
    #my $oid = Inventory::OrderItemDetail->create(item_id => $item->id, count => $count);
    my $oid = $self->order->add_item_detail(item_id => $item->id, count => $count);
    unless ($oid) {
        $self->error_message("Couldn't create item detail record for order ".$self->order_number);
        return;
    }
    return $oid;
}

sub remove_item {
    my($self, $item) = @_;

    my $order = $self->order;
    my @oids = Inventory::OrderItemDetail->get(order_id => $order->id, item_id => $item->id);
    unless (@oids) {
        $self->error_message("Order ".$self->order_number." has no items with barcode ".$item->barcode);
        return;
    }

    my $expected_count = $self->_count_for_order_item_detail();

    my @oids_with_count_1 = grep { $_->count == $expected_count } @oids;
    if (@oids_with_count_1) {
        my $oid = shift @oids_with_count_1;
        $oid->delete();
    } else {
        my $oid = shift @oids;
        $oid->count($oid->count - $expected_count);
    }

    return 1;
}
   

sub execute {
    my $self = shift;

    if ($self->append && $self->remove) {
        $self->error_message("--append and --remove can not be used together");
        return;
    }

    STDOUT->autoflush(1);

    my $order = $self->get_order_object();

    my @barcodes = $self->scan_barcodes_for_order($order);

    if (! $self->should_interrupt_for_new_barcodes ) {
        my @new_barcodes = grep { ! Inventory::Item->get( barcode => $_ ) } @barcodes;
        $self->prompt_for_info_on_barcode(barcode => $_) foreach @new_barcodes;
    }

    $self->apply_barcodes_to_order($order,\@barcodes);

    if(my @problem_items = $self->check_order_for_items_below_zero_count($order)) {
       $self->orders_report_on_items(\@problem_items);
    }

    return 1;
}
        

sub apply_barcodes_to_order {
    my($self,$order,$barcodes) = @_;

    my $apply_sub = $self->remove ? 'remove_item' : 'add_item';

    my %items;
    foreach my $barcode ( @$barcodes ) {
        my $item = Inventory::Item->get(barcode => $barcode);
        $items{$barcode} = $item;
        $self->$apply_sub($item);
    }

    return values %items;
}


sub check_order_for_items_below_zero_count {
    my($self,$order) = @_;

    my %all_item_ids = map { $_->id => 1 } $order->items();
    my @all_items = Inventory::Item->get(item_id => [ keys %all_item_ids ]);
    my @problem_items = grep { $_->count < 0 } @all_items;

    return @problem_items;
}

sub orders_report_on_items {
    my($self,$problem_items) = @_;

    foreach my $item ( @$problem_items ) {
        my $count = $item->count();
        $self->status_message("Item count below 0 ($count): ".$item->desc);
        $self->status_message($item->history_as_string());
    }
}

sub scan_barcodes_for_order {
    my($self,$order) = @_;

    my @barcodes;
    SCANNING_ITEMS:
    while(1) {
        print "Scan: ";
        my $barcode = STDIN->getline();
        last SCANNING_ITEMS unless $barcode;
        chomp $barcode if $barcode;
        $barcode =~ s/^\s+//;
        $barcode =~ s/\s+$//;
        last SCANNING_ITEMS unless $barcode;

        # Only check barcodes more than 4 chars...
        # less than 4 char barcode fields are used for special items and
        # are obviously not barcodes
        unless (Inventory::Util->verify_barcode_check_digit($barcode)) {
            $self->warning_message("Barcode did not scan properly");
            Inventory::Util->play_sound('error');
            next;
        }
        
        if ($self->should_interrupt_for_new_barcodes and ! Inventory::Item->get(barcode => $barcode) ) {
            $self->prompt_for_info_on_barcode($barcode);
        }
        push @barcodes, $barcode;
    }
    
    return @barcodes;
}

sub prompt_for_info_on_barcode {
    my($self,$barcode) = @_;

    my $item = Inventory::Item->get(barcode => $barcode);
    unless ($item) {
        my $cmd = Inventory::Command::CreateItem->create(barcode => $barcode);
        $item = $cmd->execute();
    }

    return $item;
}


sub resolve_order_number {
    my $self = shift;

    my $order_number = $self->order_number;
    unless (defined $order_number) {
        print "Order Number: ";
        $order_number = STDIN->getline();
        $order_number =~ s/^\s+//;
        $order_number =~ s/\s+$//;
        $self->order_number($order_number);
    }
    return $order_number;
}

    
sub get_order_object {
    my $self = shift;

    my $order_number = $self->resolve_order_number();

$DB::single=1;
    my $order_type = $self->_order_type_to_create();
    my $order = $order_type->get(order_number => $order_number);
    if ($self->append) {
        if ($order) {
            $self->status_message("*** Adding items to an existing order ***\n");
        } else {
            $self->error_message("No order found with that order number");
            return;
        }

    } elsif ($order) { # not append
        $self->error_message("An order already exists with that order number");
        return;
    
    } else {
        $order = $order_type->create(order_number => $order_number);
        unless ($order) {
            $self->error_message("Couldn't create Sales order record");
            return;
        }
    }

    return $order;
}


1;
