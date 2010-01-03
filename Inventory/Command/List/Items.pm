package Inventory::Command::List::Items;

use strict;
use warnings;

use Inventory;

class Inventory::Command::List::Items {
    is => 'Inventory::Command::List',
    has => [
        subject_class_name => { default_value => 'Inventory::Item' },
        show => { default_value => 'barcode,sku,count,desc' },
    ],
    doc => 'List items in the inventory DB',
};

1;
