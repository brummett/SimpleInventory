package Inventory::Command::ConfirmShipping;

use strict;
use warnings;

use Inventory;

use IO::File;
use POSIX;

class Inventory::Command::ConfirmShipping {
    is => 'Inventory::Command',
    has => [
        amazon_file => { is => 'String', default_value => 'amazon_confirm_upload.csv', doc => 'file to hold amazon upload info' },
    ],
    has_optional => [ 
        order_number => { is => 'ARRAY' },
        _prompt_for_order_number => { is => 'Boolean' },
        tracking_number => { is => 'ARRAY' },
        _prompt_for_tracking_number => { is => 'Boolean' },
    ],
    doc => 'Used to associate tracking numbers with orders',
};

sub execute {
    my $self = shift;

    my $order_numbers = $self->order_number;
    if (defined $order_numbers and scalar(@$order_numbers)) {
        $self->_prompt_for_order_number(0);
    } else {
        $self->_prompt_for_order_number(1);
    }

    my $tracking_numbers = $self->tracking_number;
    if (defined $tracking_numbers and scalar(@$tracking_numbers)) {
        $self->_prompt_for_tracking_number(0);
    } else {
        $self->_prompt_for_tracking_number(1);
    }

    while (my $order_number = $self->_get_next_from('order_number')) {
        my $order = Inventory::Order::Sale->get(order_number => $order_number);
        unless ($order) {
            $self->error_message("There is no sale order with that order number");
            next;
        }

        if ($order->confirmed) {
            $self->error_message("That order has already been confirmed");
            next;
        }
 
        my $tracking_number = $self->_get_next_from('tracking_number');
        unless ($tracking_number and length($tracking_number)) {
            $self->status_message('Skipping that order');
            next;
        }

        print "Shipping carrier [USPS]: " unless ($ENV{'INVENTORY_TEST'});
        my $carrier_code = <STDIN>;
        chomp $carrier_code;
        $carrier_code ||= 'USPS';
 
        print "Shipping method [priority]: " unless ($ENV{'INVENTORY_TEST'});
        my $ship_method = <STDIN>;
        chomp $ship_method;
        $ship_method ||= 'priority';

        $order->add_attribute(name => 'tracking_number', value => $tracking_number);
        $order->add_attribute(name => 'carrier_code', value => $carrier_code);
        $order->add_attribute(name => 'ship_method', value => $ship_method);
        my $ship_date = POSIX::strftime("%F", localtime());  # yyyy-mm-dd
        $order->add_attribute(name => 'ship_date', value => $ship_date);

        if ($order->source and $order->source eq 'amazon') {
            $self->_add_order_to_amazon_file($order, $ship_date, $carrier_code, $tracking_number, $ship_method);
        }
        $order->add_attribute(name => 'confirmed', value => 1);
    }

    my @unconfirmed = Inventory::Order::Sale->get('confirmed false' => 1);
    if (@unconfirmed) {
        $self->status_message("There are still ".scalar(@unconfirmed)." unconfirmed shipments:");
        foreach my $order (@unconfirmed) {
            $self->status_message("\t".$order->order_number);
        }
    }

    $self->status_message("Saving changes");
    my $fh = $self->_amazon_fh();
    $fh->close if $fh;
    return 1;
}


sub _add_order_to_amazon_file {
    my($self, $order, $ship_date, $carrier_code, $tracking_number, $ship_method) = @_;

    my $order_number = $order->order_number;
    #my $ship_date = $order->attr_value('ship_date');
    #my $carrier_code = $order->attr_value('carrier_code');
    my $carrier_name = '';   # always the empty string in our system?    # $order->attr_value('carrier_name') || '';
    #my $tracking_number = $order->attr_value('tracking_number');
    #my $ship_method = $order->attr_value('ship_method');

    unless ($order_number and $ship_date and $carrier_code and $tracking_number and $ship_method)  {
        $self->error_message("Can't save amazon order result, missing info");
        $self->error_message("order number $order_number ship date $ship_date carrier code $carrier_code tracking number $tracking_number ship method $ship_method");
        return;
    }

    # Map the item id to the count and amazon's order-item-id
    my %item_detail_count;
    my %amz_order_item_ids;
    foreach my $detail ( $order->item_details ) {
        my $item_id = $detail->item_id;
        $item_detail_count{$item_id} ||= 0;
        $item_detail_count{$item_id} += abs($detail->count);

        $amz_order_item_ids{$item_id} ||= $detail->attr_value('order_item_id');
    }

    my $fh = $self->_amazon_fh();

    my %items = map { $_->id => $_ } $order->items;
    foreach my $item_id ( keys %items ) {
        next unless $amz_order_item_ids{$item_id};  # Don't add unless that item had an amazon item ID
        my $line = join("\t",
                        $order_number,
                        $amz_order_item_ids{$item_id},
                        $item_detail_count{$item_id},
                        $ship_date,
                        $carrier_code,
                        $carrier_name || '',
                        $tracking_number,
                        $ship_method,
                      );
        $fh->print("$line\n");
    }

    return 1;
}


sub _amazon_fh {
    my($self) = @_;

    unless ($self->{'_amazon_fh'}) {
        $self->{'_amazon_fh'} = IO::File->new($self->amazon_file, 'w');
        $self->{'_amazon_fh'}->print("order-id\torder-item-id\tquantity\tship-date\tcarrier-code\tcarrier-name\ttracking-number\tship-method\n");
    }

    return $self->{'_amazon_fh'};
}
       


sub _get_next_from {
    my($self,$source) = @_;

    my $list = $self->$source;
    if ($list) {
        my $next = shift @$list;
        return $next if defined $next;
    }

    my $should_prompt = '_prompt_for_'.$source;
    return unless $self->$should_prompt;

    STDOUT->autoflush(1);
    $source =~ s/_/ /;  # Get rid of the underscore for prompting the user
    print "Next $source: " unless ($ENV{'INVENTORY_TEST'});
    my $next = <STDIN>;
    chomp $next if $next;

    return $next;
}


 
