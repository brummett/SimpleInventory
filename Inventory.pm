package Inventory;

use warnings;
use strict;

use UR;

class Inventory {
    is => [ 'UR::Namespace' ],
    type_name => 'inventory',
};

# The current database schema version
sub db_schema_ver {
    return 3;
}

1;
