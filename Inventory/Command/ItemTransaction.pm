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
        my @some = Inventory::OrderItemDetail::Ghost->get(order_id => $order->id, item_id => $item->id);
        if (@some) {
            $self->error_message("Tried to remove too many " . $item->desc . " from order ".$self->order_number);
        } else {
            $self->error_message("Order ".$self->order_number." has no item with barcode ".$item->barcode);
        }
        Carp::croak "Exiting without saving";
    }

    my $expected_count = $self->_count_for_order_item_detail();

    my @oids_with_count_1 = grep { $_->count == $expected_count } @oids;
    if (@oids_with_count_1) {
        my $oid = shift @oids_with_count_1;
        foreach my $attr ( $oid->attributes ) {
            $oid->remove_attribute($attr);
        }
        $oid->delete();
    } else {
        my $oid = shift @oids;
        $oid->count($oid->count - $expected_count);
        if ($oid->count < 0) {
            Carp::croak(sprintf("Order %s cannot remove barcode %s: Count dropped below 0",
                                $self->order_number,
                                $item->barcode));
        }
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
    unless ($order) {
        $self->error_message("Could not create order record for this transaction.  Exiting...");
        return;
    }

    my @barcodes = $self->scan_barcodes_for_order($order);

    if (! $self->should_interrupt_for_new_barcodes ) {
        my %new_barcodes = map { $_ => 1 }
                           grep { ! Inventory::Item->get( barcode => $_ ) } @barcodes;
        $self->prompt_for_info_on_barcode($_) foreach sort keys(%new_barcodes);
    }

    unless ($self->apply_barcodes_to_order($order,\@barcodes)) {
        return 0;
    }

    if (my @problem_items = $self->check_order_for_items_below_zero_count($order)) {
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
        unless ($item) {
            Carp::croak("Couldn't apply barcode $barcode to order " .
                        $self->order_number . ": Item not found");
        }
        $items{$barcode} = $item;
        $self->$apply_sub($item);
    }

    if (wantarray) {
        return values %items;
    } else {
        my $count = scalar(values %items) || '0 but true';
        return $count;
    }
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
        $self->warning_message("Item count below 0 ($count): ". $item->desc .
                               "\n" . $item->history_as_string);
    }
}

sub get_barcode_from_user {
    my($self) = @_;

    # FIXME - the input barcode should probably be a property
    my $barcode = STDIN->getline();
    chomp $barcode if ($barcode and length($barcode));
    return () unless (defined $barcode and length $barcode);
    return $barcode;
}

sub scan_barcodes_for_order {
    my($self,$order) = @_;

    my @scanned_barcodes;
    SCANNING_ITEMS:
    while(1) {
        print "Scan: " unless ($ENV{'INVENTORY_TEST'});
        my @barcode = $self->get_barcode_from_user;
        last SCANNING_ITEMS unless @barcode;

        foreach my $barcode ( @barcode ) {
            $barcode =~ s/^\s+//;
            $barcode =~ s/\s+$//;
            # +++ is used in test cases to emulate the user hitting ^D
            last SCANNING_ITEMS if( ! $barcode or $barcode eq '+++');

            # Only check barcodes more than 4 chars...
            # less than 4 char barcode fields are used for special items and
            # are obviously not barcodes
            unless (Inventory::Util->verify_barcode_check_digit($barcode)) {
                $self->warning_message("Barcode did not scan properly, input line $.");
                Inventory::Util->play_sound('error');
                next;
            }
        
            my $item = Inventory::Item->get(barcode => $barcode);
            if ($item) { 
                $self->status_message($item->desc);
            } elsif ($self->should_interrupt_for_new_barcodes) {
                $self->prompt_for_info_on_barcode($barcode);
            } else {
                $self->warning_message("unknown item on line $., will prompt later for details");
            }
            push @scanned_barcodes, $barcode;
        }
    }
    
    return @scanned_barcodes;
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
        print "Order Number: " unless ($ENV{'INVENTORY_TEST'});
        $order_number = STDIN->getline();
        $order_number =~ s/^\s+//;
        $order_number =~ s/\s+$//;
        $order_number = uc($order_number);
        $self->order_number($order_number);
    }
    return $order_number;
}

our @order_sources = (
        [ qr/^amz/ => 'amazon' ],
        [ qr/^web/ => 'web' ],
        [ qr/^ebay/ => 'ebay' ],
        [ qr/^iof/ => 'ioffer' ],
    );
sub get_order_object {
    my $self = shift;

    my $order_number = $self->resolve_order_number();

    my $order_type = $self->_order_type_to_create();
    my $order = $order_type->get(order_number => $order_number);
    if ($self->append || $self->remove) {
        if ($order) {
            my $action = $self->append ? 'Adding' : 'Removing';
            $self->status_message("*** $action items to an existing $order_type ***\n");
        } else {
            $self->error_message("No $order_type found with that order number");
            return;
        }

    } elsif ($order) { # not append
        $self->error_message("A(n) $order_type already exists with that order number");
        return;
    
    } else {
        my $source;
        foreach my $src ( @order_sources ) {
            my $match = $src->[0];
            if ($src =~ $match) {
                $source = $src->[1];
                last;
            }
        }

        $order = $order_type->create(order_number => $order_number, source => $source);
        unless ($order) {
            $self->error_message("Couldn't create a(n) $order_type record");
            return;
        }
        $self->status_message("Starting a new $order_type");
    }

    return $order;
}


1;
