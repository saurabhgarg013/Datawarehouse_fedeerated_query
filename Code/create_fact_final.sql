-- ===========
-- Order Fact
-- ===========

-- Create the table with primary and foreign key constraints
CREATE TABLE dwh.fact_bike_order (
    order_date_id INT NOT NULL,
    requirement_date_id INT NOT NULL,
    customer_id INT NOT NULL,
    staff_id INT NOT NULL,
    store_id INT NOT NULL,
    product_id INT NOT NULL,
    order_id INT NOT NULL,
    quantity INT,
    list_price DECIMAL(10, 2),
    discount DECIMAL(10, 2),
    order_amount DECIMAL(10, 2),
    discounted_order_amount DECIMAL(10, 2),
    PRIMARY KEY (order_id),
    FOREIGN KEY (order_date_id) REFERENCES dwh.dim_date(date_id),
    FOREIGN KEY (requirement_date_id) REFERENCES dwh.dim_date(date_id),
    FOREIGN KEY (customer_id) REFERENCES dwh.dim_customer(customer_id),
    FOREIGN KEY (staff_id) REFERENCES dwh.dim_staff(staff_id),
    FOREIGN KEY (store_id) REFERENCES dwh.dim_store(store_id),
    FOREIGN KEY (product_id) REFERENCES dwh.dim_product(product_id)
);

-- Insert data using a SELECT statement
INSERT INTO dwh.fact_bike_order
SELECT
    to_char(o.order_date, 'yyyymmdd')::int AS order_date_id,
    to_char(o.required_date, 'yyyymmdd')::int AS requirement_date_id,
    o.customer_id,
    o.staff_id,
    o.store_id,
    oi.product_id,
    o.order_id,
    oi.quantity,
    oi.list_price,
    oi.discount,
    oi.list_price * oi.quantity AS order_amount,
    (oi.list_price - oi.discount) * oi.quantity AS discounted_order_amount
FROM rds_schema_1.orders o 
JOIN rds_schema_1.order_items oi
    ON o.order_id = oi.order_id;


-- ===============
-- Shipment Fact
-- ===============

-- Create the table with primary and foreign key constraints
CREATE TABLE dwh.fact_bike_shipment (
    shipment_date_id INT NOT NULL,
    customer_id INT NOT NULL,
    staff_id INT NOT NULL,
    store_id INT NOT NULL,
    product_id INT NOT NULL,
    order_id INT NOT NULL,
    quantity INT,
    list_price DECIMAL(10, 2),
    discount DECIMAL(10, 2),
    shipment_amount DECIMAL(10, 2),
    discounted_shipment_amount DECIMAL(10, 2),
    PRIMARY KEY (order_id),
    FOREIGN KEY (shipment_date_id) REFERENCES dwh.dim_date(date_id),
    FOREIGN KEY (customer_id) REFERENCES dwh.dim_customer(customer_id),
    FOREIGN KEY (staff_id) REFERENCES dwh.dim_staff(staff_id),
    FOREIGN KEY (store_id) REFERENCES dwh.dim_store(store_id),
    FOREIGN KEY (product_id) REFERENCES dwh.dim_product(product_id)
);

-- Insert data using a SELECT statement
INSERT INTO dwh.fact_bike_shipment
SELECT
    to_char(o.shipped_date, 'yyyymmdd')::INT AS shipment_date_id,
    o.customer_id,
    o.staff_id,
    o.store_id,
    oi.product_id,
    o.order_id,
    oi.quantity,
    oi.list_price,
    oi.discount,
    oi.list_price * oi.quantity AS shipment_amount,
    (oi.list_price - oi.discount) * oi.quantity AS discounted_shipment_amount
FROM rds_schema_1.orders o 
JOIN rds_schema_1.order_items oi
    ON o.order_id = oi.order_id
WHERE o.shipped_date IS NOT NULL;


-- ============================
-- Store Stock Fact
-- ============================

-- Create the table with primary and foreign key constraints
CREATE TABLE dwh.fact_store_stock (
    date_id INT NOT NULL,
    store_id INT NOT NULL,
    product_id INT NOT NULL,
    quantity INT,
    PRIMARY KEY (date_id, store_id, product_id),
    FOREIGN KEY (store_id) REFERENCES dwh.dim_store(store_id),
    FOREIGN KEY (product_id) REFERENCES dwh.dim_product(product_id),
    FOREIGN KEY (date_id) REFERENCES dwh.dim_date(date_id)
);

