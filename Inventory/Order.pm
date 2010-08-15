package Inventory::Order;

use strict;
use warnings;

use Inventory;
my $now = scalar(localtime);
class Inventory::Order {
    type_name => 'order',
    table_name => 'ORDERS',
    subclassify_by => 'order_class',
    id_by => [
        order_id => { is => 'integer' },
    ],
    has => [
        date              => { is => 'datetime', default_value => $now },
        order_class       => { is => 'varchar', implied_by => 'order_class_obj' },
        order_class_obj   => { is => 'Inventory::OrderClass', id_by => 'order_class' },
        order_type_name   => { via => 'order_class_obj', to => 'name' },
        order_number      => { is => 'varchar' },
        item_details      => { is => 'Inventory::OrderItemDetail', reverse_as => 'order', is_many => 1 },
        items             => { is => 'Inventory::Item', via => 'item_details', to => 'item', is_many => 1 },
        item_detail_count => { is => 'Integer', is_calculated => 1 },
        item_count        => { is => 'Integer', is_calculated => 1 },
        source            => { is => 'varchar', is_optional => 1, 
                               doc => 'Where the order came from (Amazon, Web, etc)' },
        attributes        => { is => 'Inventory::OrderAttribute', reverse_as => 'order', is_many => 1 },
    ],
    unique_constraints => [
        { properties => [qw/order_class order_number/], sql => 'SQLITE_AUTOINDEX_ORDERS_1' },
    ],
    schema_name => 'Inventory',
    data_source => 'Inventory::DataSource::Inventory',
};


# when computing $item->count(), should this kind of order
# be included in the total.  Usually yes, but don't count pick lists or 
# purchase orders
sub should_count_items {
    1;
}


sub add_item {
    my $class = shift;
    $class = ref($class) if ref($class);
    die "Subclass $class did not implement add_item_by_barcode";
}

sub item_detail_count {
    my $self = shift;

    my @details = $self->item_details;
    return scalar(@details);
}

sub item_count {
    my $self = shift;

    my @item_ids = map { $_->item_id } $self->item_details;
    my @items = Inventory::Item->get(item_id => \@item_ids);
    return scalar(@items);
}

sub count_for_item {
    my($self, $item) = @_;
    
    my $count = 0;
    foreach my $detail ( Inventory::OrderItemDetail->get(order_id => $self->id, item_id => $item->id)) {
        $count += $detail->count;
    }

    return $count;
}

sub attr_value {
    my($self,$name) = @_;
    my $attr = Inventory::OrderAttribute->get(order_id => $self->order_id, name => $name);
    return unless $attr;
    return $attr->value;
}

1;
