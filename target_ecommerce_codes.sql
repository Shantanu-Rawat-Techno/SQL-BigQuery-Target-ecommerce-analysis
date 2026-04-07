-- Target E-commerce Analysis (SQL/BIG QUERY)

--1.1 Data type of all columns in the "customers" table.
SELECT column_name, data_type
FROM target-sql-488119.TARGET_SQL.INFORMATION_SCHEMA.COLUMNS
WHERE table_name = 'customers';

--1.2 Get the time range between which the orders were placed.
SELECT
MIN(order_purchase_timestamp) AS first_order_date,
MAX(order_purchase_timestamp) AS last_order_date
FROM target-sql-488119.TARGET_SQL.orders;

--1.3 Count the Cities & States of customers who ordered during the given period.
SELECT
COUNT(DISTINCT c.customer_city) AS count_of_cities,
COUNT(DISTINCT c.customer_state) AS count_of_states
FROM target-sql-488119.TARGET_SQL.orders o
JOIN target-sql-488119.TARGET_SQL.customers c
USING (customer_id);

--2.1 Is there a growing trend in the no. of orders placed over the past years?
SELECT
EXTRACT(YEAR FROM order_purchase_timestamp) AS year, 
EXTRACT(MONTH FROM order_purchase_timestamp) AS month, 
CONCAT(EXTRACT(YEAR FROM order_purchase_timestamp), '-', EXTRACT(MONTH FROM order_purchase_timestamp)) AS year_month,
COUNT(order_id) AS total_orders 
FROM target-sql-488119.TARGET_SQL.orders 
GROUP BY year, month, year_month 
ORDER BY year, month, year_month;

--2.2 Monthly seasonality in number of orders
SELECT
EXTRACT(MONTH FROM order_purchase_timestamp) AS month, 
COUNT(order_id) AS total_orders 
FROM target-sql-488119.TARGET_SQL.orders 
GROUP BY month 
ORDER BY month;

--2.3 Time of day analysis for orders
-- 0-6 hrs: Dawn, 7-12 hrs: Morning, 13-18 hrs: Afternoon, 19-23 hrs: Night
SELECT
CASE
WHEN EXTRACT(HOUR FROM order_purchase_timestamp) BETWEEN 0 AND 6 THEN 'Dawn'
WHEN EXTRACT(HOUR FROM order_purchase_timestamp) BETWEEN 7 AND 12 THEN 'Mornings'
WHEN EXTRACT(HOUR FROM order_purchase_timestamp) BETWEEN 13 AND 18 THEN 'Afternoon'
WHEN EXTRACT(HOUR FROM order_purchase_timestamp) BETWEEN 19 AND 23 THEN 'Night'
END AS TIME_OF_DAY,
COUNT(order_id) AS Total_orders_placed
FROM target-sql-488119.TARGET_SQL.orders
GROUP BY TIME_OF_DAY
ORDER BY Total_orders_placed DESC;

--3.1 Month on month orders per state
SELECT
C.customer_state AS STATE,
EXTRACT(YEAR FROM O.order_purchase_timestamp) AS YEAR,
EXTRACT(MONTH FROM O.order_purchase_timestamp) AS MONTH,
COUNT(O.order_id) AS TOTAL_ORDERS
FROM target-sql-488119.TARGET_SQL.orders O 
JOIN target-sql-488119.TARGET_SQL.customers C USING(customer_id)
GROUP BY STATE, YEAR, MONTH
ORDER BY STATE, YEAR, MONTH;

--3.2 Customer distribution across states
SELECT
customer_state AS STATE, COUNT(customer_id) AS TOTAL_CUSTOMERS
FROM target-sql-488119.TARGET_SQL.customers
GROUP BY customer_state
ORDER BY customer_state;

--4.1 % increase in order cost (2017 vs 2018 Jan–Aug)
WITH cte AS (
    SELECT
        EXTRACT(YEAR FROM o.order_purchase_timestamp) AS years,
        COUNT(p.payment_value) AS total_order_cost
    FROM `target-sql-488119.TARGET_SQL.orders` o
    JOIN `target-sql-488119.TARGET_SQL.payments` p USING (order_id)
    WHERE EXTRACT(YEAR FROM o.order_purchase_timestamp) IN (2017, 2018)
      AND EXTRACT(MONTH FROM o.order_purchase_timestamp) BETWEEN 1 AND 8
    GROUP BY years
)
SELECT 
    years, 
    total_order_cost,
    ROUND(
        ((total_order_cost - LAG(total_order_cost) OVER (ORDER BY years)) 
        / LAG(total_order_cost) OVER (ORDER BY years)) * 100, 2
    ) AS percent_increase_yearly
FROM cte
ORDER BY years;

