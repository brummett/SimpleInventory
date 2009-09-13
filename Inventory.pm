package Inventory;

use strict;
use warnings;

use DBI;
use Carp;

sub connect {
my $class = shift;
my $dbname = shift;

    $dbname ||= 'inventory.sqlite3';
    my $dbh = DBI->connect("dbi:SQLite:dbname=$dbname",'','',{AutoCommit => 0});
    unless ($dbh) {
        print STDERR "Can't create/connect to DB inventory.sqlite3: ".$DBI::errstr."\n";
        exit 1;
    }

    $class->_initialize_db($dbh);

    my $self = { dbh => $dbh };
    bless $self,$class;
    return $self;
}

sub _initialize_db {
    my($self,$dbh) = @_;

    $dbh->do("create table if not exists inventory
                           (barcode varchar primary key,
                            sku varchar,
                            desc varchar,
                            count integer,
                            unique (barcode, sku))") || die "Error creating inventory table: ".$DBI::errstr;
    $dbh->do("create index if not exists inventory_sku_index on inventory (sku)") || die "Error creating sku index: ".$DBI::errstr;

    $dbh->do("create table if not exists item_transaction_type
                     (item_transaction_type_id integer PRIMARY KEY,
                      name varchar)") || die "Error creating item_transaction_type table";

    $dbh->do("create table if not exists item_transaction
                     (item_transaction_id varchar NOT NULL primary key,
                      date datetime default CURRENT_TIMESTAMP,
                      type_id integer REFERENCES item_transaction_type(item_transaction_type_id)
                     )") || die "Error creating item_transaction table: ".$DBI::errstr;

    $dbh->do("create table if not exists item_transaction_detail
                     (item_transaction_id integer NOT NULL REFERENCES item_transaction(item_transaction_id),
                      barcode varchar NOT NULL REFERENCES inventory(barcode),
                      count integer NOT NULL,
                      primary key (item_transaction_id, barcode))") || die "Error creating item_transaction_detail table: ".$DBI::errstr;
    $dbh->do("create index if not exists item_transaction_detail_barcode_index on item_transaction_detail(barcode)")
        || die "Error creating item_transaction index: ".$DBI::errstr;

    my %tx_types = ( 1 => 'sale', 2 => 'receive', 3 => 'expired', 4 => 'initial_import' );
    my $check_sth = $dbh->prepare("select item_transaction_type_id from item_transaction_type where item_transaction_type_id = ?");
    my $insert_sth = $dbh->prepare("insert into item_transaction_type (item_transaction_type_id, name) values (?,?)");
    foreach my $id ( keys %tx_types ) {
        $check_sth->execute($id);
        unless ($check_sth->fetchrow_arrayref) {
            $insert_sth->execute($id, $tx_types{$id});
        }
    }
}
 

sub dbh {
    return $_[0]->{'dbh'};
}

sub lookup_by_barcode {
    my($self,$barcode) = @_;

    my $sth = $self->dbh->prepare_cached('select barcode, sku, desc, count from inventory where barcode = ?');
    unless ($sth)  {
        print STDERR "Error preparing lookup_by_barcode: ".$DBI::errstr."\n";
        $sth->finish;
        return;
    }

    unless ($sth->execute($barcode)) {
        print STDERR "Error executing lookup_by_barcode: ".$DBI::errstr."\n";
        $sth->finish;
        return;
    }

    my @retval = $sth->fetchrow_array;
    $sth->finish;
    return unless @retval;
    my %retval;
    @retval{'barcode','sku','desc','count'} = @retval;
    return \%retval;
}

sub get_all_inventory {
    my($self) = @_;

    my $sth = $self->dbh->prepare_cached('select barcode, sku, desc, count from inventory');
    unless ($sth)  {
        print STDERR "Error preparing get_all_inventory: ".$DBI::errstr."\n";
        $sth->finish;
        return undef;
    }
    unless ($sth->execute()) {
        print STDERR "Error executing get_all_inventory: ".$DBI::errstr."\n";
        $sth->finish;
        return;
    }

    #my @all_values;
    #while(my $row = $sth->fetchrow_arrayref) {
    #    my %item;
    #    @item{'barcode','sku','desc','count'} = @$row;
    #    push @all_values, \%item;
    #}
    my $all_values = $sth->fetchall_arrayref({});
    $sth->finish;
    return $all_values;
}
 
sub iterate_all_inventory {
    my($self) = @_;

    my $sth = $self->dbh->prepare_cached('select barcode, sku, desc, count from inventory');
    unless ($sth)  {
        print STDERR "Error preparing get_all_inventory: ".$DBI::errstr."\n";
        $sth->finish;
        return undef;
    }
    unless ($sth->execute()) {
        print STDERR "Error executing get_all_inventory: ".$DBI::errstr."\n";
        $sth->finish;
        return;
    }

    return sub {
        my @retval = $sth->fetchrow_array;
        unless (@retval) {
            $sth->finish;
            $sth = undef;
            return;
        }
        my %retval;
        @retval{'barcode','sku','desc','count'} = @retval;
        return \%retval;
    };
}       

    

sub lookup_by_sku {
    my($self,$sku) = @_;

    my $sth = $self->dbh->prepare_cached('select barcode, sku, desc, count from inventory where sku = ?');
    unless ($sth)  {
        print STDERR "Error preparing lookup_by_sku: ".$DBI::errstr."\n";
        $sth->finish;
        return undef;
    }
    unless ($sth->execute($sku)) {
        print STDERR "Error executing lookup_by_sku: ".$DBI::errstr."\n";
        $sth->finish;
        return;
    }

    my $all_values = $sth->fetchall_arrayref;
    $sth->finish;

    return unless @$all_values;

    if (wantarray) {
        return map { { 'barcode' => $_->[0],
                       'sku'     => $_->[1],
                       'desc'    => $_->[2],
                       'count'   => $_->[3],
                      }
                   } @$all_values;
    } else {
        if (@$all_values > 1) {
            Carp::confess("lookup_by_sku($sku) called in scalar context, but returned multiple values");
            return undef;
        }

        return { 'barcode' => $all_values->[0]->[0],
                 'sku'     => $all_values->[0]->[1],
                 'desc'    => $all_values->[0]->[2],
                 'count'   => $all_values->[0]->[3],
               };
    }
}

sub create_item {
    my($self,%args) = @_;

    $args{'count'} ||= 0;

    my $sth = $self->dbh->prepare_cached('insert into inventory (barcode, sku, desc, count) values (?,?,?,?)');
    unless ($sth) {
        Carp::confess('prepare for create_item failed: ',$DBI::errstr);
        $sth->finish;
        return;
    }

    unless($sth->execute(@args{'barcode','sku','desc','count'})) {
        Carp::confess(sprintf('execute for create_item failed (barcode %s, sku %s, desc %s, count %s): %s',
                              @args{'barcode','sku','desc','count'}, $DBI::errstr));
    }

    $sth->finish;
    return \%args;
}

sub adjust_count_by_barcode {
    my($self,$barcode,$adjustment) = @_;

    my $item = $self->lookup_by_barcode($barcode);
    unless ($item) {
        die "No item with barcode $barcode\n";
        return;
    }

    if ($item->{'count'} + $adjustment < 0) {
        die "Count below 0 for barcode $barcode\n";
    }

    my $sth = $self->dbh->prepare_cached("update inventory set count = count + ? where barcode = ?");
    unless ($sth) {
        Carp::confess('prepare for adjust_count_by_barcode failed: '.$DBI::errstr);
        $sth->finish;
    }

    unless ($sth->execute($adjustment, $barcode)) {
        Carp::confess("execute($adjustment $barcode) for adjust_count_by_barcode failed: ".$DBI::errstr);
        $sth->finish;
    }

    $sth->finish;

    $item = $self->lookup_by_barcode($barcode);
    return $item->{'count'} || '0 but true';
}

sub set_count_by_barcode {
    my($self,$barcode,$count) = @_;

    my $item = $self->lookup_by_barcode($barcode);
    unless ($item) {
        die "No item with barcode $barcode\n";
        return;
    }

    my $sth = $self->dbh->prepare_cached("update inventory set count = ? where barcode = ?");
    unless ($sth) {
        Carp::confess('prepare for set_count_by_barcode failed: '.$DBI::errstr);
        $sth->finish;
    }

    unless ($sth->execute($count, $barcode)) {
        Carp::confess("execute($count $barcode) for set_count_by_barcode failed: ".$DBI::errstr);
        $sth->finish;
    }

    $sth->finish;

    return $count || '0 but true';
}

sub disconnect {
   my $self = shift;
   $self->dbh->disconnect();
}

sub commit {
    my $self = shift;
    $self->dbh->commit();
}

sub rollback {
    my $self = shift;
    $self->dbh->rollback();
}

sub transaction_type_id_for_name  {
    my $self = shift;
    my $name = shift;

    my $sth = $self->dbh->prepare_cached('select item_transaction_type_id from item_transaction_type where name = ?');
    unless ($sth) {
        Carp::confess('prepare for transaction_type_id_for_name failed: ',$DBI::errstr);
        $sth->finish;
        return;
    }

    unless ($sth->execute($name) ) {
        Carp::confess("execute for transaction_type_id_for_name failed (name $name): ".$DBI::errstr);
        $sth->finish;
        return;
    }

    my @row = $sth->fetchrow();
    $sth->finish;

    unless (@row) {
        die "No transaction type named $name\n";
    }

    return $row[0];
}
    
   

sub create_order {
    my($self,$item_transaction_id,$type_name) = @_;
    
    unless ($item_transaction_id && $type_name) {
        die "order id and type name are required\n";
        return;
    }
    
    my $tx_type_id = $self->transaction_type_id_for_name($type_name);

    my $sth = $self->dbh->prepare_cached('insert into item_transaction (item_transaction_id,type_id) values (?,?)');
    unless ($sth) {
        Carp::confess('prepare for create_order failed: ',$DBI::errstr);
        $sth->finish;
        return;
    }

    unless($sth->execute($item_transaction_id,$tx_type_id)) {
        die "execute for create_order failed (item_transaction_id $item_transaction_id: ".$DBI::errstr;
        $sth->finish;
        return;
    }

    $sth->finish;

    my $order = { _db => $self,
                  _item_transaction_id => $item_transaction_id,
                  _type => $type_name };
    return bless $order, 'Inventory::Order';
}

sub get_order_detail {
    my($self, $item_transaction_id) = @_;

    my $sth = $self->dbh->prepare_cached('select date from item_transaction where item_transaction_id = ?');
    unless ($sth) {
       Carp::confess('prepare for get_order_detail failed: '.$DBI::errstr);
       $sth->finish;
       return;
    }

    unless ($sth->execute($item_transaction_id)) {
        Carp::confess("execute for get_order_detail failed (order number $item_transaction_id): ".$DBI::errstr);
        $sth->finish;
        return;
    }

    my @row = $sth->fetchrow_array();
    return unless @row;

    my $order = { _item_transaction_id => $item_transaction_id, _date => $row[0] };

    $sth = $self->dbh->prepare_cached('select barcode, count from item_transaction_detail where item_transaction_id = ?');
    unless ($sth) {
       Carp::confess('prepare for get_order_detail items failed: '.$DBI::errstr);
       $sth->finish;
       return;
    }

    unless ($sth->execute($item_transaction_id)) {
        Carp::confess("execute for get_order_detail items failed (order number $item_transaction_id): ".$DBI::errstr);
        $sth->finish;
        return;
    }

    while (my @row = $sth->fetchrow_array) {
        $order->{$row[0]} = $row[1];
    }
  
    $sth->finish;

    return $order;
}


package Inventory::Order;

sub _db {
    return shift->{'_db'};
}

sub item_transaction_id {
    return shift->{'_item_transaction_id'};
}

sub sell_item_by_barcode {
    my($self, $barcode) = @_;

    my $type = $self->{'_type'};
    unless ($type eq 'sale' or $type eq 'expired') {
        die "Tried to sell barcode $barcode and order type was $type\n";
    }

    no warnings 'uninitialized';
    --$self->{$barcode};
}

sub receive_item_by_barcode {
    my($self, $barcode) = @_;

    my $type = $self->{'_type'};
    unless ($type eq 'receive' or $type eq 'initial_import') {
        die "Tried to receive barcode $barcode and order type was $type\n";
    }

    no warnings 'uninitialized';
    ++$self->{$barcode};
}


sub barcodes {
    my $self = shift;

    my @list;
    foreach my $key ( keys %$self ) {
        next if (substr($key, 0, 1) eq '_');  # skip keys starting with _
        push @list, $key;
    }
    return @list;
}

sub remove_barcode {
    my($self,$barcode) = @_;

    delete $self->{$barcode};
}

sub save {
    my $self = shift;

    return if ($self->{'_saved'});

    my $db= $self ->_db;
    my @barcodes = $self->barcodes();
    foreach my $barcode ( @barcodes ) {
        $db->adjust_count_by_barcode($barcode, $self->{$barcode});
    }

    my $sth = $db->dbh->prepare_cached('insert into item_transaction_detail (item_transaction_id,barcode,count) values (?,?,?)');
    unless ($sth) {
        die 'prepare for save-items failed: '.$DBI::errstr;
        $sth->finish;
        return;
    }

    foreach my $barcode ( @barcodes ) {
        next unless ($self->{$barcode} ); # Skip items with 0 count
        my $count = $self->{$barcode};
        unless($sth->execute($self->{'_item_transaction_id'}, $barcode, $count)) {
            die sprintf("execute for create_order failed (item_transaction_id %s): %s", $self->{'_item_transaction_id'}, $DBI::errstr);
        }
    }

    $sth->finish;

    $self->{'_saved'} = 1;
    return 1;
}

1;
