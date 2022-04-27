
/*Set Time Zone*/

set time_zone='-4:00';


/*Preliminary Data Collection
select * to investigate your tables.*/

SELECT * FROM ba710_emails;
SELECT * FROM ba710_prod;
SELECT * FROM ba710_sales;

/*Investigate production dates and prices from the prod table*/

SELECT *
FROM ba710_prod
WHERE product_type = 'scooter'
ORDER BY base_msrp;

/***PRELIMINARY ANALYSIS***/

/*Create a new table in WORK that is a subset of the prod table
which only contains scooters.
Result should have 7 records.*/

CREATE TABLE WORK.case_Scooter AS
SELECT * 
FROM ba710case.ba710_prod
WHERE product_type = 'scooter';

/*Use a join to combine the table above with the sales information*/

CREATE TABLE WORK.case_scooter_sales AS
SELECT p.model, p.product_type, p.product_id,
		  s.customer_id, s.sales_transaction_date, 
          date(s.sales_transaction_date) as sale_date,
          s.sales_amount, s.channel, s.dealership_id
FROM ba710case.ba710_sales s
JOIN WORK.case_Scooter p
ON s.product_id = p.product_id;

/*Create a list partition on product_id. (Hint: Alter table)  
Create one partition for each product_type.
Name each partition as the product's name.*/

ALTER TABLE WORK.case_scooter_sales 
PARTITION BY LIST(product_id) (
			PARTITION Lemon_2010 VALUES IN (1),
            PARTITION Lemon_2013 VALUES IN (3),
            PARTITION Lemon_ltd_edition VALUES IN (2),
            PARTITION BLADE VALUES IN (5),
            PARTITION BAT VALUES IN (7),
            PARTITION Bat_ltd_edition VALUES IN (8),
            PARTITION LEMON_ZESTOR VALUES IN (12));


/***PART 1: INVESTIGATE BAT SALES TRENDS***/  

/*Select Bat models from your table.*/
SELECT * 
FROM WORK.case_scooter_sales
PARTITION(BAT);

/*Count the number of Bat sales from your table.*/
SELECT COUNT(*)
FROM WORK.case_scooter_sales
PARTITION(BAT);

-- Number of Bat sales is 7328 

/*What is the total revenue of Bat sales?*/
SELECT ROUND(SUM(sales_amount),2)
FROM WORK.case_scooter_sales
PARTITION(BAT);

-- Total Revenue of Bat sales is $42,02,269.96

/*When was most recent Bat sale?*/
SELECT *
FROM WORK.case_scooter_sales
PARTITION(BAT)
ORDER BY sale_date DESC
LIMIT 1;

-- Latest Bat sale was on 2019-05-31

/*Now create a table of daily sales.
Summarize of count of sales by date and product id 
(one record for each date & product id combination).
Include model, product_id, sale_date and a column for total sales for each day*/

CREATE TABLE WORK.case_daily_sales AS
SELECT model, sale_date,product_id,  COUNT(*) AS sales_count, ROUND(SUM(sales_amount),2) AS daily_Sales
FROM WORK.case_scooter_sales
GROUP BY sale_date,product_id, model
ORDER BY sale_date,product_id, model; 


/*Now quantify the sales drop*/
/*Create a table of cumulative sales figures for just the Bat scooter.
Using the table created above, add a column that contains the cumulative
sales (one row per date)*/

CREATE TABLE WORK.case_cumulative_bat_Sales AS 
SELECT sale_date, daily_sales, ROUND(SUM(daily_Sales) OVER (ORDER BY sale_date),2) AS cumulative_sales
FROM WORK.case_daily_sales
WHERE model = 'Bat';

/*Compute the cumulative sales for the previous week.
This is caluclated as the 7 day lag of cumulative sum of sales
(i.e., each record should contain the sum of sales for the current date plus
the sales for the preceeding 6 records)*/

CREATE TABLE WORK.case_weekly AS
SELECT sale_date, daily_sales,cumulative_Sales, ROUND(SUM(daily_sales) OVER (ORDER BY sale_date ROWS BETWEEN 6 PRECEDING AND CURRENT ROW),2) AS weekly_cumulative
FROM WORK.Case_cumulative_bat_Sales;


/*Calculate the weekly sales growth as a percentage change of cumulative sales
compared to the cumulative sales from the previous week (seven days ago).*/
/*DROP TABLE work.case_bat_sales_growth;*/

