package Inventory::Item;

use strict;
use warnings;

use Inventory;
class Inventory::Item {
    type_name => 'item',
    table_name => 'ITEM',
    id_by => [
        item_id => {  },
    ],
    has => [
        barcode => { is => 'varchar' },
        desc    => { is => 'varchar', is_optional => 1 },
        sku     => { is => 'varchar' },
    ],
    schema_name => 'Inventory',
    data_source => 'Inventory::DataSource::Inventory',
};

1;
