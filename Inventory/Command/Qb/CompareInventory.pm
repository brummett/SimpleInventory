package Inventory::Command::Qb::CompareInventory;

use strict;
use warnings;

use Inventory;

use IO::File;

class Inventory::Command::Qb::CompareInventory {
    is => 'Inventory::Command::Qb',
    has => [
        qb_file   => { is => 'String', default_value => 'physical.csv',
                       doc => 'Pathname to quickbooks inventory export csv file' },
        output    => { is => 'String', default_value => 'qb_currections.csv',
                       doc => 'Pathname to store the differences in' },
        skip_avon => { is => 'Boolean', default_value => 1,
                       doc => 'Do not look at avon or tupperware items in the QB file' }, # FIXME - poorly named
    ],
    doc => 'Compare inventory counts between the local database and QuickBooks',
};

sub help_synopsis {
    return <<"EOS"
inv qb compare-inventory
inv qb compare-inventory --qb-file physical.csv
inv qb compare-inventory --qb-file physical.csv --output corrections.csv
EOS
}

sub help_detail {
    return <<"EOS"
After exporting the current inventory report from QuickBooks, this command
will read that file in, and produce a report showing which items have counts
that differ from the internal Inventory database, and what the QuickBooks
inventory corrections should be.

By default it will look for a file called 'physical.csv' in the current
directory and output the report to stdout.
EOS
}

# Vendors' products to skip wieh --skip-avon is true
my %skip_avon_vendors = ( Avon => 1,
                          Tupperware => 1,
                          'Advocare Products' => 1,
                          'Pampered Chef' => 1,
                        );

sub execute {
    my $self = shift;

    my $file = $self->qb_file;
    my $in = IO::File->new($file, 'r');
    unless ($in) {
        $self->error_message("Can't open file $file for reading: $!");
        return;
    }

    {
        my $line = $in->getline();
        chomp $line if $line;
        my @line = split(/\t/, $line);
        unless ($line[1] eq 'Item Description' and $line[2] eq 'Pref Vendor'
                and $line [3] eq 'On Hand') {
            $self->error_message("$file format is incorrect.  Expected  'Item Description', 'Pref Vendor' and 'On Hand' in columns 2 3 and 4");
            $self->error_message("Got: ".join(',',@line[1,2,3]));
            return;
        }
    }

    my $outfile = $self->output;
    my $out = IO::File->new($outfile, 'w');
    unless ($out) {
        $self->error_message("Can't open file $outfile for writing: $!");
        return;
    }

    my $skip_avon = $self->skip_avon;
    my %qb_skus;
    $self->status_message("Reading QuickBooks file...\n");
    while (my $line = $in->getline()) {
        chomp $line if $line;
        last unless $line;

        my @line = split(/\t/, $line);
$DB::single=1 if $line[0] =~ m/402594/;
        next unless ($line[0] and $line[1] and $line[2]);  # some lines look like headers or dividers?
        if ($skip_avon and $skip_avon_vendors{$line[2]}) {
            next;
        }

        my $sku = $line[0];
        # Some of her SKUs in QB have a -vendow suffix that's not in the Inventory DB
        $sku =~ s/-\w+$//;
        $qb_skus{$sku} = { count => $line[3], desc => $line[1], line => $. };
    }
    $in->close;

$DB::single=1;
    my %report;
    my %seen;
    $self->status_message("Comparing to database counts...");
    my $item_iter = Inventory::Item->create_iterator();
    while (my $item = $item_iter->next) {
        my $db_count = $item->count;
        my $sku = $item->sku;
        
        if (exists $qb_skus{$sku}) {
$DB::single=1 if (! defined $db_count or ! defined  $qb_skus{$sku}->{'count'});
            if ($db_count != $qb_skus{$sku}->{'count'}) {
                $report{'differing_count'}->{$sku} = 1;
            } 
        } else {
            $report{'in_db_not_qb'}->{$sku} = 1;
        }
        $seen{$sku} = 1;
    }

    foreach my $sku ( keys %qb_skus ) {
        next if $seen{$sku};
        # leftovers were not in the local DB
        next unless ($qb_skus{$sku}->{'count'});  # don't bother with items with 0 count
        $report{'in_qb_not_db'}->{$sku} = 1;
    }

    $self->_report_on('differing_count', \%report, $out, \%qb_skus);
    $self->_report_on('in_db_not_qb', \%report, $out, \%qb_skus);
    $self->_report_on('in_qb_not_db', \%report, $out, \%qb_skus);

    $out->close;

    $self->status_message("Results saved to $outfile");
    return 1;
}

sub _report_on {
    my($self,$key, $report, $out, $qb_skus) = @_;

    return unless $report->{$key};  # Nothing for this key

    $out->print($key,"\n");
    $out->print("sku\tItem Description\tDB Count\tQuickBooks Count\tQuickBooks Correction\n");
    foreach my $sku ( keys %{$report->{$key}} ) {
        my($desc,$db_count,$correction);

        my $item = Inventory::Item->get(sku => $sku);
        if ($item) {
            $desc = $item->desc;
            $db_count = $item->count;
            $correction = $qb_skus->{$sku}
                          ? $db_count - $qb_skus->{$sku}->{'count'}
                          : "$db_count (new item)";
        } else {
            $desc = $qb_skus->{$sku}->{'desc'};
            $db_count = 'n/a';
            $correction = 'add to db';
        }

        $out->printf("%s\t%s\t%s\t%s\t%s\n",
                     $sku,
                     $desc,
                     $db_count,
                     $qb_skus->{$sku}->{'count'},
                     $correction);
    }
}

1;
