package Inventory::OrderClass;

use strict;
use warnings;

use Inventory;
class Inventory::OrderClass {
    type_name => 'order class',
    table_name => 'ORDER_CLASS',
    er_role => 'validation item',
    id_by => [
        order_class_name => { is => 'varchar' },
    ],
    schema_name => 'Inventory',
    data_source => 'Inventory::DataSource::Inventory',
};

1;
