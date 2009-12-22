package Inventory::OrderItemDetail;

use strict;
use warnings;

use Inventory;
class Inventory::OrderItemDetail {
    type_name => 'order item detail',
    table_name => 'ORDER_ITEM_DETAIL',
    id_by => [
        order_item_detail_id => { is => 'integer' },
    ],
    has => [
        count    => { is => 'integer', valid_values => [1, -1] },
        item     => { is => 'Inventory::Item', id_by => 'item_id', constraint_name => 'ORDER_ITEM_DETAIL_ITEM_ID_ITEM_ITEM_ID_FK' },
        item_id  => { is => 'integer' },
        order    => { is => 'Inventory::Order', id_by => 'order_id', constraint_name => 'ORDER_ITEM_DETAIL_ORDER_ID_ORDERS_ORDER_ID_FK' },
        order_id => { is => 'integer' },
    ],
    schema_name => 'Inventory',
    data_source => 'Inventory::DataSource::Inventory',
};

1;
