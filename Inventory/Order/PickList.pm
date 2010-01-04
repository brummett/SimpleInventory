package Inventory::Order::PickList;

use strict;
use warnings;

class Inventory::Order::PickList {
    is => 'Inventory::Order::Sale',
};

sub should_count_items {
    0;
}



1;
