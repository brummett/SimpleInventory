package Inventory::Command::ItemHistory;

use strict;
use warnings;

use Inventory;

class Inventory::Command::ItemHistory {
    is => 'Inventory::Command',
    has_optional => [
        items    => { is => 'ARRAY' },
        item_ids => { is => 'ARRAY' },
        barcodes => { is => 'ARRAY' },
        skus     => { is => 'ARRAY' },
    ],
    doc => 'Show the order history for an item',
};

# FXIME turn this into a viewer...
sub execute {
    my $self = shift;

    my @item_ids = $self->item_ids();
    my @items = Inventory::Item->get(item_id => \@item_ids);

    my @barcodes = $self->barcodes();
    push @items, Inventory::Item->get(barcode => \@barcodes);

    my @skus = $self->skus();
    push @items, Inventory::Item->get(sku => \@skus);

    foreach my $item ( @items ) {
        $self->status_message($item->history_as_string);
    }
    return 1;
}

1;