SELECT sale_date,daily_sales, cumulative_Sales, weekly_cumulative,
ROUND((cumulative_Sales - LAG(cumulative_Sales,7) OVER (Order by sale_date))*100/LAG(cumulative_Sales,7) OVER (Order by sale_date),2) AS sales_growth
FROM WORK.case_weekly;


/*Question: On what date does the cumulative weekly sales growth drop below 10%?
Answer: 06/12/2016     

Question: How many days since the launch date did it take for cumulative sales growth
to drop below 10%?
Answer:  58 days */

/*********************************************************************************************
Is the launch timing (October) a potential cause for the drop?
Replicate the Bat sales cumulative analysis for the Bat Limited Edition.
As above, create a cumulative sales table, compute sum of sales for the previous week,
and calculate the sales growth for the past week.*/
/*Compute a cumulative sum of sales with one row per date*/

CREATE TABLE WORK.case_cumulative_bat_ltd_Sales AS 
SELECT sale_date, daily_sales, ROUND(SUM(daily_Sales) OVER (ORDER BY sale_date),2) AS cumulative_sales
FROM WORK.case_daily_sales
WHERE model = 'Bat Limited Edition';

/*Compute a 7 day lag of cumulative sum of sales*/
CREATE TABLE WORK.case_weekly_bat_ltd AS
SELECT sale_date, daily_sales,cumulative_Sales, ROUND(SUM(daily_sales) OVER (ORDER BY sale_date ROWS BETWEEN 6 PRECEDING AND CURRENT ROW),2) AS weekly_cumulative
FROM WORK.Case_cumulative_bat_ltd_Sales;
    
/*Calculate a running sales growth as a percentage by comparing the
current sales to sales from 1 week prior*/
SELECT sale_date, cumulative_Sales, weekly_cumulative,
ROUND((cumulative_Sales - LAG(cumulative_Sales,7) OVER (Order by sale_date))*100/LAG(cumulative_Sales,7) OVER (Order by sale_date),2) AS sales_growth
FROM WORK.case_weekly_bat_ltd;


/*Question: On what date does the cumulative weekly sales growth drop below 10%?
Answer:  29/4/2017          

Question: How many days since the launch date did it take for cumulative sales growth
to drop below 10%?
Answer:    74                           

219 Bat models were sold within first 30 days, whereas only 133 Bat limited edition models were sold within first 30 days.
Hence, it is evident that launch timing (October) is not a potential cause for the drop.

Question: Is there a difference in the behavior in cumulative sales growth 
between the Bat edition and either the Bat Limited edition?
Answer:  While both scooter model’s sales dropped below 100% within a week, the drop in sales growth of Bat limited scooter has been gradual, 
	and it took more than 2 months for growth to drop below 10%. In case of sales of Bat scooter, the drop has been drastic in the first week
        of sales and growth dropped below 10% within 2 months of launch. Also,after first drop below 10% sales growth of bat limited was more 
        than 10% for few weeks. So, overall bat limited performed better than bat model.   */


/*********************************************************************************************
However, the Bat Limited was at a higher price point.
Let's take a look at the 2013 Lemon model, since it's a similar price point.  
Is the launch timing (October) a potential cause for the drop?
Replicate the Bat sales cumulative analysis for the 2013 Lemon model.
As above, create a cumulative sales table, compute sum of sales for the previous week,
and calculate the sales growth for the past week.*/

/*Compute a cumulative sum of sales with one row per date*/
CREATE TABLE WORK.case_cumulative_lemon_2013 AS 
SELECT sale_date, daily_sales, ROUND(SUM(daily_Sales) OVER (ORDER BY sale_date),2) AS cumulative_sales
FROM WORK.case_daily_sales
WHERE model = 'LEMON' AND sale_date > '2013-01-01';

/*Compute a 7 day lag of cumulative sum of sales*/
CREATE TABLE WORK.case_weekly_lemon_2013 AS
SELECT sale_date, daily_sales,cumulative_Sales, ROUND(SUM(daily_sales) OVER (ORDER BY sale_date ROWS BETWEEN 6 PRECEDING AND CURRENT ROW),2) AS weekly_cumulative
FROM WORK.Case_cumulative_lemon_2013;

