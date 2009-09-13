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

    $dbh->do("create table if not exists inventory
                           (barcode varchar primary key,
                            sku varchar,
                            desc varchar,
                            count integer,
                            unique (barcode, sku))") || die "Error creating inventory table: ".$DBI::errstr;
    $dbh->do("create index if not exists inventory_sku_index on inventory (sku)") || die "Error creating sku index: ".$DBI::errstr;
 
    my $self = { dbh => $dbh };
    bless $self,$class;
    return $self;
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
        Carp::confess("No item with barcode $barcode");
        return;
    }
    my $new_count = $item->{'count'} + $adjustment;
    my $sth = $self->dbh->prepare_cached("update inventory set count = ? where barcode = ?");
    unless ($sth) {
        Carp::confess('prepare for adjust_count_by_barcode failed: '.$DBI::errstr);
        $sth->finish;
    }

    unless ($sth->execute($new_count, $barcode)) {
        Carp::confess("execute($new_count $barcode) for adjust_count_by_barcode failed: ".$DBI::errstr);
        $sth->finish;
    }

    $sth->finish;

    return $new_count;
}

sub set_count_by_barcode {
    my($self,$barcode,$count) = @_;

    my $item = $self->lookup_by_barcode($barcode);
    unless ($item) {
        Carp::confess("No item with barcode $barcode");
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

    return $count;
}

sub disconnect {
   my $self = shift;
   $self->dbh->disconnect();
}

1;
