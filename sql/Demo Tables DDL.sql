DROP TABLE IF EXISTS daily_load_track;
CREATE TABLE daily_load_track 
(run_date date default current_date,
 pipeline_name varchar(100),
 status varchar(10)
);
 
INSERT INTO daily_load_track(pipeline_name, status) values('');
SELECT * FROM daily_load_track

DROP TABLE IF EXISTS stg_orders;
CREATE TABLE stg_orders 
AS SELECT * FROM orders WHERE 1=2;
SELECT * FROM stg_orders;
TRUNCATE TABLE stg_orders;

DROP TABLE IF EXISTS stg_order_details;
CREATE TABLE stg_order_details
AS SELECT * FROM order_details WHERE 1=2;
TRUNCATE TABLE stg_orders;

DROP TABLE IF EXISTS stg_products;
CREATE TABLE stg_products
AS SELECT * FROM products WHERE 1=2;
SELECT * FROM stg_products;

DROP TABLE IF EXISTS stg_employees;
CREATE TABLE stg_employees
AS SELECT * FROM employees WHERE 1=2;
SELECT * FROM stg_employees;

DROP TABLE IF EXISTS stg_shippers;
CREATE TABLE stg_shippers (
shipper_id int2 NOT NULL, 
company_name varchar(40) NOT NULL, 
phone varchar(24) NULL, 
CONSTRAINT shippers_company_name_not_null NOT NULL company_name, 
CONSTRAINT shippers_shipper_id_not_null NOT NULL shipper_id);
SELECT * from stg_shippers;

DROP TABLE IF EXISTS d_products;
CREATE TABLE d_products 
(dwh_key bigint,
 src_prod_id int, 
 prod_name varchar(40),
 unit_price float);
SELECT * FROM d_products;

DROP TABLE IF EXISTS d_employees;
CREATE TABLE d_employees
(dwh_key bigint,
 src_emp_id int, 
 emp_full_name varchar(100),
 birth_date date,
 hire_date date,
 region varchar(20),
 country varchar(30));
TRUNCATE TABLE d_employees;
SELECT * FROM d_employees;

DROP TABLE IF EXISTS f_orders;
CREATE TABLE f_orders
(order_id int,
 d_employee_id bigint,
 emp_full_name varchar(100),
 src_customer_id int,
 required_date date,
 shipped_date date, 
 d_product_id bigint,
 total_value float,
 record_date date);
SELECT * FROM f_orders;
TRUNCATE TABLE f_orders;

SELECT * FROM orders;
SELECT * FROM order_details od 
(q * unit price) * (1 - disc)

TRUNCATE TABLE stg_orders;
TRUNCATE TABLE stg_order_details;
SELECT count(*) from stg_orders;
SELECT count(*) FROM orders;
SELECT count(DISTINCT order_id) from stg_order_details;


SELECT * FROM stg_orders;
SELECT * FROM stg_order_details;

 
