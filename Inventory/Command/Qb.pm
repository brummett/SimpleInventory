package Inventory::Command::Qb;

use strict;
use warnings;

use Inventory;

class Inventory::Command::Qb {
    is => 'Inventory::Command',
    is_abstract => 1,
    doc => 'Commands related to interacting with QuickBooks',
};

1;

