package Inventory::View::Inventory;

use strict;
use warnings;

use Inventory;
class Inventory::View::Inventory {
    type_name => 'inventory view',
    table_name => 'INVENTORY',
    has => [
        barcode  => { is => 'varchar', is_optional => 1 },
        count    => { is_optional => 1 },
        desc     => { is => 'varchar', is_optional => 1 },
        item_id  => { is => 'integer', is_optional => 1 },
        sku      => { is => 'varchar', is_optional => 1 },
    ],
    schema_name => 'Inventory',
    data_source => 'Inventory::DataSource::Inventory',
};

1;
