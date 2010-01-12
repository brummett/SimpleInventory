package Inventory::Command::Amazon;

use strict;
use warnings;

use Inventory;

class Inventory::Command::Amazon {
    is => 'Inventory::Command',
    is_abstract => 1,
    doc => 'Commands for interacting with an Amazon seller account',
};

1;
