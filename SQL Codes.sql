--STEP 1. Get an Overview of the data :
SELECT TOP(10)  * FROM dbo.dim_date
SELECT TOP(10)  * FROM dbo.electric_vehicle_sales_by_makers
SELECT TOP(10)  * FROM dbo.electric_vehicle_sales_by_state
SELECT TOP(10)  * FROM dbo.charging_stations

--Let's now see the structure of the tables and the data types of variables:
EXEC sp_help 'dbo.dim_date'
EXEC sp_help 'dbo.electric_vehicle_sales_by_makers'
EXEC sp_help 'dbo.electric_vehicle_sales_by_state' 
EXEC sp_help 'dbo.charging_stations' 

--Change the data type of the columns now:
--For Table 1
ALTER TABLE dbo.dim_date
ALTER COLUMN date date

--For Table 2
ALTER TABLE dbo.electric_vehicle_sales_by_makers
ALTER COLUMN date date

ALTER TABLE dbo.electric_vehicle_sales_by_makers
ALTER COLUMN electric_vehicles_sold int

--For Table 3
ALTER TABLE dbo.electric_vehicle_sales_by_state
ALTER COLUMN date date

ALTER TABLE dbo.electric_vehicle_sales_by_state
ALTER COLUMN electric_vehicles_sold int

ALTER TABLE dbo.electric_vehicle_sales_by_state
ALTER COLUMN total_vehicles_sold int

--For Table 4
ALTER TABLE dbo.charging_stations
ALTER COLUMN no_of_operational_charging_stations int


--STEP 2 Clean the Data:
--Remove null values:
--For Table 1
SELECT *
FROM dbo.dim_date
WHERE date IS NULL

--For Table 2
SELECT *
FROM dbo.electric_vehicle_sales_by_makers
WHERE date IS NULL

--For Table 3
SELECT *
FROM dbo.electric_vehicle_sales_by_state
WHERE date IS NULL

--As we can see there are no null values in the data.

--let's now remove duplicate values:
--For Table 1
SELECT date,
       fiscal_year,
	   quarter,
	   count(*) as duplicate_rows
FROM dbo.dim_date
group by date,fiscal_year,quarter
having COUNT(*)>1

--For Table 2
SELECT date,
       maker,
	   vehicle_category,
	   electric_vehicles_sold,
	   count(*) as duplicate_rows
FROM dbo.electric_vehicle_sales_by_makers
group by date, maker,vehicle_category,electric_vehicles_sold
having COUNT(*)>1

--For Table 3
SELECT date,
       state,
	   vehicle_category,
	   electric_vehicles_sold,
	   total_vehicles_sold,
	   count(*) as duplicate_rows
FROM dbo.electric_vehicle_sales_by_state
group by date, state,vehicle_category,electric_vehicles_sold,total_vehicles_sold
having COUNT(*)>1

--There are also no duplicate data in any table.

--STEP 3 Data Analysis:

/* Q1. List the top 3 and bottom 3 makers for the fiscal years 2023 and 2024 in 
       terms of the number of 2-wheelers sold.
*/
With Maker_Sales as 
      (SELECT maker,fiscal_year,sum(electric_vehicles_sold) as total_EV_sold,
             ROW_NUMBER() OVER(PARTITION BY fiscal_year ORDER BY SUM(electric_vehicles_sold) DESC) as Top_makers,
			 ROW_NUMBER() OVER (PARTITION BY fiscal_year ORDER BY SUM(electric_vehicles_sold) ASC) as Bottom_makers
	         FROM dbo.dim_date as A
	  JOIN dbo.electric_vehicle_sales_by_makers as B
	  ON A.fiscal_year = YEAR(B.date)
	  WHERE A.fiscal_year IN (2023,2024)
	  AND B.vehicle_category = '2-Wheelers'
	  GROUP BY maker,fiscal_year
	  )

SELECT maker,fiscal_year,total_EV_sold
FROM Maker_Sales
WHERE Top_makers <=3
OR Bottom_makers <= 3
ORDER BY fiscal_year,total_EV_sold DESC


/* Q2. Identify the top 5 states with the highest penetration rate in 2-wheeler 
       and 4-wheeler EV sales in FY 2024.
*/


