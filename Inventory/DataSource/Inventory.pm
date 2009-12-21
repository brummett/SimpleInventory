package Inventory::DataSource::Inventory;

use strict;
use warnings;

use Inventory;

class Inventory::DataSource::Inventory {
    is => [ 'UR::DataSource::SQLite', 'UR::Singleton' ],
};

sub server { '/Users/abrummet/git/inventory2/Inventory/DataSource/Inventory.sqlite3' }

1;
