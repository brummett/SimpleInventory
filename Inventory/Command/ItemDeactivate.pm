package Inventory::Command::ItemDeactivate;

use strict;
use warnings;

use Inventory;

class Inventory::Command::ItemDeactivate {
    is => 'Inventory::Command',
    doc => 'Set the "active" flag for an item to false',
    has_many_optional => [
        bare_args => { is => 'Text', doc => 'List of item barcodes or SKUs', shell_args_position => 1},
    ],
};

sub execute {
    my $self = shift;

    my @items;
    foreach my $i ( $self->bare_args ) {
        my $item = Inventory::Item->get(sku => $i);

        unless ($item) {
            $item = Inventory::Item->get(barcode => $i);
        }
        unless ($item) {
            $item = Inventory::Item->get(id => $i);
        }

        if ($item) {
            push @items, $item;
        } else {
            $self->warning_message("Found no item matching $i, skipping");
        }
    }

    $self->status_message("Changing ".scalar(@items)." to active");
    foreach my $item ( @items ) {
        if(! $item->active) {
            $self->warning_message("Item with sku ".$item->sku." is already inactive");
        } else {
            $item->active(0);
        }
    }
        
    return 1;
}

1;