--4.2 Total & average order price per state
SELECT
c.customer_state AS state,
ROUND(SUM(oi.price),2) AS total_value_of_order_price,
ROUND(SUM(oi.price)/COUNT(DISTINCT oi.order_id),2) AS avg_value_of_order_price
FROM target-sql-488119.TARGET_SQL.customers c 
JOIN target-sql-488119.TARGET_SQL.orders o USING (customer_id)
JOIN target-sql-488119.TARGET_SQL.order_items oi USING (order_id)
GROUP BY state;

--4.3 Total & average freight value per state
SELECT
c.customer_state AS state,
ROUND(SUM(oi.freight_value),2) AS total_freightvalue,
ROUND(SUM(oi.freight_value)/COUNT(DISTINCT oi.order_id),2) AS avg_freightvalue
FROM target-sql-488119.TARGET_SQL.customers c 
JOIN target-sql-488119.TARGET_SQL.orders o USING (customer_id)
JOIN target-sql-488119.TARGET_SQL.order_items oi USING (order_id)
GROUP BY state;

--5.1 Delivery time and difference from estimated date
SELECT 
order_id,
DATE_DIFF(DATE(order_delivered_customer_date), DATE(order_purchase_timestamp), DAY) AS days_to_deliver,
DATE_DIFF(DATE(order_delivered_customer_date), DATE(order_estimated_delivery_date), DAY) AS diff_estimated_delivery
FROM `target-sql-488119.TARGET_SQL.orders`
ORDER BY days_to_deliver DESC, diff_estimated_delivery DESC;

--5.2 Top 5 states with highest & lowest avg freight
WITH state_avg AS (
    SELECT
        c.customer_state,
        ROUND(AVG(oi.freight_value), 2) AS avg_freight
    FROM `target-sql-488119.TARGET_SQL.customers` c
    JOIN `target-sql-488119.TARGET_SQL.orders` o ON c.customer_id = o.customer_id
    JOIN `target-sql-488119.TARGET_SQL.order_items` oi ON o.order_id = oi.order_id
    GROUP BY c.customer_state
)
SELECT * FROM (
    SELECT 'Highest' AS category, customer_state, avg_freight
    FROM state_avg
    ORDER BY avg_freight DESC
    LIMIT 5
)
UNION ALL
SELECT * FROM (
    SELECT 'Lowest' AS category, customer_state, avg_freight
    FROM state_avg
    ORDER BY avg_freight ASC
    LIMIT 5
);

--5.3 Top 5 states with highest & lowest delivery time
WITH state_avg AS (
    SELECT
        c.customer_state,
        ROUND(AVG(DATE_DIFF(DATE(o.order_delivered_customer_date), DATE(o.order_purchase_timestamp), DAY)), 2) AS avg_time
    FROM `target-sql-488119.TARGET_SQL.customers` c
    JOIN `target-sql-488119.TARGET_SQL.orders` o ON c.customer_id = o.customer_id
    GROUP BY c.customer_state
)
SELECT * FROM (
    SELECT 'Highest' AS category, customer_state, avg_time
    FROM state_avg
    ORDER BY avg_time DESC
    LIMIT 5 
)
UNION ALL
SELECT * FROM (
    SELECT 'Lowest' AS category, customer_state, avg_time
    FROM state_avg
    ORDER BY avg_time ASC
    LIMIT 5
);

--5.4 Top 5 states with fastest delivery vs estimate
SELECT
c.customer_state,
ROUND(AVG(
    DATE_DIFF(
        DATE(o.order_delivered_customer_date),
        DATE(o.order_estimated_delivery_date),
        DAY
    )
), 2) AS avg_delivery_diff
FROM `target-sql-488119.TARGET_SQL.customers` c
JOIN `target-sql-488119.TARGET_SQL.orders` o
ON c.customer_id = o.customer_id
WHERE o.order_delivered_customer_date IS NOT NULL
AND o.order_estimated_delivery_date IS NOT NULL
GROUP BY c.customer_state
ORDER BY avg_delivery_diff ASC 
LIMIT 5;

--6.1 Orders by payment type monthly
SELECT
EXTRACT(YEAR FROM order_purchase_timestamp) AS year,
EXTRACT(MONTH FROM order_purchase_timestamp) AS month,
payment_type,
COUNT(order_id) AS NUMB_OF_ORDERS
FROM target-sql-488119.TARGET_SQL.orders o 
JOIN target-sql-488119.TARGET_SQL.payments p USING(order_id)
GROUP BY year, month, payment_type
ORDER BY year, month, payment_type;

--6.2 Orders by payment installments
SELECT
p.payment_installments,
COUNT(DISTINCT o.order_id) AS num_of_orders
FROM `target-sql-488119.TARGET_SQL.orders` o
JOIN `target-sql-488119.TARGET_SQL.payments` p 
ON o.order_id = p.order_id
WHERE p.payment_installments > 0
GROUP BY p.payment_installments
ORDER BY p.payment_installments;