-- Insert data using a SELECT statement
INSERT INTO dwh.fact_store_stock
SELECT 
    to_char('2021-06-23'::DATE, 'yyyymmdd')::INT AS date_id,
    store_id,
    product_id,
    quantity
FROM 
    rds_schema_1.stocks;
	
	

------
--fact_bike_order_snapshot
-----

-- Create the accumulated snapshot table
CREATE TABLE dwh.fact_bike_order_snapshot (
    order_id INT NOT NULL PRIMARY KEY,
    order_date_id INT NOT NULL,
    requirement_date_id INT,
    shipment_date_id INT,
    delivery_date_id INT,
    order_status SMALLINT NOT NULL,
    customer_id INT NOT NULL,
    staff_id INT NOT NULL,
    store_id INT NOT NULL,
    product_id INT NOT NULL,
    days_pending INT,
    FOREIGN KEY (order_date_id) REFERENCES dwh.dim_date(date_id),
    FOREIGN KEY (requirement_date_id) REFERENCES dwh.dim_date(date_id),
    FOREIGN KEY (shipment_date_id) REFERENCES dwh.dim_date(date_id),
    FOREIGN KEY (customer_id) REFERENCES dwh.dim_customer(customer_id),
    FOREIGN KEY (staff_id) REFERENCES dwh.dim_staff(staff_id),
    FOREIGN KEY (store_id) REFERENCES dwh.dim_store(store_id),
    FOREIGN KEY (product_id) REFERENCES dwh.dim_product(product_id)
);


-- Insert initial data into the accumulated snapshot table
-- Insert initial data into the accumulated snapshot table
INSERT INTO dwh.fact_bike_order_snapshot
SELECT
    o.order_id,
    to_char(o.order_date, 'yyyymmdd')::INT AS order_date_id,
    to_char(o.required_date, 'yyyymmdd')::INT AS requirement_date_id,
    NULL AS shipment_date_id,
    o.order_status,
    o.customer_id,
    o.staff_id,
    o.store_id,
    oi.product_id,
    DATEDIFF(day, o.order_date, CURRENT_DATE) AS days_pending
FROM rds_schema_1.orders o
JOIN rds_schema_1.order_items oi
    ON o.order_id = oi.order_id
WHERE o.shipped_date IS NULL;



UPDATE dwh.fact_bike_order_snapshot
SET 
    shipment_date_id = to_char(o.shipped_date, 'yyyymmdd')::INT,
      order_status = o.order_status,
    days_pending = DATEDIFF(day, o.order_date, CURRENT_DATE)
FROM rds_schema_1.orders o
WHERE 
    dwh.fact_bike_order_snapshot.order_id = o.order_id
    AND o.shipped_date IS NOT NULL;	
	


---------
--Total Revenue / Sales Metrics
SELECT
    SUM(order_amount) AS total_order_revenue,
    SUM(discounted_order_amount) AS total_discounted_order_revenue,
    SUM(shipment_amount) AS total_shipment_revenue,
    SUM(discounted_shipment_amount) AS total_discounted_shipment_revenue
FROM
    dwh.fact_bike_order fbo
JOIN
    dwh.fact_bike_shipment fbs ON fbo.order_id = fbs.order_id;
	

--Order and Shipment Metrics

SELECT
    COUNT(DISTINCT fbo.order_id) AS total_orders,
    COUNT(DISTINCT fbs.order_id) AS total_shipments,
    COUNT(DISTINCT fbos.order_id) AS total_pending_orders
FROM
    dwh.fact_bike_order fbo
LEFT JOIN
    dwh.fact_bike_shipment fbs ON fbo.order_id = fbs.order_id
LEFT JOIN
    dwh.fact_bike_order_snapshot fbos ON fbo.order_id = fbos.order_id;



SELECT
    COUNT(DISTINCT fbo.order_id) AS total_orders,
    COUNT(DISTINCT fbs.order_id) AS total_shipments,
    COUNT(DISTINCT fbos.order_id) AS total_pending_orders
FROM
    dwh.fact_bike_order fbo
LEFT JOIN
    dwh.fact_bike_shipment fbs ON fbo.order_id = fbs.order_id
