package Inventory::DataSource::Inventory;

use strict;
use warnings;

use Inventory;

class Inventory::DataSource::Inventory {
    is => [ 'UR::DataSource::SQLite', 'UR::Singleton' ],
};

#sub server { '/Users/abrummet/git/inventory2/Inventory/DataSource/Inventory.sqlite3' }

# The schema_path should always be the official, installed one.  But the 
# active DB can either be the real DB or a test DB
my($database_file_path,$schema_path);
sub _database_file_path {
    unless ($database_file_path) {
        my $self = shift;

        if ($ENV{'INVENTORY_TEST'}) {
            $database_file_path = $self->SUPER::_database_file_path;
            $schema_path = $self->SUPER::_schema_path;
            $database_file_path = "/tmp/inventorydb_$$.sqlite3";
            unlink $database_file_path if (-f $database_file_path);
        } else {
            $database_file_path = $self->SUPER::_database_file_path(@_);
        }
    }
    return $database_file_path;
}

sub _schema_path {
    unless ($schema_path) {
        my $self = shift;
        $schema_path = $self->SUPER::_schema_path(@_);
    }
    return $schema_path;
}


END {
    if ($ENV{'INVENTORY_TEST'}) {
        unlink $database_file_path;
    }
}
        

1;
