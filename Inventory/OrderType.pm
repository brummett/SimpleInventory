package Inventory::OrderType;

use strict;
use warnings;

use Inventory;
class Inventory::OrderType {
    type_name => 'order type',
    table_name => 'ORDER_TYPE',
    id_by => [
        order_type_id => { is => 'integer' },
    ],
    has => [
        name => { is => 'varchar' },
    ],
    schema_name => 'Inventory',
    data_source => 'Inventory::DataSource::Inventory',
};

1;
