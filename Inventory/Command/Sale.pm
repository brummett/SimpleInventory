package Inventory::Command::Sale;

use strict;
use warnings;

use Inventory;

class Inventory::Command::Sale {
    is => 'Inventory::Command::ItemTransaction',
    doc => 'Record a sales transaction',
};

sub _order_type_to_create {
    return 'Inventory::Order::Sale';
}

sub _count_for_order_item_detail {
    -1;
}

1;
