package Inventory::Order::Sale;

use Inventory;

class Inventory::Order::Sale {
    is => 'Inventory::Order',
};

sub add_item {
    my($self, $item) = @_;

    my $detail = $self->add_item_detail(item => $item, count => -1);
    return $detail;
}


1;