/*Calculate a running sales growth as a percentage by comparing the
current sales to sales from 1 week prior*/
SELECT sale_date, cumulative_Sales, weekly_cumulative,
ROUND((cumulative_Sales - LAG(cumulative_Sales,7) OVER (Order by sale_date))*100/LAG(cumulative_Sales,7) OVER (Order by sale_date),2) AS sales_growth
FROM WORK.case_weekly_lemon_2013;

/*Question: On what date does the cumulative weekly sales growth drop below 10%?
Answer:  01/07/2013  

Question: How many days since the launch date did it take for cumulative sales growth
to drop below 10%?
Answer:  62   

219 Bat models were sold within first 30 days, whereas only 190 Lemon 2013 edition models were sold in first 30 days.
Hence, again launch timing (October) is not a potential cause for the drop.

Question: Is there a difference in the behavior in cumulative sales growth 
between the Bat edition and the 2013 Lemon edition?
Answer: One of the evident differences in the behavior in cumulative sales growth between the Bat edition and the 2013 Lemon edition is that 
	Lemon 2013’s cumulative sales in 1st week have been tremendously successful, with sales growth of 904% which unfortunately dropped 
        below 400% in second week. Also, sales growth has remained close to 10% for more than a month in case of Lemon 2013 edition but for 
        Bat edition the sales growth continuously declined. */



/***PART 2: MARKETING ANALYSIS***/

/*General Email & Sales Prep*/

/*Create a table called WORK.CASE_SALES_EMAIL that contains all of the email data
as well as both the sales_transaction_date and the product_id from sales.
Please use the WORK.CASE_SCOOT_SALES table to capture the sales information.*/
CREATE TABLE WORK.CASE_SALES_EMAIL AS 
SELECT e.*, s.product_id, s.sales_transaction_date
FROM ba710case.ba710_emails e
JOIN WORK.case_scooter_sales s
ON e.customer_id = s.customer_id;

/*Create two separate indexes for product_id and sent_date on the newly created
   WORK.CASE_SALES_EMAIL table.*/
CREATE INDEX product_idx ON WORK.CASE_SALES_EMAIL(product_id);
CREATE INDEX sent_date_idx ON WORK.CASE_SALES_EMAIL(sent_date);

/***Product email analysis****/

/*Bat emails 30 days prior to purchase
   Create a view of the previous table that:
   - contains only emails for the Bat scooter
   - contains only emails sent 30 days prior to the purchase date*/

DROP VIEW BAT_email_30;
CREATE VIEW BAT_email_30 AS 
		SELECT * 
        FROM WORK.CASE_SALES_EMAIL
        WHERE product_id = 7 and 
        DATEDIFF(DATE(sales_transaction_date),DATE(sent_date)) BETWEEN 1 AND 30 ;
        
/*Filter emails*/
/*There appear to be a number of general promotional emails not 
specifically related to the Bat scooter.  Create a new view from the 
view created above that removes emails that have the following text
in their subject.

Remove emails containing:
Black Friday
25% off all EVs
It's a Christmas Miracle!
A New Year, And Some New EVs*/

/*Question: How many rows are left in the relevant emails view.*/
/*Code:*/
DROP VIEW BAT_email_30_new;
CREATE VIEW BAT_email_30_new AS
	SELECT * 
	FROM bat_email_30
	WHERE email_subject NOT REGEXP "Black Friday|25% off all EVs|It's a Christmas Miracle!|A New Year, And Some New EVs";

/*Answer:   401 emails sent related to Bat scooter, 30 days prior to purchase date */

/*Question: How many emails were opened (opened='t')?*/
/*Code:*/

SELECT COUNT(*) 
FROM BAT_email_30_new
WHERE opened = 't';

/*Answer:  98 emails were opened    */


/*Question: What percentage of relevant emails (the view above) are opened?*/
/*Code:*/

SELECT 
ROUND((SELECT COUNT(*) FROM BAT_email_30_new WHERE opened = 't')*100/COUNT(*),2)
FROM bat_email_30_new
;
 
/*Answer:   Out of 401 customers who received an email, only 24.44% of customers opened the email */ 


/***Purchase email analysis***/
/*Question: How many distinct customers made a purchase (CASE_SCOOT_SALES)?*/
/*Code:*/

SELECT COUNT(DISTINCT customer_id)
FROM WORK.case_scooter_sales
WHERE product_id = 7;

