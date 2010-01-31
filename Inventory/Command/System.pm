package Inventory::Command::System;

use strict;
use warnings;

use Inventory;

class Inventory::Command::System {
    is => 'Inventory::Command',
    doc => 'System maintainence commands',
    is_abstract => 1,
};

1;
