package Inventory::Command::Amazon;

use strict;
use warnings;

use Inventory;

class Inventory::Command::Amazon {
    is => 'Inventory::Command',
    is_abstract => 1,
    doc => 'Commands for interacting with an Amazon seller account',
};

sub help_detail {
    return <<"EOS"
The Amazon orders workflow goes something like this:
1) Download the New Orders report (not Unshipped Orders) to a local
   text file
2) run "inv amazon import-orders --file <filename"
   Creates picklist orders for each amazon order
   By default, automaticly runs the 'print picklist' command unless
   you specify --noprint
3) run 'inv print picklist'
   Creates a file called pick_list.txt in the currect directory containing
   a report of all the PickList orders in the system.
3) run "inv sale" or "inv fill-pick-list"
   If you give "sale" the order number of a picklist order, it starts
   up 'fill-pick-list' for you.  After the order is filled, is is converted
   from a picklist order into a sale order
4) run 'inv confirm-shipping'
   Asks for order numbers, tracking number for their box, etc.
   For amazon sourced orders, it creates a file called amazon_confirm_upload.txt
   that you can use to batch-confirm all the orders.
EOS
}

1;