SELECT TOP 5 state,
            vehicle_category,
			ROUND(SUM(CAST(electric_vehicles_sold as float))/SUM(total_vehicles_sold)*100,2) as penetration_rate
FROM dbo.dim_date as A
INNER JOIN dbo.electric_vehicle_sales_by_state as C
ON A.fiscal_year = YEAR(C.date)
WHERE fiscal_year = 2024
AND vehicle_category = '2-Wheelers'
GROUP BY state,vehicle_category
ORDER BY penetration_rate DESC



SELECT TOP 5 state,
            vehicle_category,
			ROUND(SUM(CAST(electric_vehicles_sold as float))/SUM(total_vehicles_sold)*100,2) as penetration_rate
FROM dbo.dim_date as A
INNER JOIN dbo.electric_vehicle_sales_by_state as C
ON A.fiscal_year = YEAR(C.date)
WHERE fiscal_year = 2024
AND vehicle_category = '4-Wheelers'
GROUP BY state,vehicle_category
ORDER BY penetration_rate DESC


/* Q3. List the states with negative penetration (decline) in EV sales from 2022 
       to 2024?
*/

WITH EV_sales as (
          SELECT state,
		         YEAR(date) as Year,
		         ROUND(SUM(CAST(electric_vehicles_sold as float))/SUM(total_vehicles_sold)*100,2) as penetration_rate
		  FROM dbo.electric_vehicle_sales_by_state
		  WHERE YEAR(date) IN (2022,2024)
		  GROUP BY state,YEAR(date)
		  )
SELECT E1.state,E1.penetration_rate as penetration_rate_2022,E2.penetration_rate as penetration_rate_2024
FROM EV_sales as E1
INNER JOIN EV_sales as E2
ON E1.state = E2.state
WHERE E1.Year = 2022
AND E2.Year = 2024
AND E1.penetration_rate >= E2.penetration_rate

/* Q4. What are the quarterly trends based on sales volume for the top 5 EV 
makers (4-wheelers) from 2022 to 2024?
*/

                         
WITH Top_makers as (SELECT TOP 5 maker,
			                    SUM(electric_vehicles_sold) as Sales_Volume
                    FROM dbo.electric_vehicle_sales_by_makers
                    WHERE vehicle_category = '4-Wheelers'
                    GROUP BY maker
                    ORDER BY Sales_Volume DESC)

SELECT maker,
      quarter,
	  SUM(electric_vehicles_sold) as Sales_Volume
FROM dbo.dim_date as A
INNER JOIN dbo.electric_vehicle_sales_by_makers as B
ON A.date = B.date
WHERE vehicle_category ='4-Wheelers'
AND B.maker IN (SELECT maker from Top_makers)
AND YEAR(B.date) IN (2022,2023,2024)
GROUP BY maker,quarter
ORDER BY maker,quarter,Sales_Volume DESC

/* Q5. How do the EV sales and penetration rates in Delhi compare to 
       Karnataka for 2024?
*/
SELECT state,
       SUM(electric_vehicles_sold) as EV_Sales,
	   ROUND(SUM(CAST(electric_vehicles_sold as float))/SUM(total_vehicles_sold)*100,2) as penetration_rate
FROM dbo.electric_vehicle_sales_by_state as C
INNER JOIN dbo.dim_date as A
ON C.date = A.date
WHERE state IN ('Delhi','Karnataka')
AND A.fiscal_year = 2024
GROUP BY state


/* Q6.  List down the compounded annual growth rate (CAGR) in 4-wheeler 
        units for the top 5 makers from 2022 to 2024.
*/
WITH sales_by_year as (
                      SELECT maker,
					         fiscal_year,
							 SUM(electric_vehicles_sold) as total_EV_sold
					  FROM dbo.electric_vehicle_sales_by_makers as B
					  INNER JOIN dbo.dim_date as A
					  ON B.date = A.date
					  WHERE A.fiscal_year IN (2022,2024)
					  AND vehicle_category = '4-Wheelers'
					  GROUP BY maker,fiscal_year)

,Year_2022_2024 as (
                   SELECT S2022.maker,
				          S2022.total_EV_sold as Begining_value,
						  S2024.total_EV_sold as Ending_value
					FROM sales_by_year as S2022
					INNER JOIN sales_by_year as S2024
					ON S2022.maker = S2024.maker
					WHERE S2022.fiscal_year = 2022
					AND S2024.fiscal_year = 2024)

