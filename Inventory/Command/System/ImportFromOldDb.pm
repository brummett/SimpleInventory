package Inventory::Command::System::ImportFromOldDb;

use strict;
use warnings;

use Inventory;

class Inventory::Command::System::ImportFromOldDb {
    is => 'Inventory::Command',
    has => [
        db => { is => 'String', doc => 'path to old sqlite db' },
    ],
    doc => 'Convert a SimpleInventory v1 database to v2',
};

sub execute {
    my $self = shift;

    my $old_db = $self->db;
    unless (-f $old_db) {
        $self->error_message("Path to old DB does not exist");
        return;
    }

    my $dbname = $self->db;
    my $old_dbh = DBI->connect("dbi:SQLite:dbname=$dbname",'','',{AutoCommit => 0});
    unless ($old_dbh) {
        $self->error_message("Can't connect to old DB: $DBI::errstr");
        return;
    }

    $self->_import_items($old_dbh);

    $self->_import_orders($old_dbh);

    $self->_import_order_details($old_dbh);
    
    $self->_verify_counts($old_dbh);

    return 1;
}

sub _import_items {
    my($self,$dbh) = @_;

    print "Importing items...\n";
    my $sth = $dbh->prepare('select * from inventory');
    $sth->execute();
    my $count = 0;
    while (my $row = $sth->fetchrow_hashref()) {
        my $i = Inventory::Item->create(barcode => $row->{'barcode'},
                                        sku     => $row->{'sku'},
                                        desc    => $row->{'desc'});
        unless ($i) {
            printf("*** barcode %s sku %s desc %s\n",@$row->{'barcode','sku','desc'});
            die "Problem creating Inventory::Item ";
        }
        $count++;
    }
    print "Imported $count items\n";
    return $count;
}

# Convert from the old order_type_id to the new classes
my %order_types = ( 1 => 'Inventory::Order::Sale',
                    2 => 'Inventory::Order::Purchase',
                    3 => 'Inventory::Order::Expiration',
                    4 => 'Inventory::Order::InventoryCorrection',
                    5 => 'Inventory::Order::InventoryCorrection',
                  );
sub _import_orders {
    my($self,$dbh) = @_;

    print "Importing orders...\n";
    my $sth = $dbh->prepare('select * from item_transaction');
    $sth->execute();
    my $count = 0;
    while (my $row = $sth->fetchrow_hashref) {
        my $type = $order_types{$row->{'type_id'}};
        unless ($type) {
            die "*** No order type for ".$row->{'type_id'};
        }
        
        my $trans_id = $row->{'item_transaction_id'};
        my $source;
        if ($trans_id =~ m/^amz/ ) {
            $source = 'amazon';
        } elsif ($trans_id =~ m/^web/) {
            $source = 'web';
        } elsif ($trans_id =~ m/^ebay/) {
            $source = 'ebay';
        } elsif ($trans_id =~ m/^iof/) {
            $source = 'ioffer';
        }
 
        my $o = $type->create(order_number => $row->{'item_transaction_id'},
                              date         => $row->{'date'},
                              source       => $source);
        unless ($o) {
            printf("*** order number %s date %s",@$row->{'item_transaction_id','date'});
            die "Can't create $type";
        }
        $count++;
    }
    print "Imported $count orders\n";
    return $count;
}

# Due to a bug in the old schema, the item_transaction_id might not match up
# in the item_transaction table  it was a varchar, in the detail table it was integer
my %order_number_fixup = ( '66632' => '0066632',
                           '670655' => '0670655',
                         );
sub _import_order_details {
    my($self,$dbh) = @_;

    print "Importing order details...\n";
    my $sth = $dbh->prepare('select * from item_transaction_detail');
    $sth->execute();
    my $count = 0;
    while (my $row = $sth->fetchrow_hashref) {
        my $order = Inventory::Order->get(order_number => $row->{'item_transaction_id'});
        unless ($order) {
            $order = Inventory::Order->get(order_number => $order_number_fixup{$row->{'item_transaction_id'}});
            unless ($order) {
                die "Can't get Inventory::Order with order_number ".$row->{'item_transaction_id'};
            }
        }
        my $item = Inventory::Item->get(barcode => $row->{'barcode'});
        unless ($item) {
            die "Can't get Inventory::Item with barcode ".$row->{'barcode'};
        }

        my $d = $order->add_item_detail(item_id => $item->id, count => $row->{'count'});
        unless ($d) {
            printf("*** item_id %d count %d",$item->id, $row->{'count'});
            die "Can't add detail to order ".$order->order_number;
        }
        $count++;
    }
    print "Imported $count order details\n";
    return $count;
}


sub _verify_counts {
    my($self,$dbh) = @_;

    print "Verifying item counts\n";
    my $sth = $dbh->prepare('select * from inventory where barcode = ?');

    my $iter = Inventory::Item->create_iterator();
    my $count = 0;
    my $die = 0;
    while (1) {
        my $item = $iter->next();
        last unless $item;
        my $new_count = $item->count();

        $sth->execute($item->barcode);

        my $row = $sth->fetchrow_hashref();
        my $old_count = $row->{'count'};
        if ($new_count != $old_count) {
            printf("Item barcode %s desc %s old count %d new count %d\n",
                   $item->barcode, $item->desc, $old_count, $new_count);
            $die = 1;
        }
    }
    die "Exiting without saving" if $die;
    $self->status_message("Saving changes");

    return 1;
}
