package Inventory::Util;

use strict;
use warnings;

use Inventory;

use Time::HiRes;

class Inventory::Util {
    is_singleton => 1,
    doc => 'Collection of useful routines',
};

sub verify_barcode_check_digit {
    my($class, $barcode) = @_;

    return 1 if length($barcode) <= 4;  # Barcodes with 4 or less digits have special uses
    my @digits = split(//,$barcode);
    if (@digits != 12) {
        $class->error_message("Excpected 12 barcode digits, got ",scalar(@digits),"\n");
    }

    my $check = pop @digits;

    my @even = @digits[0,2,4,6,8,10];
    my $even = 0;
    { no warnings 'uninitialized';
      $even += $_ foreach @even;
    }
    $even *= 3;

    my @odd = @digits[1,3,5,7,9];
    my $odd = 0;
    { no warnings 'uninitialized';
     $odd += $_ foreach @odd;
    }

    my $sum = $even + $odd + $check;
    if (! ($sum % 10)) {
        return 1;
    } else {
        $class->error_message("Bad barcode checksum: $sum\n");
        return;
    }
}

my %sound_files = ( error => 'homer_doh.mp3',
                    warning => 'homer_doh.mp3',
                    status => 'ding.mp3',
                  );
sub play_sound {
    return 1 if ($ENV{'INVENTORY_TEST'});

    my($class,$sound) = @_;

    # VT100 set reverse video
    print STDOUT "[?5h";

    my $sound_app;
    if ($^O eq 'darwin') {
        $sound_app = '/usr/bin/true';
        # FIXME - re-enable when we have some sound files
        #$sound_app = 'afplay';
    } elsif ($^O eq 'linux') {
        #$sound_app = 'mpg123';
        $sound_app = '/bin/true';
    } else {
        print STDOUT "\cG";  # bell
    }

    my $sound_file;
    if (-f $sound) {
        $sound_file = $sound;
    } elsif (exists $sound_files{$sound}) {
        $sound_file = $sound_files{$sound};
    } else {
    }

    if ($sound_app) {
        system("$sound_app $sound_file &");  # play in the background
    }
    sleep(0.25);

    # VT100 set normal video
    print STDOUT "[?5l";
}
    
1;
