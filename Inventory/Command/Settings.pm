package Inventory::Command::Settings;

use strict;
use warnings;

use Inventory;

class Inventory::Command::Settings {
    is => 'Inventory::Command',
    has_optional => [
        key => { is => 'String', doc => 'Setting key' },
        value => { is => 'String', doc => 'New value' },
        remove => { is => 'Boolean', doc => 'Remove the named setting' },
    ],
    doc => 'View or change configuration settings',
};

sub help_synopsis {
    return <<"EOS"
inv settings
inv settings --key foo
inv settings --key foo --value 123
inv settings --key foo --remove
EOS
}

sub help_detail {
    return <<"EOS"
With no options, it will display all the settings and their values.
With just a --key option, it will print the value of that option.
With both --key and --value, it will change the named setting to the
given value
EOS
}

# FIXME - The schema supports multi-value settings (more than one row with
# the same name), but there's no support in this command for manipulating them.
sub execute {
    my $self = shift;

    if ($self->remove) {
        unless ($self->key) {
            $self->error_message("--key is required when removing settings");
            return;
        }
        my @settings = Inventory::Setting->get(name => $self->key);
        $self->status_message("Removing ".scalar(@settings)." settings");
        $_->delete foreach @settings;
        return 1;

    } elsif (! $self->value) {
        my %params;
        if ($self->key) {
            $params{'filter'} = 'name='.$self->key;
        }

        my $lister = Inventory::Command::List::Settings->create(%params);
        my $rv = $lister->execute();
        return $rv;
    }

    # Changing a setting
    my $s = Inventory::Setting->get(name => $self->key);
    if ($s) {
        my $old = $s->value;
        $s->value($self->value);
        $self->status_message(sprintf("%s changed from %s to %s",
                                      $s->name, $old, $s->value));
    } else {
        $s = Inventory::Setting->create(name => $self->key, value => $self->value);
        $self->status_message("New setting '".$s->name."' set to '".$s->value."'");
    }
    return 1;
}
    
1;
