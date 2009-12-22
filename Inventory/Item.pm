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
        count   => { is_calculated => 1 },

        order_item_details => { is => 'Inventory::OrderItemDetail', reverse_as => 'item', is_many => 1 },
    ],
    schema_name => 'Inventory',
    data_source => 'Inventory::DataSource::Inventory',
};


sub count {
    my $self = shift;

    my @details = Inventory::OrderItemDetail->get(item_id => $self);
    my $sum = 0;
    $sum += $_->count foreach @details;

    return $sum;
}


1;
