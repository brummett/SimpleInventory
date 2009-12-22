package Inventory::View::OrderItem;

use strict;
use warnings;

use Inventory;
class Inventory::View::OrderItem {
    type_name => 'order item view',
    table_name => 'ORDER_ITEMS',
    has => [
        count    => { is_optional => 1 },
        item_id  => { is => 'integer', is_optional => 1 },
        order_id => { is => 'integer', is_optional => 1 },
    ],
    schema_name => 'Inventory',
    data_source => 'Inventory::DataSource::Inventory',
};

1;
