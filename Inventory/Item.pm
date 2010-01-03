package Inventory::Item;

use strict;
use warnings;

use Inventory;
class Inventory::Item {
    type_name => 'item',
    table_name => 'ITEM',
    id_by => [
        item_id => { is => 'integer' },
    ],
    has => [
        barcode => { is => 'varchar' },
        desc    => { is => 'varchar', is_optional => 1 },
        sku     => { is => 'varchar' },
        count   => { is => 'Number', is_calculated => 1 },

        order_item_details => { is => 'Inventory::OrderItemDetail', reverse_as => 'item', is_many => 1 },
        orders             => { is => 'Inventory::Order', via => 'order_item_details', to => 'order', is_many => 1 },
    ],
    schema_name => 'Inventory',
    data_source => 'Inventory::DataSource::Inventory',
};


sub count {
    my $self = shift;

    my @details = $self->order_item_details;
    my $sum = 0;
    $sum += $_->count foreach @details;

    return $sum;
}

sub count_for_order {
    my($self, $order) = @_;

    my @details = Inventory::OrderItemDetail->get(item_id => $self->item_id, order_id => $order->order_id);
    my $count = 0;
    $count += $_->count foreach @details;
    return $count;
}

sub history_as_string {
    my $self = shift;

    my @strings;

    my %orders = map { $_ => $_ } $self->orders;
    foreach my $order ( sort { $a->id <=> $b->id } values %orders ) {
        my $kind = ucfirst( $order->order_type_name );
        my $count = $self->count_for_order($order);
        push @strings, sprintf("%s order on %s:\t%d", $kind, $order->date, $count);
    }

    return join("\n", @strings);
}


1;
