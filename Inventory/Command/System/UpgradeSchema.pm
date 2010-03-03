package Inventory::Command::System::UpgradeSchema;

use strict;
use warnings;

use Inventory;

class Inventory::Command::System::UpgradeSchema {
    is => 'Inventory::Command::System',
    doc => 'Upgrade the database to the most current version',
};

sub help_synopsis {
    return "inv system upgrade-schema\n";
}

sub help_detail {
    my $self = shift;

    my $latest_ver = Inventory->db_schema_ver;
    my $current_ver_obj = eval { Inventory::Setting->get(name => 'DB_schema_version') };
    my $current_ver = $current_ver_obj ? $current_ver_obj->value : 0;

    my $should_upgrade = $current_ver < $latest_ver
                         ? "You need to perform an upgrade."
                         : "You are already at the latest version.";
    return <<"EOS"
This command should be used whenever there is a schema change.

Your database is at schema version $current_ver.
The latest schema is version $latest_ver.
$should_upgrade
EOS
}

sub execute {
    my $self = shift;
    $DB::single=1;

    my $latest_ver = Inventory->db_schema_ver;
    my $current_ver_obj = eval { Inventory::Setting->get(name => 'DB_schema_version') };
    if (! $current_ver_obj) {
         $self->status_message("You can ignore the above errors about 'no such table: SETTINGS'");
    }
    my $current_ver = $current_ver_obj ? $current_ver_obj->value : 0;

    if ($current_ver > $latest_ver) {
        $self->error_message("The database is at a later version than the current known schema!?\nExiting without making changes");
        return;
    } elsif ($current_ver == $latest_ver) {
        $self->status_message("You are currently at the latest database schema version: $current_ver");
        return 1;
    }

    $self->status_message("Currently at database version $current_ver");
    my $dbh = Inventory::DataSource::Inventory->get_default_handle;

    if ($current_ver == 0) {
        # Version "0" where we didn't have a version stored in the schema
        unless($dbh->do('CREATE TABLE IF NOT EXISTS settings (setting_id integer PRIMARY KEY NOT NULL, name varchar NOT NULL, value varchar)')) {
            $self->error_message("Can't create SETTINGS table: $DBI::errstr");
            return;
        }
        $current_ver_obj = Inventory::Setting->create(name => 'DB_schema_version', value => 1);
        $current_ver = 1;
        $self->status_message("Upgraded to schema version 1");
    }

    if ($current_ver == 1) {
         # Add a new column to flag an item inactive
        if ($dbh->do("alter table item add column active bool NOT NULL DEFAULT 1")) {
            $dbh->do('update item set active = 1');
        } else {
            $self->error_message("Can't add column active to item table: $DBI::errstr");
        }
        $current_ver = 2;
        $self->status_message("Upgraded to schema version 2");
    }

    if ($current_ver == 2) {
        # confirm-shipping will now complain if there are any sale orders without
        # tracking numbers.  Make all the current orders without a tracking number have 
        # a placeholder instead
        my @orders = Inventory::Order::Sale->get(tracking_number => undef);
        foreach my $order ( @orders ) {
            $order->add_attribute(name => 'tracking_number', value => 'unknown');
        }
        $current_ver = 3;
        $self->status_message("Upgraded to schema version 3");
    }


    # finally, save the version number in the table
    $self->status_message("Upgrade complete.  Now at database schema version $current_ver");
    $current_ver_obj->value($current_ver);
    return 1;
}

1;
