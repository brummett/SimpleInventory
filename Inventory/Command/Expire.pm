package Inventory::Command::Expire;

use strict;
use warnings;

use Inventory;

class Inventory::Command::Expire {
    is => 'Inventory::Command::ItemTransaction',
    doc => 'Remove expired items from inventory',
};

sub _order_type_to_create {
    return 'Inventory::Order::Expiration';
}

sub _count_for_order_item_detail {
    -1;
}

1;
