package Inventory::Command::View;

use strict;
use warnings;

use Inventory;

class Inventory::Command::View {
    is => 'Inventory::Command',
    is_abstract => 1,
    doc => 'View database entities',
};

1;