LEFT JOIN
    dwh.fact_bike_order_snapshot fbos ON fbo.order_id = fbos.order_id;
	


SELECT
    fbo.staff_id,
    COUNT(DISTINCT fbo.order_id) AS total_orders_handled
    AVG(
        DATE(TO_CHAR(fbo.order_date_id, '9999-99-99')) - 
        DATE(TO_CHAR(fbs.shipment_date_id, '9999-99-99'))
    ) AS avg_order_processing_time
FROM
    dwh.fact_bike_order fbo
LEFT JOIN
    dwh.fact_bike_shipment fbs ON fbo.order_id = fbs.order_id
GROUP BY
    fbo.staff_id;
	



SELECT
    COUNT(DISTINCT fbs.order_id) AS total_on_time_shipments
   
FROM
    dwh.fact_bike_order fbs
LEFT JOIN
    dwh.fact_bike_shipment fbos ON fbs.order_id = fbos.order_id
WHERE
    DATEDIFF(day, TO_DATE(CAST(fbos.shipment_date_id AS VARCHAR), 'YYYYMMDD'), TO_DATE(CAST(fbs.requirement_date_id AS VARCHAR), 'YYYYMMDD')) <= 0;	
	
	
	
	
	
SELECT
    dd.year,
    COUNT(DISTINCT fbo.order_id) AS total_orders
FROM
    dwh.fact_bike_order fbo
JOIN
    dwh.dim_date dd ON fbo.order_date_id = dd.date_id
GROUP BY
    dd.year
ORDER BY
    dd.year;



SELECT
    dd.year,
    dd.quarter,
    COUNT(DISTINCT fbo.order_id) AS total_orders
FROM
    dwh.fact_bike_order fbo
JOIN
    dwh.dim_date dd ON fbo.order_date_id = dd.date_id
GROUP BY
    dd.year, dd.quarter
ORDER BY
    dd.year, dd.quarter;




select 
 dc.zip_code  as "customerZipCode"
 ,sum(
  case 
   when sdate."date" is not null 
    and rdate."date" < sdate."date" 
   then 1 
   when sdate."date" is null
    and rdate."date" < current_date          
   then 1
   else 0 
  end 
 )            as "delayedShipmentsCount"
 ,count(*)    as "shipmentsCount"
from
(
 select order_id
  ,customer_id
  ,store_id
  ,requirement_date_id 
 from dwh.fact_bike_order
 group by order_id
  ,customer_id
  ,store_id
  ,requirement_date_id
) orders
left join 
(
 select order_id
  ,shipment_date_id
 from dwh.fact_bike_shipment
 group by order_id
  ,shipment_date_id
) shipments 
 on orders.order_id = shipments.order_id
left join dwh.dim_customer dc 
 on orders.customer_id = dc.customer_id 
left join dwh.dim_store ds 
 on orders.store_id = ds.store_id
left join dwh.dim_date rdate 
 on orders.requirement_date_id = rdate.date_id
left join dwh.dim_date sdate
 on shipments.shipment_date_id = sdate.date_id
group by 
 dc.zip_code
 
 
 --staff managed by Jannette for the first quarter of the year 2017 
 
select 
 (select first_name || ' ' || last_name as "Name" 
 from dwh.dim_staff ds 
 where ds.staff_id = fbo.staff_id
 ) 
 ,sum(fbo.order_amount)                 as "Sales Amount"
from 
 dwh.fact_bike_order fbo
 ,dwh.staff_hierarchy bridge
 ,dwh.dim_staff ds
 ,dwh.dim_date dd
where
 fbo.staff_id    = bridge.subordinate_id   -- 1
 and ds.staff_id = bridge.staff_id         -- 2
 and ds.first_name = 'Jannette'            -- 3
 and fbo.order_date_id   = dd.date_id 
 and dd."year" = 2017
 and dd.quarter = 1
group by
 fbo.staff_id 
 
 
 
 
-- drop table dwh.dim_product cascade;
-- drop table dwh.dim_customer cascade;
-- drop table dwh.dim_date cascade;
-- drop table dwh.dim_staff cascade;
-- drop table dwh.dim_store cascade;
-- drop table dwh.fact_bike_order cascade;
-- drop table dwh.fact_bike_order_snapshot cascade;
-- drop table dwh.fact_bike_shipment cascade;
-- drop table dwh.fact_store_stock cascade; 