,CAGR_calculation as (
                     SELECT maker,
					        Ending_value,
							Begining_value,
							ROUND(POWER(CAST(Ending_value as float)/NULLIF(Begining_value,0),1.0/2)-1,2)*100 as CAGR_percentage
					FROM Year_2022_2024
					)

,Top_5_makers as (
                  SELECT TOP 5 maker,
				             SUM(electric_vehicles_sold) as total_electric_vehicles_sold
				  FROM dbo.electric_vehicle_sales_by_makers as B
				  INNER JOIN dbo.dim_date as A
				  ON B.date = A.date
				  WHERE vehicle_category = '4-Wheelers'
				  AND A.fiscal_year = 2024
				  GROUP BY maker
				  )
SELECT CG.maker,concat(CG.CAGR_percentage,'%') as CAGR_percentage
FROM CAGR_calculation as CG
INNER JOIN Top_5_makers as T5
ON CG.maker = T5.maker
ORDER BY CG.CAGR_percentage DESC

/* Q7. List down the top 10 states that had the highest compounded annual 
       growth rate (CAGR) from 2022 to 2024 in total vehicles sold.
*/
WITH sales_by_year as (
                      SELECT state,
					         fiscal_year,
							 SUM(total_vehicles_sold) as total_sales
							 FROM dbo.electric_vehicle_sales_by_state as C
							 INNER JOIN dbo.dim_date as A
							 ON C.date = A.date
							 WHERE A.fiscal_year IN (2022,2024)
							 GROUP BY state,fiscal_year )

,sales_2022_2024 as (
                     SELECT S2022.state,
					        S2022.total_sales as Begining_value,
							S2024.total_sales as Ending_value
					 FROM sales_by_year as S2022
					 INNER JOIN sales_by_year as S2024
					 ON S2022.state = S2024.state
					 WHERE S2022.fiscal_year = 2022
					 AND S2024.fiscal_year = 2024 )

,CAGR_calculation as (
                      SELECT state,
					        ROUND(POWER(CAST(Ending_value as float)/NULLIF(Begining_value,0),1.0/2)-1,2)*100 as CAGR_percentage
					  FROM sales_2022_2024 )

,Top_10_states as (
                   SELECT TOP 10 state,
				             SUM(total_vehicles_sold) as total_sales
				   FROM dbo.electric_vehicle_sales_by_state as C
				   INNER JOIN dbo.dim_date as A
				   ON C.date = A.date
				   WHERE A.fiscal_year = 2022
				   GROUP BY state
				   ORDER BY total_sales DESC)

SELECT T10.state,concat(CG.CAGR_percentage,'%') as CAGR_percentage
FROM CAGR_calculation as CG
INNER JOIN Top_10_states as T10
ON CG.state = T10.state
ORDER BY CG.CAGR_percentage DESC

/* Q8. What are the peak and low season months for EV sales based on the 
       data from 2022 to 2024?
*/

SELECT YEAR(B.date) as Year,
       DATENAME(MONTH,B.date) as Month,
       SUM(electric_vehicles_sold) as total_vehicles_sold
FROM dbo.electric_vehicle_sales_by_makers as B
INNER JOIN dbo.dim_date as A
ON B.date = A.date
WHERE A.fiscal_year IN (2022,2023,2024)
GROUP BY YEAR(B.date),DATENAME(MONTH,B.date)
ORDER BY total_vehicles_sold DESC

/* Q9. What is the projected number of EV sales (including 2-wheelers and 4-
       wheelers) for the top 10 states by penetration rate in 2030, based on the 
       compounded annual growth rate (CAGR) from previous years?
*/

WITH Top_10_state as (
                     SELECT TOP 10 state,
					        ROUND(CAST(SUM(electric_vehicles_sold) as float)/SUM(total_vehicles_sold)*100,2) as penetration_rate
                     FROM dbo.electric_vehicle_sales_by_state
					 GROUP BY state
					 ORDER BY penetration_rate DESC )

,sales_by_year as (
                      SELECT state,
					         fiscal_year,
					         SUM(electric_vehicles_sold) as total_EV_sold
					  FROM dbo.electric_vehicle_sales_by_state as C
					  INNER JOIN dbo.dim_date as A
					  ON C.date = A.date
					  WHERE A.fiscal_year IN (2022,2024)
					  GROUP BY state,fiscal_year )

