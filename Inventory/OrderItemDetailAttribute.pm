package Inventory::OrderItemDetailAttribute;

use strict;
use warnings;

use Inventory;
class Inventory::OrderItemDetailAttribute {
    type_name => 'order item detail attribute',
    table_name => 'ORDER_ITEM_DETAIL_ATTRIBUTE',
    id_by => [
        order_item_detail_attribute_id => { is => 'integer' },
    ],
    has => [
        name                 => { is => 'varchar' },
        order_item_detail    => { is => 'Inventory::OrderItemDetail', id_by => 'order_item_detail_id', constraint_name => 'ORDER_ITEM_DETAIL_ATTRIBUTE_ORDER_ITEM_DETAIL_ID_ORDER_ITEM_DETAIL_ORDER_ITEM_DETAIL_ID_FK' },
        order_item_detail_id => { is => 'integer' },
        value                => { is => 'varchar', is_optional => 1 },
    ],
    schema_name => 'Inventory',
    data_source => 'Inventory::DataSource::Inventory',
};

1;
