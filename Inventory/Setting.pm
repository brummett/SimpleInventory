package Inventory::Setting;

use strict;
use warnings;

use Inventory;
class Inventory::Setting {
    type_name => 'setting',
    table_name => 'SETTINGS',
    id_by => [
        setting_id => { is => 'integer' },
    ],
    has => [
        name  => { is => 'varchar' },
        value => { is => 'varchar', is_optional => 1 },
    ],
    schema_name => 'Inventory',
    data_source => 'Inventory::DataSource::Inventory',
};

1;