,sales_2022_2024 as ( 
                    SELECT S2022.state,
					       S2022.total_EV_sold as Begining_value,
						   S2024.total_EV_sold as Ending_value
					FROM sales_by_year as S2022
					INNER JOIN sales_by_year as S2024
					ON S2022.state = S2024.state
					WHERE S2022.fiscal_year = 2022
					AND S2024.fiscal_year = 2024 )

,CAGR_calculation as ( 
                       SELECT state,
					        ROUND(POWER(CAST(Ending_value as float)/NULLIF(Begining_value,0),1.0/2)-1,2)*100 as CAGR
					  FROM sales_2022_2024 )

,projection_2030 as (
                     SELECT CAGR_calculation.state,
					        ROUND(Ending_value * POWER(1 + (CAGR/100),6),0) as projected_2030_sales
					 FROM CAGR_calculation 
					 INNER JOIN sales_2022_2024
					 ON CAGR_calculation.state = sales_2022_2024.state
					 )

SELECT T10.state,p2030.projected_2030_sales
FROM Top_10_state as T10
INNER JOIN projection_2030 as p2030
ON T10.state = p2030.state
ORDER BY p2030.projected_2030_sales DESC

/* Q10. Estimate the revenue growth rate of 4-wheeler and 2-wheelers 
        EVs in India assuming an average unit price of Rs.85,000 for 2-Wheeler and Rs.1,50,000 for 4-Wheeler.
*/

WITH sales_by_year AS (
    SELECT 
        fiscal_year,
        vehicle_category,
        SUM(electric_vehicles_sold) AS total_EV_sales,
        CASE 
            WHEN vehicle_category = '2-Wheelers' THEN SUM(CAST(electric_vehicles_sold AS BIGINT)) * 85000 
            WHEN vehicle_category = '4-Wheelers' THEN SUM(CAST(electric_vehicles_sold AS BIGINT)) * 1500000 
            ELSE 0
        END AS total_revenue
    FROM 
        dbo.electric_vehicle_sales_by_state AS C
    INNER JOIN 
        dbo.dim_date AS A ON C.date = A.date
    WHERE 
        fiscal_year IN (2022, 2023, 2024)
    GROUP BY 
        fiscal_year, vehicle_category
)

, revenue_with_next_year AS (
    SELECT 
        fiscal_year,
        vehicle_category,
        total_revenue AS Revenue,
        LEAD(total_revenue) OVER (PARTITION BY vehicle_category ORDER BY fiscal_year) AS next_year_revenue
    FROM 
        sales_by_year
)

-- Final calculation of growth rate
SELECT 
    fiscal_year,
    vehicle_category,
    Revenue,

    CASE 
        -- For 2022, calculate growth rate from 2022 to 2023
        WHEN fiscal_year = 2022 THEN 
            ROUND((next_year_revenue - Revenue) / CAST(Revenue as float) * 100, 2) 
        
        -- For 2023, calculate growth rate from 2023 to 2024
        WHEN fiscal_year = 2023 THEN 
            ROUND((next_year_revenue - Revenue) / CAST(Revenue as float) * 100, 2)
        
        -- For 2024, set growth rate to 0
        WHEN fiscal_year = 2024 THEN 0
        
        ELSE NULL
    END AS growth_rate

FROM 
    revenue_with_next_year
ORDER BY 
    vehicle_category, fiscal_year;



/* Q11.  How does the availability of charging stations infrastructure correlate 
        with the EV sales in the top 5 states?  
*/

--number of charging station per 1000 electric vehicle for top 5 states:
SELECT top 5 C.state,
SUM(electric_vehicles_sold) as EV_Sales,
D.no_of_operational_charging_stations,
ROUND((D.no_of_operational_charging_stations /SUM(CAST(C.electric_vehicles_sold as float))) *1000,2) station_to_1000_EV_ratio
FROM dbo.electric_vehicle_sales_by_state as C
INNER JOIN dbo.charging_stations as D
ON C.state = D.State
GROUP BY C.state,D.no_of_operational_charging_stations
ORDER BY EV_Sales DESC
