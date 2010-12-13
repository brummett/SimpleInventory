package Inventory;

use warnings;
use strict;

use UR v0.18;

class Inventory {
    is => [ 'UR::Namespace' ],
    type_name => 'inventory',
};

# The current database schema version
sub db_schema_ver {
    return 3;
}

1;
