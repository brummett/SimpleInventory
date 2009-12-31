package Inventory::Command::Lookup;

use strict;
use warnings;

use Inventory;

use IO::Handle;

class Inventory::Command::Lookup {
    is => 'Inventory::Command',
    has => [
        key => { is => 'String', is_optional => 1, doc => 'item to look up, prompt if ommitted' },
    ],
    doc => 'Show details about an item',
};
 
sub execute {
    my $self = shift;

    my $key = $self->key;

    my $prompted = 0;
    unless (defined $key) {
        STDOUT->autoflush(1);
        $prompted = 1;
        print "SKU, barcode or partial description: ";
        my $key = <STDIN>;
        return 1 unless $key;

        chomp($key);
        $key =~ s/^\s+|\s+$//;
        return 1 unless $key;
    }

    my @items = Inventory::Item->get(sky => $key);
    push @items, Inventory::Item->get(barcode => $key);
    push @items, Inventory::Item->get('desc like' => $key);

    foreach my $item ( @items ) {
        $self->status_message(
            sprintf("Item: barcode %s sku %s count %d\n\t%s\n",
                $item->barcode, $item->sku, $item->count. $item->desc));
    }

    return 1;
}

1;   
