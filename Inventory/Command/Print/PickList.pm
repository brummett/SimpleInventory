package Inventory::Command::Print::PickList;

use strict;
use warnings;

use Inventory;

use File::Temp;
use IO::File;

class Inventory::Command::Print::PickList {
    is => 'Inventory::Command::Print',
    has => [
        'print' => { is => 'Boolean', default_value => 1, doc => 'Use lpr to print the list after it is generated' },
        file    => { is => 'String', default_value => 'pick_list', doc => 'filename to save the list to' },
        type    => { is => 'String', default_value => 'pdf', valid_values => ['pdf','txt'], doc => 'What kind of output file to create' },
    ],
    doc => 'Generate a pick list based on all the PickList order records in the system',
};

sub execute {
    my $self = shift;

    my $output = $self->_create_output_handle();
    unless ($output) {
        $self->error_message("Can't create output file: $!");
        return;
    }
 
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

    $output->short_order_data($self->{'_short_orders'});

    if (@filled || @unfilled) {
        $output->header("Printed ".scalar(localtime()));
    }

    if (scalar(@filled)) {
        $output->header(scalar(@filled). " orders to fill:");
        $output->next_line;
        foreach my $order ( @filled ) {
            $output->print_order($order);
        }
    }


    if (scalar(@unfilled)) {
        $output->next_page();

        $output->header(scalar(@unfilled). " orders we can't fill:");
        $output->next_line;
        foreach my $order ( @unfilled ) {
            $output->print_order($order);
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


sub _create_output_handle {
    my $self = shift;

    my $filename = $self->file;
    my $output_type;
    if ($self->type eq 'txt') {
        $output_type = 'Inventory::Command::Print::PickList::Output::Text';
    } elsif ($self->type eq 'pdf') {
        $output_type = 'Inventory::Command::Print::PickList::Output::Pdf';
    } else {
        $self->error_message("Don't know how to create ".$self->type." type output files");
    }

    my $output = $output_type->create(filename => $filename);
    return $output;
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


# Some helper classes for output control

# FIXME - maybe move these to viewers of Orders at some point?

package Inventory::Command::Print::PickList::Output;
class Inventory::Command::Print::PickList::Output {
    is_abstract => 1,
    has => [
        filename => { is => 'String', doc => 'Filename to write the result to' },
        _handle  => { doc => 'Underlying object that handles the output, IO::Handle or PDF thingy' },
        short_order_data => { is => 'HASH' },
    ],
};

sub create {
    my $class = shift;

    my $self = $class->SUPER::create(@_);
    $self->_handle($self->_create_handle());

    return $self;
}

sub _create_handle {
    my $class = shift;
    $class = ref($class) if ref($class);

    Carp::croak("Class $class didn't implement _create_handle");
}


sub _is_item_short_for_order {
    my($self,$item,$order) = @_;

    my $short = $self->short_order_data;
    return unless $short;

    return $short->{$order->id}->{$item->id};
}



package Inventory::Command::Print::PickList::Output::Text;
class Inventory::Command::Print::PickList::Output::Text {
    is => 'Inventory::Command::Print::PickList::Output',
};

sub _create_handle {
    my $self = shift;

    my $filename = $self->filename;
    my $handle = IO::File->new($filename, 'w');
    unless ($handle) {
        Carp::croak("Can't open $filename for writing: $!");
    }
    return $handle;
}

sub header {
    my($self,$text) = @_;

    $self->_handle->print("\t\t\t$text\n");
}

sub next_line {
    my $self = shift;

    $self->_handle->print("\n");
}

sub print_order {
    my($self,$order) = @_;

    my $source = $order->source;
    my $order_number = $order->order_number;

    my %items = map { $_->id => $_ } $order->items;

    my $handle = $self->_handle;

    # Purchase dates look like 2010-01-01T12:12:00-08:00
    # Remove everything after and including the 'T'
    my $purchase_date = $order->attr_value('purchase_date');
    $purchase_date =~ s/T.*$//;

    $handle->printf("%s order number %s on %s\n", $source, $order_number, $purchase_date);
    $handle->printf("%-30s box number:            weight:      lb       oz   box desc:\n",$order->attr_value('recipient_name'));
    $handle->printf("%-30s\n", $order->attr_value('ship_address_1'));
    $handle->printf("%-30s phone: %s  Invoice num:\n", $order->attr_value('ship_address_2'), $order->attr_value('ship_phone'));
    $handle->printf("%-30s\n", $order->attr_value('ship_address_3')) if ($order->attr_value('ship_address_3'));

    $handle->printf("%s, %s %s %s\n",
                        $order->attr_value('ship_city'),
                        $order->attr_value('ship_state'),
                        $order->attr_value('ship_zip'),
                        $order->attr_value('ship_country'),
                      );

    my $items_count = 0;
    $items_count += $_->count foreach $order->item_details;
    $handle->print(abs($items_count) . " total items:\n");

    my $shipping_total = 0;
    my $money_total = 0;
    my @items_strings;
    foreach my $item ( values %items ) {
        my $location = $item->attr_value('location','warehouse');
        # We need the detail record to get some of its attributes.
        # they should all have the same attributes stored, so just get the first one
        my $item_detail = ( Inventory::OrderItemDetail->get(order_id => $order->id,
                                                            item_id  => $item->id))[0];

        my $item_price =  $item_detail->attr_value('item_price');
        $handle->printf("\t(%3s) %3s %-10s \$%-6.2f         %-50s %s\n",
                        abs($order->count_for_item($item)),
                        $self->_is_item_short_for_order($item,$order) ? 'OUT' : '',
                        $item->sku,
                        $item_price,
                        $item->desc,
                        $location || '',
                      );
        $shipping_total += $item_detail->attr_value('shipping_price');
        $money_total += $item_price;
    }
    $money_total += $shipping_total;


    my $ship_service = $order->attr_value('ship_service_level');
    $ship_service = uc($ship_service) if (lc($ship_service) eq 'expedited');
    $handle->printf(" " x 30 . "%s shipping \$%-6.2f" . " " x 20 . "Total \$%-6.2f\n",
                        $ship_service, $shipping_total, $money_total);

    $handle->print("\n". '-' x 80, "\n");
}
        

sub next_page {
    my $self = shift;
    $self->_handle->print("\n" . '-' x 80 . "\n");
}

sub close {
    my $self = shift;
    $self->_handle->close();
}


package Inventory::Command::Print::PickList::Output::Pdf;
class Inventory::Command::Print::PickList::Output::Pdf {
    is => 'Inventory::Command::Print::PickList::Output',
};

sub _create_handle {
    my $self = shift;

    eval "use PDF::API2::Simple;";
    if ($@) {
        Carp::croak("Couldn't load PDF::API2::Simple: $@");
    }
    eval "use GD::Barcode;";
    if ($@) {
        Carp::croak("Couldn't load GD::Barcode: $@");
    }
    eval "use PDF::Reuse";
    if ($@) {
        Carp::croak("Couldn't load PDF::Reuse: $@");
    }


    eval "use PDF::Reuse::Barcode";
    if ($@) {
        Carp::croak("Couldn't load PDF::Reuse::Barcode: $@");
    }



    my $handle = PDF::API2::Simple->new(file => $self->filename);

    $handle->add_font('Arial');
    $handle->add_page();


    return $handle;
}

sub header {
    my($self, $text) = @_;

    my $handle = $self->_handle;
    $handle->text($text);
    $handle->next_line;
}

sub next_line {
    my $self = shift;
    $self->_handle->next_line();
}

sub print_order {
    my($self,$order) = @_;

    my $source = $order->source;
    my $order_number = $order->order_number;

    my %items = map { $_->id => $_ } $order->items;

    my $handle = $self->_handle;
    my $lines_needed = 11 + scalar(keys %items);  # Each order record needs 11 lines, plus one line for each item
    my $lines_left = int(($handle->y - $handle->margin_bottom) / $handle->line_height);
    if ($lines_left <= $lines_needed) {
        $handle->add_page();
    }

    my($bar_fh,$barcode_file) = File::Temp::tempfile(SUFFIX => '.pdf');
    $bar_fh->close;
    prFile($barcode_file);
    PDF::Reuse::Barcode::Code39(x => 1, y => 1, value => '*'.$order_number.'*', hide_asterisk => 1);
    prEnd();

    # Purchase dates look like 2010-01-01T12:12:00-08:00
    # Remove everything after and including the 'T'
    my $purchase_date = $order->attr_value('purchase_date');
    $purchase_date =~ s/T.*$//;

    #$handle->text(sprintf("%s order number %s on %s", $source, $order_number, $purchase_date));
    $handle->next_line();
    my ($new_x);
    (undef,undef,$new_x, undef) = $handle->text("$source order on $purchase_date  Order number: ");
    
    $handle->next_line();
    $handle->image($barcode_file, x => $new_x + 15, height => $handle->line_height);
    $handle->x($handle->margin_left);
    $handle->next_line();

    $handle->text($order->attr_value('recipient_name'));
    $handle->text("box number:            weight:      lb       oz   box desc:", x=> 200);
    $handle->next_line();
    $handle->text($order->attr_value('ship_address_1'));
    $handle->next_line();
    $handle->text($order->attr_value('ship_address_2'));
    my $phone = $order->attr_value('ship_phone');
    $handle->text("phone: $phone  Invoice num:", x => 200);
    $handle->next_line();
    $handle->text(sprintf("%-30s", $order->attr_value('ship_address_3'))) if ($order->attr_value('ship_address_3'));
    $handle->next_line();

    $handle->text(sprintf("%s, %s %s %s",
                        $order->attr_value('ship_city'),
                        $order->attr_value('ship_state'),
                        $order->attr_value('ship_zip'),
                        $order->attr_value('ship_country'),
                      ));
    $handle->next_line();

    my $items_count = 0;
    $items_count += $_->count foreach $order->item_details;
    $handle->text(abs($items_count) . " total items:");
    $handle->next_line();

    # All the line items....
    my $shipping_total = 0;
    my $money_total = 0;
    foreach my $item ( values %items ) {
        my $location = $item->attr_value('location','warehouse');
        # We need the detail record to get some of its attributes.
        # they should all have the same attributes stored, so just get the first one
        my $item_detail = ( Inventory::OrderItemDetail->get(order_id => $order->id,
                                                            item_id  => $item->id))[0];

        my $item_price =  $item_detail->attr_value('item_price');
        $handle->text(
             sprintf("\t(%3s) %3s %-10s \$%-6.2f         %-50s %s",
                     abs($order->count_for_item($item)),
                     $self->_is_item_short_for_order($item,$order) ? 'OUT' : '',
                     $item->sku,
                     $item_price,
                     $item->desc,
                     $location || '',
                   ));
        $handle->next_line();
        $shipping_total += $item_detail->attr_value('shipping_price');
        $money_total += $item_price;
    }
    $money_total += $shipping_total;


    my $ship_service = $order->attr_value('ship_service_level');
    my $is_expedited = lc($ship_service) eq 'expedited';
    $ship_service = uc($ship_service) if ($is_expedited);
    (undef,undef,$new_x, undef) = $handle->text("$ship_service shipping", x => 150);
    $handle->text("$ship_service shipping", x => 150) if ($is_expedited);  # Make it bold

    $handle->text(sprintf(" \$%-6.2f" . " " x 20 . "Total \$%-6.2f",
                        $shipping_total, $money_total),
                  x => $new_x);
    $handle->next_line();

    # I'm not sure why line() doesn't actually draw a line here...
    $handle->rect(to_x => $handle->width_right,
                  to_y => $handle->y+1,
                  stroke => 'true',
                  fill => 'true',
                  stoke_color => 'black',
                  fill_color => 'black');
    $handle->x($handle->margin_left);

    $handle->next_line;
    $handle->next_line;
}


sub next_page {
    my $self = shift;

    $self->_handle->add_page();
}

sub close {
    my $self = shift;

    $self->_handle->save()
}
1;
