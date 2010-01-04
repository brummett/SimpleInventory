package Inventory::Order::PurchaseOrder;

use Inventory;

class Inventory::Order::PurchaseOrder {
    is => 'Inventory::Order',
};

sub should_count_items {
    0;
}

1;