/*Answer:  6659 customers purchases Bat edition scooter  */


/*Question: What is the percentage of distinct customers made a purchase after receiving an email?*/
/*Code:*/

SELECT concat(100*(401/6659), '%') AS purchase_after_email;

/*Answer: 6.0219% of customers made purchase after receiving an email related to Bat scooter  that was sent 30 days prior to purchase */
               
		
/*Question: What is the percentage of distinct customers that made a purchase 
    after opening an email?*/
/*Code:*/

SELECT concat(100*(98/6659), '%') AS purchase_after_opening_email;

/*Answer:   1.4717% of customers made purchase after opening an email related to Bat scooter that was sent 30 days prior to purchase  */

 
/*****LEMON 2013*****/
/*Complete a comparitive analysis for the Lemon 2013 scooter.  
Irrelevant/general subjects are:
25% off all EVs
Like a Bat out of Heaven
Save the Planet
An Electric Car
We cut you a deal
Black Friday. Green Cars.
Zoom 

/***Product email analysis****/
/*Lemon emails 30 days prior to purchase
   Create a view that:
   - contains only emails for the Lemon 2013 scooter
   - contains only emails sent 30 days prior to the purchase date */

CREATE VIEW Lemon2013_email_30 AS 
	SELECT * 
        FROM WORK.CASE_SALES_EMAIL
        WHERE product_id = 3 and 
        DATEDIFF(sales_transaction_date,sent_date) BETWEEN 1 AND 30;


/*Filter emails*/
/*There appear to be a number of general promotional emails not 
specifically related to the Lemon scooter.  Create a new view from the 
view created above that removes emails that have the following text
in their subject.

Remove emails containing:
25% off all EVs
Like a Bat out of Heaven
Save the Planet
An Electric Car
We cut you a deal
Black Friday. Green Cars.
Zoom */

CREATE VIEW Lemon2013_email_30_new AS
	SELECT *
	FROM Lemon2013_email_30
	WHERE email_subject NOT REGEXP "Black Friday. Green Cars.|25% off all EVs|Like a Bat out of Heaven|Save the Planet|An Electric Car|We cut you a deal";


/*Question: How many rows are left in the relevant emails view.*/
/*Code:*/
SELECT * FROM Lemon2013_email_30_new;

/*Answer:   576   */


/*Question: How many emails were opened (opened='t')?*/
/*Code:*/

SELECT COUNT(*) 
FROM Lemon2013_email_30_new
WHERE opened = 't';

/*Answer:   142       */


/*Question: What percentage of relevant emails (the view above) are opened?*/
/*Code:*/

SELECT 
ROUND((SELECT COUNT(*) FROM Lemon2013_email_30_new WHERE opened = 't')*100/COUNT(*),2)
FROM Lemon2013_email_30_new;
 
/*Answer:   24.70 %        */ 


/***Purchase email analysis***/
/*Question: How many distinct customers made a purchase (CASE_SCOOT_SALES)?*/
/*Code:*/

SELECT COUNT(DISTINCT customer_id)
FROM WORK.case_scooter_sales
WHERE product_id = 3;

/*Answer:   13854          */


/*Question: What is the percentage of distinct customers made a purchase after receiving an email?*/
/*Code:*/

SELECT 100*(Select count(distinct(customer_id)) from work.Lemon2013_email_30_new)/13854 AS purchase_after_email;

/*Answer:    4.1288      */
               
		
/*Question: What is the percentage of distinct customers that made a purchase 
    after opening an email?*/
/*Code:*/

SELECT concat(100*(142/13854), '%') AS purchase_after_opening_email; 

                
/*Answer:  1.0250% of customers made purchase after opening an email related to Lemon 2013 scooter that was sent 30 days prior to purchase        */

/** Email-marketing campaign for Bat scooter was more successful than Lemon 2013 models. Although, number of Lemon 2013 edition scooter sold is 
higher than Bat scooter sales but the conversion rate of email campaign for Bat model was higher. Percentage of customers who bought after opening emails
is almost 50 times higher for Bat scooters. Since the percentage of email opened in both campaigns is almost equal, the major difference in 
the percentage of customers with purchase after opening an email can be attributed to email campaign itself. So, Management should fine tune 
the email campaign for better conversion rate. **/

  
