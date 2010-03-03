package Inventory::Command;

use strict;
use warnings;

use Inventory;

class Inventory::Command {
    is => 'Command',
};

sub create {
    my($class,@params) = @_;

    my $wanted_schema_ver = Inventory->db_schema_ver;
    my $current_schema_obj = eval { Inventory::Setting->get(name => 'DB_schema_version') };
    my $current_schema_ver = $current_schema_obj ? $current_schema_obj->value : 0;

    if ($class eq 'Inventory::Command::System::UpgradeSchema' or $wanted_schema_ver == $current_schema_ver) {
        return $class->SUPER::create(@params);

    } else {
        $class->error_message("Your database schema is at version $current_schema_ver and the latest version is $wanted_schema_ver.");

        if ($wanted_schema_ver > $current_schema_ver) {
            $class->error_message("You need to run 'inv system update-schema' before contunuing");
        } else {
            $class->error_message("Somehow, your schema is at a later version than expected.  Do you need to upgrade your software distribution?");
        }

        return undef;
    }
}

1;
