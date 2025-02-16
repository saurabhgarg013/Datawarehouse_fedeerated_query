-- Create the table with the NOT NULL constraint on product_id


-- ==================
-- Product Dimension
-- ==================

drop table dwh.dim_product;
CREATE TABLE dwh.dim_product (
    product_id INT NOT NULL PRIMARY KEY,
    product_name VARCHAR(255),
    list_price DECIMAL(10, 2),
    model_year INT,
    brand_name VARCHAR(255),
    category_name VARCHAR(255)
  )


-- Insert data using the federated query
INSERT INTO dwh.dim_product
SELECT 
    p.product_id,
    p.product_name,
    p.list_price,
    p.model_year,
    b.brand_name,
    c.category_name 
FROM rds_schema_1.products p
JOIN rds_schema_1.brands b
    ON p.brand_id = b.brand_id 
JOIN rds_schema_1.categories c
    ON p.category_id = c.category_id
WHERE p.product_id IS NOT NULL;

select * from dwh.dim_product;

-- ==================
-- Customer Dimension
-- ==================
CREATE TABLE dwh.dim_customer (
    customer_id INT NOT NULL PRIMARY KEY,
    first_name VARCHAR(255),
    last_name VARCHAR(255),
    phone VARCHAR(255),
    email VARCHAR(255),
    street VARCHAR(255),
    zip_code VARCHAR(255),
    state VARCHAR(255)
);

-- Insert data using the federated query
INSERT INTO dwh.dim_customer
SELECT
    c.customer_id,
    c.first_name,
    c.last_name,
    COALESCE(c.phone, 'Unknown') AS phone,
    COALESCE(c.email, 'Unknown') AS email,
    COALESCE(c.street, 'Unknown') AS street,
    COALESCE(c.zip_code, 'Unknown') AS zip_code,
    COALESCE(c.state, 'Unknown') AS state
FROM rds_schema_1.customers c
WHERE c.customer_id IS NOT NULL;



select * from dwh.dim_customer;

-- ==================
-- Store Dimension
-- ==================

-- Create the table with the store_id column as NOT NULL and declare the primary key
CREATE TABLE dwh.dim_store (
    store_id INT NOT NULL PRIMARY KEY,
    store_name VARCHAR(255),
    phone VARCHAR(255),
    email VARCHAR(255),
    street VARCHAR(255),
    zip_code VARCHAR(255),
    city VARCHAR(255)
);

-- Insert data using the federated query
INSERT INTO dwh.dim_store
SELECT 
    s.store_id,
    s.store_name,
    COALESCE(s.phone, 'Unknown') AS phone,
    COALESCE(s.email, 'Unknown') AS email,
    s.street,
    s.zip_code,
    s.city 
FROM rds_schema_1.stores s
WHERE s.store_id IS NOT NULL;



-- ==================
-- Staff Dimension
-- ==================

-- Create the table with the staff_id column as NOT NULL and declare the primary key
CREATE TABLE dwh.dim_staff (
    staff_id INT NOT NULL PRIMARY KEY,
    first_name VARCHAR(255),
    last_name VARCHAR(255),
    phone VARCHAR(255),
    email VARCHAR(255),
    active BOOLEAN,
    manager_id INT,
    manager_first_name VARCHAR(255),
    manager_last_name VARCHAR(255)
);

-- Insert data using the federated query
INSERT INTO dwh.dim_staff
SELECT 
    s.staff_id,
    s.first_name,
    s.last_name,
    COALESCE(s.phone, 'Unknown') AS phone,
    COALESCE(s.email, 'Unknown') AS email,
    s.active,
    s.manager_id,
    s2.first_name AS manager_first_name,
    s2.last_name AS manager_last_name
FROM rds_schema_1.staffs s
LEFT JOIN rds_schema_1.staffs s2
    ON s.manager_id = s2.staff_id
WHERE s.staff_id IS NOT NULL;

-- ==================
-- Date Dimension
-- ==================

-- Create the table
CREATE TABLE dwh.dim_date (
    date_id INT NOT NULL PRIMARY KEY,
    date DATE NOT NULL,
    day_name VARCHAR(9) NOT NULL,  -- Using VARCHAR instead of TEXT
    day_of_month INT NOT NULL,
    week_of_month INT NOT NULL,
    week_of_year INT NOT NULL,
    month INT NOT NULL,
    month_name VARCHAR(9) NOT NULL,
    quarter INT NOT NULL,
    year INT NOT NULL,
    is_weekend BOOLEAN NOT NULL
);

-- Insert data using ROW_NUMBER() and generate date sequence
INSERT INTO dwh.dim_date
SELECT 
    (EXTRACT(YEAR FROM d) * 10000 + EXTRACT(MONTH FROM d) * 100 + EXTRACT(DAY FROM d)) AS date_id,
    d AS date,
    CASE EXTRACT(DOW FROM d) 
        WHEN 0 THEN 'Sunday' 
        WHEN 1 THEN 'Monday'
        WHEN 2 THEN 'Tuesday'
        WHEN 3 THEN 'Wednesday'
        WHEN 4 THEN 'Thursday'
        WHEN 5 THEN 'Friday'
        WHEN 6 THEN 'Saturday'
    END AS day_name,
    EXTRACT(DAY FROM d) AS day_of_month,
    ((EXTRACT(DAY FROM d) - 1) / 7 + 1) AS week_of_month,  -- Manually calculating week_of_month
    EXTRACT(WEEK FROM d) AS week_of_year,
    EXTRACT(MONTH FROM d) AS month,
    CASE EXTRACT(MONTH FROM d) 
        WHEN 1 THEN 'January'
        WHEN 2 THEN 'February'
        WHEN 3 THEN 'March'
        WHEN 4 THEN 'April'
        WHEN 5 THEN 'May'
        WHEN 6 THEN 'June'
        WHEN 7 THEN 'July'
        WHEN 8 THEN 'August'
        WHEN 9 THEN 'September'
        WHEN 10 THEN 'October'
        WHEN 11 THEN 'November'
        WHEN 12 THEN 'December'
    END AS month_name,
    EXTRACT(QUARTER FROM d) AS quarter, 
    EXTRACT(YEAR FROM d) AS year,
    CASE 
        WHEN EXTRACT(DOW FROM d) IN (0, 6) THEN TRUE
        ELSE FALSE
    END AS is_weekend
FROM (
    -- Generate a sequence of 2000 days using Redshift's STL system tables
    SELECT DATEADD(day, ROW_NUMBER() OVER() - 1, '2016-01-01') AS d
    FROM (SELECT NULL FROM STV_BLOCKLIST LIMIT 3000) seq
) date_seq
ORDER BY 1;