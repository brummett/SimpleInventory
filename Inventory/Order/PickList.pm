package Inventory::Order::PickList;

use strict;
use warnings;

class Inventory::Order::PickList {
    is => 'Inventory::Order',
};

sub should_count_items {
    0;
}

sub add_item {
    my($self, $item) = @_;

    my $detail = $self->add_item_detail(item => $item, count => -1);
    return  $detail;
}



1;
