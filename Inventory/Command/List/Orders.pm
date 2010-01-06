package Inventory::Command::List::Orders;

use strict;
use warnings;

use Inventory;

class Inventory::Command::List::Orders {
    is => 'Inventory::Command::List',
    has => [
        subject_class_name => { default_value => 'Inventory::Order' },
        show => { default_value => 'order_number,order_type_name,date,item_detail_count,item_count,source' },
    ],
};

1;
