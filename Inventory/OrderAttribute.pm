package Inventory::OrderAttribute;

use strict;
use warnings;

use Inventory;
class Inventory::OrderAttribute {
    type_name => 'order attribute',
    table_name => 'ORDER_ATTRIBUTES',
    id_by => [
        order_attribute_id => { is => 'integer' },
    ],
    has => [
        name     => { is => 'varchar' },
        order    => { is => 'Inventory::Order', id_by => 'order_id', constraint_name => 'ORDER_ATTRIBUTES_ORDER_ID_ORDERS_ORDER_ID_FK' },
        order_id => { is => 'integer' },
        value    => { is => 'varchar', is_optional => 1 },
    ],
    schema_name => 'Inventory',
    data_source => 'Inventory::DataSource::Inventory',
};

1;
