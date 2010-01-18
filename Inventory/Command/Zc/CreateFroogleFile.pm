package Inventory::Command::Zc::CreateFroogleFile;

use strict;
use warnings;

use Inventory;

use IO::File;
use WWW::Mechanize;

class Inventory::Command::Zc::CreateFroogleFile {
    is => 'Inventory::Command::Zc',
    has => [
        output => { is => 'String', default_value => 'froogle_upload.csv', doc => 'Corrected froogle filename to create' },
    ],
    has_optional => [
        input => { is => 'String', doc => "'Froogle csv' file exported from ZenCart's EasyPopulate" },
        url => { is => 'String', doc => 'URL to look for Froogle csv files' },
    ],
};

sub help_synopsis {
    return <<"EOS"
inv zc create-froogle-file
inv zc create-froogle-file --input Froogle-EP2010-Jan1-1234.txt --output froogle.csv
inv zc create-froogle-file --url http://www.example.com/catalog/temp/FroogleFile.txt
EOS
}

sub help_detail {
    return <<"EOS"
ZenCart has a function to create files appropriate for uploading into Google
Base, under the Tools -> EasyPopulate menu of the admin interface.  However,
the file it creates is missing a column for 'condition'.  It may also be 
missing data in the 'upc' column.  This command creates a new file with all
the information of the original, adds upc barcodes for all items, and adds
'new' for the condition.

The input data can be found by:
1) The 'zencart froogle url' setting.  It will search the given directory for
   files and use the newest one it finds.
2) The --url command-line option.  To override and existing 'zencart froogle
   url' setting.
3) The --input option to specify a file you may have already downloaded from 
   ZenCart.
EOS
}

sub execute {
    my $self = shift;

$DB::single=1;
    my $infh = $self->_open_input_stream();
    return unless $infh;

    my $outfile = $self->output;
    if (-f $outfile) {
        my $renamed = $outfile . '.bak';
        $self->warning_message("Output file $outfile already exists, renaming it to $renamed");
        unless(rename($outfile, $renamed)) {
            $self->error_message("Couldn't rename: $!");
            return;
        }
    }

    my $outfh = IO::File->new($outfile, 'w');
    unless ($outfh) {
        $self->error_message("Can't open $outfile for writing: $!");
        return;
    }

    my $first_line = $self->_verify_input_stream_format($infh);
    return unless ($first_line);

    $outfh->print($first_line,"\tcondition\n");

    my $count = 0;
    while(<$infh>) {
        chomp;
        my @fields = split(/\t/);

        my $sku = $fields[6];
        unless (defined $sku) {
            $self->error_message("Item on line $. has no sku");
            next;
        }

        my $item = Inventory::Item->get(sku => $sku);
        unless ($item) {
            $self->error_message("Item on line $. has sku $sku, but found no matching item in the database");
            next;
        }

        my $barcode = $fields[10];
        unless ($barcode) {
            $barcode = $fields[10] = $item->barcode;
        }

        push @fields, 'new';

        $count++;
        $outfh->print(join("\t", @fields),"\n");
    } # end while

    $self->status_message("Wrote $count items to $outfile");
    return 1;
}


sub _verify_input_stream_format {
    my($self,$infh) = @_;

    my $first_line = $infh->getline;
    chomp $first_line;
    my @first_line = split(/\t/, $first_line);

    unless ($first_line[3] eq 'price' and $first_line[6] eq 'offer_id' and $first_line[10] eq 'upc') {
        $self->error_message("Input file has bad layout, expected 'price' in column D, 'offer_id' in column G and 'upc' in column K");
        $self->error_message("Got: ",$first_line[3],", ",$first_line[6]," and ",$first_line[10]);
        return;
    }

    return $first_line;
}


sub _open_input_stream {
    my $self = shift;

    
    if ($self->input) {
        my $infh = IO::File->new($self->input, 'r');
        unless ($infh) {
            $self->error_message("Can't open ".$self->input." for reading: $!");
            return;
        }
        return $infh;

    } else {
        unless ($self->url) {
            my $setting = Inventory::Setting->get(name => 'zencart froogle url');
            unless ($setting) {
                $self->error_message("You provided no way to get the froogle data file");
                return;
            }
            $self->url($setting->value);
        }

        my $mech = WWW::Mechanize->new();
        $mech->get($self->url);
        my @links = $mech->find_all_links(text_regex => qr(Froogle-EP.*\.txt));

        # If no links found, maybe that was a direct URL to the file?
        # If there were links, then find the link with the latest date
        if (@links) {
            my(@dates,%date_to_link_idx);
            for (my $i = 0; $i < @links; $i++) {
                $links[$i]->text =~ m/Froogle-EP(\d\d\d\d)(\w\w\w)(\d\d)-/;
                unless ($1) {
                    $self->warning_message("Couldn't parse date from url $links[$i]");
                    next;
                }
                my $datestr = "$1-$2-$3";
                push @dates, $datestr;
                $date_to_link_idx{$datestr} = $i;
            }

            @dates = sort { UR::Time->compare_dates($a,$b) } @dates;
            my $link_to_get = $links[ $date_to_link_idx{ $dates[-1] } ];
            $mech->get($link_to_get);
        }

        my $content = $mech->content;

        my $infh = IO::Handle->new();
        open($infh, '<', \$content);
        return $infh
    }
}


1;
