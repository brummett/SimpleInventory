package Inventory::Command::List::Settings;

use strict;
use warnings;

use Inventory;

class Inventory::Command::List::Settings {
    is => 'Inventory::Command::List',
    has => [
        subject_class_name => { default_value => 'Inventory::Setting' },
        show => { default_value => 'name,value' },
    ],
};

1;
