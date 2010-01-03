package Inventory::Command::List;

use strict;
use warnings;

use Inventory;

class Inventory::Command::List {
    is => 'UR::Object::Command::List',
    is_abstract => 1,
    doc => 'List various kinds of objects in the inventory',
};

1;
