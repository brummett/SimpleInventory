package Inventory::Order;

use strict;
use warnings;

use Inventory;
class Inventory::Order {
    type_name => 'order',
    table_name => 'ORDERS',
    id_by => [
        order_id => { is => 'integer' },
    ],
    has => [
        date          => { is => 'datetime', is_optional => 1 },
        order_number  => { is => 'varchar' },
        order_type    => { is => 'Inventory::OrderType', id_by => 'order_type_id', constraint_name => 'ORDERS_ORDER_TYPE_ID_ORDER_TYPE_ORDER_TYPE_ID_FK' },
        order_type_id => { is => 'integer' },
    ],
    schema_name => 'Inventory',
    data_source => 'Inventory::DataSource::Inventory',
};

1;
