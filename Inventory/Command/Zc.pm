package Inventory::Command::Zc;

use strict;
use warnings;

use Inventory;

class Inventory::Command::Zc {
    is => 'Inventory::Command',
    is_abstract => 1,
    doc => 'Commands for interacting with ZenCart online store software',
};

1;
