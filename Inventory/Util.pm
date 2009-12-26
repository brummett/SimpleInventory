package Inventory::Util;

use Inventory;

class Inventory::Util {
    is_singleton => 1,
    doc => 'Collection of useful routines',
};

sub verify_barcode_check_digit {
    my($class, $barcode) = @_;

    my @digits = split(//,$barcode);
    if (@digits != 12) {
        $self->error_message("Excpected 12 barcide digits, got ",scalar(@digits),"\n");
    }

    my $check = pop @digits;

    my @even = @digits[0,2,4,6,8,10];
    my $even = 0;
    $even += $_ foreach @even;
    $even *= 3;

    my @odd = @digits[1,3,5,7,9];
    my $odd = 0;
    $odd += $_ foreach @odd;

    my $sum = $even + $odd + $check;
    if (! ($sum % 10)) {
        return 1;
    } else {
        $self->error_message("Bad barcode checksum: $sum\n");
        return;
    }
}

my %sound_files = ( error => 'homer_doh.mp3',
                    warning => 'homer_doh.mp3',
                    status => 'ding.mp3',
                  );
sub play_sound {
    my($class,$sound) = @_;

    # VT100 set reverse video
    print STDOUT "[?5h";

    my $sound_app;
    if ($^O eq 'darwin') {
        $sound_app = 'afplay';
    } elsif ($^O eq 'linux') {
        $sound_app = 'mpg123';
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

    # VT100 set normal video
    print STDOUT "[?5l";
}
    
1;
