package Inventory::Command::Remove;

use strict;
use warnings;

use Inventory;

class Inventory::Command::Remove {
    is => 'Inventory::Command',
    is_abstract => 1,
    doc => 'Remove database entities',
};

1;
