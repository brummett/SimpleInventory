package Inventory::Command::ReceivePurchase;

use strict;
use warnings;

use Inventory;

class Inventory::Command::ReceivePurchase {
    is => 'Inventory::Command::ItemTransaction',
    doc => 'Record purchased items coming into inventory',
};

sub _order_type_to_create {
    return 'Inventory::Order::Purchase';
}

sub _count_for_order_item_detail {
    1;
}

1;
