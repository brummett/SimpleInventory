package Inventory::Command::CreateItem;

use strict;
use warnings;

use Inventory;
use IO::Handle;

class Inventory::Command::CreateItem {
    is => 'Inventory::Command',
    has_optional => [
        barcode => { is => 'String' },
        sku     => { is => 'String' },
        desc    => { is => 'String' },
    ],
    doc => 'Create a new item by prompting the user',
};

sub execute {
    my $self = shift;

    my $item;
    if ($self->barcode or $self->sku) {
        my %params;
        foreach my $attr (qw( barcode sku ) ) {
            my $val = $self->$attr;
            $params{$attr} = $val if $val;
        }
    
        my @items = Inventory::Item->get(%params);
        if (@items > 1) {
            my $param_str = join(', ', map { $_ . ': ' . $params{$_} } keys %params);
            $self->error_message("Expected to find zer or one item for params $param_str, but got ".scalar(@items));
            return;
        }
        $item = shift @items;
    } 

    if ($item) {
        $self->status_message("Updating item: ".$item->desc);
    
    } else {
        $self->status_message("New item");
        SCAN_BARCODE:
        for (1) {
            my $barcode = $self->get_response_for('barcode');
            return unless $barcode;
            unless (Inventory::Util->verify_barcode_check_digit($barcode)) {
                $self->error_message('Barcode did not scan properly');
                redo SCAN_BARCODE;
            }
            $item = Inventory::Item->get(barcode => $barcode);
            if ($item) {
                $self->error_message("An item already exists with that barcode: ".$item->desc);
                return;
            }
            # Worked
            $self->barcode($barcode);
        }
    }

    foreach my $attr (qw( sku desc ) ) {
        my $value = $self->$attr();
        unless ($value) {
            $value = $self->get_response_for($attr);
        }
        $self->$attr($value);
    }

    $item = Inventory::Item->create(barcode => $self->barcode,
                                    sku => $self->sku,
                                    desc => $self->desc);
    unless ($item) {
        $self->error_message("Could not create new item");
        return;
    }
    
    return $item;
}

sub get_response_for {
    my($self,$attr) = @_;

    my $val;
    if ($self->can($attr)) { 
        $val = $self->$attr();
    }
    unless (defined $val) {
        print "    $attr: ";
        $val = STDIN->getline() || '';
        chomp $val;
    }
    return $val;
}
        
1;
