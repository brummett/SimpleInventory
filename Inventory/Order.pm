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
        date                    => { is => 'datetime', is_optional => 1 },
        order_class             => { is => 'varchar' },
        order_class_order_class => { is => 'Inventory::OrderClass', id_by => 'order_class', constraint_name => 'ORDERS_ORDER_CLASS_ORDER_CLASS_ORDER_CLASS_NAME_FK' },
        order_number            => { is => 'varchar' },
    ],
    schema_name => 'Inventory',
    data_source => 'Inventory::DataSource::Inventory',
};

1;
