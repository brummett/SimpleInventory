package Inventory::Order::Sale;

use Inventory;

class Inventory::Order::Sale {
    is => 'Inventory::Order',
    has_optional => [
        confirmed       => { is => 'Boolean', via => 'attributes', to => 'value', where => [name => 'confirmed'] },
    ],
    has_many_optional => [
        tracking_number => { is => 'String', via => 'attributes', to => 'value', where => [name => 'tracking_number'] },
    ],
};

sub add_item {
    my($self, $item) = @_;

    my $detail = $self->add_item_detail(item => $item, count => -1);
    return $detail;
}


1;
