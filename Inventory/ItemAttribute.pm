package Inventory::ItemAttribute;

use strict;
use warnings;

use Inventory;
class Inventory::ItemAttribute {
    type_name => 'item attribute',
    table_name => 'ITEM_ATTRIBUTE',
    id_by => [
        item_attribute_id => { is => 'integer' },
    ],
    has => [
        application => { is => 'varchar' },
        item        => { is => 'Inventory::Item', id_by => 'item_id', constraint_name => 'ITEM_ATTRIBUTE_ITEM_ID_ITEM_ITEM_ID_FK' },
        item_id     => { is => 'integer' },
        name        => { is => 'varchar' },
        value       => { is => 'varchar', is_optional => 1 },
    ],
    schema_name => 'Inventory',
    data_source => 'Inventory::DataSource::Inventory',
};

1;
