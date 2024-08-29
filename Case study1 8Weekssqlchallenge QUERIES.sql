-- 1) What is the total amount each customer spent at the restaurant?
select customer_id, sum(price) as Total_price from sales s
inner join menu m
on s.product_id=m.product_id
group by customer_id;

-- 2) How many days has each customer visited the restaurant?
select customer_id ,count(distinct order_date) as days from sales 
group by customer_id;
 
-- 3) What was the first item from the menu purchased by each customer?
SELECT rs.customer_id,m.product_name,rs.order_date
FROM (SELECT customer_id,product_id,order_date,
ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY order_date) AS row_num
FROM sales s) AS rs
JOIN menu m ON rs.product_id = m.product_id
WHERE rs.row_num = 1;

-- 4) What is the most purchased item on the menu and how many times was it purchased by all customers?
select product_name,count(order_date) as purchased_Items from sales s
join menu m on s.product_id=m.product_id
group by product_name
order by purchased_Items desc
limit 1;

-- 5) Which item was the most popular for each customer?
SELECT customer_id,product_name
FROM (SELECT s.customer_id,m.product_name, 
        ROW_NUMBER() OVER (PARTITION BY s.customer_id ORDER BY COUNT(s.product_id) DESC) AS rnk
    FROM sales s
    JOIN menu m ON s.product_id = m.product_id GROUP BY s.customer_id, m.product_name
) AS ranked_items WHERE rnk = 1;

-- 6) Which item was purchased first by the customer after they became a member?
SELECT rs.customer_id,m.product_name,rs.order_date
FROM (SELECT s.customer_id,s.product_id,s.order_date,
ROW_NUMBER() OVER (PARTITION BY s.customer_id ORDER BY s.order_date) AS row_num
    FROM sales s
    JOIN members mb ON s.customer_id =mb.customer_id
    WHERE s.order_date >= mb.join_date  
) AS rs
JOIN menu m ON rs.product_id = m.product_id
WHERE rs.row_num = 1;  

-- 7) Which item was purchased just before the customer became a member?
SELECT s.customer_id,m.product_name,s.order_date
FROM sales s
JOIN members mb ON s.customer_id = mb.customer_id
JOIN menu m ON s.product_id = m.product_id
WHERE s.order_date < mb.join_date  
AND s.order_date = (SELECT MAX(order_date)
FROM sales WHERE customer_id = s.customer_id
AND order_date < mb.join_date);

-- 8) What is the total items and amount spent for each member before they became a member?
SELECT mb.customer_id,COUNT(s.product_id) AS total_items,SUM(m.price) AS total_amount_spent
FROM sales s
JOIN members mb ON s.customer_id = mb.customer_id
JOIN menu m ON s.product_id = m.product_id
WHERE s.order_date < mb.join_date  
GROUP BY mb.customer_id
order by customer_id;


-- 9) If each $1 spent equates to 10 points and sushi has a 2x points multiplier - how many points would each customer have?
SELECT s.customer_id,
SUM(
	CASE 
            WHEN m.product_id = 1 THEN (m.price * 2)  ELSE m.price
            END * 10  
    ) AS total_points
FROM sales s
JOIN members mb ON s.customer_id = mb.customer_id
JOIN menu m ON s.product_id = m.product_id
WHERE s.order_date < mb.join_date  
GROUP BY s.customer_id;

-- 10) In the first week after a customer joins the program (including their join date) they earn 2x points on all items, 
-- not just sushi - how many points do customer A and B have at the end of January?
WITH points AS (
    SELECT s.customer_id,s.order_date,m.product_name,m.price,
        CASE
            WHEN s.order_date <= DATE_ADD(mb.join_date, INTERVAL 6 DAY) THEN m.price * 2  
            ELSE m.price
        END * 10 AS points
    FROM sales s
    JOIN members mb ON s.customer_id = mb.customer_id
    JOIN menu m ON s.product_id = m.product_id WHERE s.order_date BETWEEN mb.join_date AND '2024-01-31'  
)
SELECT customer_id,SUM(points) AS total_points FROM points
WHERE customer_id IN ('A', 'B')  GROUP BY customer_id order by customer_id;


-- BONUS QUESTIONS
/*
Join All The Things
Create basic data tables that Danny and his team can use to quickly 
derive insights without needing to join the underlying tables using SQL.
Fill Member column as 'N' if the purchase was made before becoming a member 
and 'Y' if the after is amde after joining the membership.
*/
SELECT customer_id,order_date,product_name,price,
IF(order_date >= join_date, 'Y', 'N') AS member
FROM members
RIGHT JOIN sales USING (customer_id)
INNER JOIN menu USING (product_id)
ORDER BY customer_id,order_date;


/* Rank All The Things
Danny also requires further information about the ranking of customer products,
but he purposely does not need the ranking for non-member purchases
so he expects null ranking values for the records 
when customers are not yet part of the loyalty program.
*/
WITH data_table AS
(SELECT customer_id,order_date,product_name,price,
IF(order_date >= join_date, 'Y', 'N') AS member
FROM members
   RIGHT JOIN sales USING (customer_id)
   INNER JOIN menu USING (product_id)
   ORDER BY customer_id,order_date)
SELECT *,IF(member='N', NULL, DENSE_RANK() OVER (PARTITION BY customer_id, member ORDER BY order_date)) AS ranking FROM data_table;