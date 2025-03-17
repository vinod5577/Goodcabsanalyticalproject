#Business requirements : 
-- 1 : city level fare and trip summary
/* this report displays the total_trips, average fare per km, average fare per trip, and the percentage contribution pf each city
trips to overall trips. This report will help in assessing trip volume, pricing efficincy, and each city's contribution to the 
overall trip count.
Fields : city_name, total_trips, avg_fare_per_km, avg_fare_per_trip, %_contribution_to_total_trips */

select 
	c.city_name as city_name,
    count(t.trip_id) as total_trips,
    sum(fare_amount) as total_fare_amount,
    round(sum(fare_amount)/sum(distance_travelled_km),2) as avg_fare_per_km,
    round(sum(fare_amount)/count(t.trip_id),2) as avg_fare_per_trip,
    concat(round((sum(fare_amount)/(select sum(fare_amount) from trips_db.fact_trips))*100,2),"%") as contribution_to_total_trips
from trips_db.dim_city c
left join trips_db.fact_trips t
on c.city_id = t.city_id
group by c.city_id;

-- 2 : monthly City-Level Trips Target Performance Report

/* This report evaluates the target performance for trips at the monthly and city level. For each city and month, compares
the actual total trips with the target trips and categorize the performance as follows:
    * If actual trips are greater than target trips, mark it as  "Above Target".
    * If actual trips are than or equal to target trips, mark it as "Below Target".
Fields : City_name, month_name, actual_trips, target_trips, performance_status, %_difference */

select 
	c.city_name as city,
    monthname(t.date) as "month",
    count(t.trip_id) as "actual_trips",
    tt.total_target_trips as "target_trips",
    case
		when count(t.trip_id)>=tt.total_target_trips then "Above target"
        when count(t.trip_id)<tt.total_target_trips then "Below target"
	end as Perfomance_status,
    concat(round((count(t.trip_id)-tt.total_target_trips)/tt.total_target_trips*100,2),"%") as "%_difference"
from trips_db.dim_city c
left join trips_db.fact_trips t
on c.city_id = t.city_id
left join targets_db.monthly_target_trips tt
on monthname(t.date) = monthname(tt.month) and t.city_id = tt.city_id
group by c.city_id,monthname(t.date);


-- 3 City - Level Repeat Passenger Trip Frequency Report 

/* This report will help identify cities with high repeat trip frequency, which can indicate strong customer loyalty or 
frequent usage patterns.
fields : city_name, 2-trips, 3-trips, 4-trips, 5-trips, 6-trips, 7-trips, 8-trips, 9-trips, 10-trips */

SELECT 
    dc.city_name,
    CONCAT(ROUND(COALESCE(SUM(CASE WHEN drt.trip_count = '2-Trips' THEN drt.repeat_passenger_count END) / SUM(drt.repeat_passenger_count) * 100, 0), 2), '%') AS `2-Trips`,
    CONCAT(ROUND(COALESCE(SUM(CASE WHEN drt.trip_count = '3-Trips' THEN drt.repeat_passenger_count END) / SUM(drt.repeat_passenger_count) * 100, 0), 2), '%') AS `3-Trips`,
    CONCAT(ROUND(COALESCE(SUM(CASE WHEN drt.trip_count = '4-Trips' THEN drt.repeat_passenger_count END) / SUM(drt.repeat_passenger_count) * 100, 0), 2), '%') AS `4-Trips`,
    CONCAT(ROUND(COALESCE(SUM(CASE WHEN drt.trip_count = '5-Trips' THEN drt.repeat_passenger_count END) / SUM(drt.repeat_passenger_count) * 100, 0), 2), '%') AS `5-Trips`,
    CONCAT(ROUND(COALESCE(SUM(CASE WHEN drt.trip_count = '6-Trips' THEN drt.repeat_passenger_count END) / SUM(drt.repeat_passenger_count) * 100, 0), 2), '%') AS `6-Trips`,
    CONCAT(ROUND(COALESCE(SUM(CASE WHEN drt.trip_count = '7-Trips' THEN drt.repeat_passenger_count END) / SUM(drt.repeat_passenger_count) * 100, 0), 2), '%') AS `7-Trips`,
    CONCAT(ROUND(COALESCE(SUM(CASE WHEN drt.trip_count = '8-Trips' THEN drt.repeat_passenger_count END) / SUM(drt.repeat_passenger_count) * 100, 0), 2), '%') AS `8-Trips`,
    CONCAT(ROUND(COALESCE(SUM(CASE WHEN drt.trip_count = '9-Trips' THEN drt.repeat_passenger_count END) / SUM(drt.repeat_passenger_count) * 100, 0), 2), '%') AS `9-Trips`,
    CONCAT(ROUND(COALESCE(SUM(CASE WHEN drt.trip_count = '10-Trips' THEN drt.repeat_passenger_count END) / SUM(drt.repeat_passenger_count) * 100, 0), 2), '%') AS `10-Trips`
FROM trips_db.dim_repeat_trip_distribution drt
JOIN trips_db.dim_city dc ON drt.city_id = dc.city_id
GROUP BY dc.city_name;


-- 4 : Identifies Cities with highest and lowest new passengers

/* this report calculates total new passengers for each city and ranks them based on this value. Identifies the top 3 cities
with the highest number of passengers as well as the bottom 3 cities with lowest number of new passengers, categorising 
them as Top 3 and bottom 3 accordingly.
field : city_name, total_new_passengers, city_category(top 3, bottom 3) */

WITH NewPassengerCounts AS (
    SELECT 
        dc.city_name,
        COUNT(ft.trip_id) AS total_new_passengers
    FROM trips_db.fact_trips ft
    JOIN trips_db.dim_city dc ON ft.city_id = dc.city_id
    WHERE ft.passenger_type = 'New'
    GROUP BY dc.city_name
), RankedCities AS (
    SELECT 
        city_name, 
        total_new_passengers,
        RANK() OVER (ORDER BY total_new_passengers DESC) AS rank_highest,
        RANK() OVER (ORDER BY total_new_passengers ASC) AS rank_lowest
    FROM NewPassengerCounts
)
SELECT 
    city_name, 
    total_new_passengers,
    CASE 
        WHEN rank_highest <= 3 THEN 'Top 3'
        WHEN rank_lowest <= 3 THEN 'Bottom 3'
        ELSE NULL 
    END AS city_category
FROM RankedCities
WHERE rank_highest <= 3 OR rank_lowest <= 3;

 
 
 -- 5 : Identifies the Month with highest revenue for each city 
 
 /* this report identifies the month with the highest revenue for each city. for each city, display the month_name, 
 the revenue amount for that month, and the percentage contribution of that month's revenue to the city's total revenue. */

WITH MonthlyRevenue AS (
    SELECT 
        dc.city_name,
        DATE_FORMAT(ft.date, '%Y-%m') AS revenue_month,
        SUM(ft.fare_amount) AS total_revenue,
        SUM(SUM(ft.fare_amount)) OVER (PARTITION BY dc.city_name) AS city_total_revenue
    FROM trips_db.fact_trips ft
    JOIN trips_db.dim_city dc ON ft.city_id = dc.city_id
    GROUP BY dc.city_name, revenue_month
), RankedRevenue AS (
    SELECT 
        city_name, 
        revenue_month,
        total_revenue,
        city_total_revenue,
        RANK() OVER (PARTITION BY city_name ORDER BY total_revenue DESC) AS revenue_rank
    FROM MonthlyRevenue
)
SELECT 
    city_name,
    DATE_FORMAT(STR_TO_DATE(revenue_month, '%Y-%m'), '%M %Y') AS highest_revenue_month,
    total_revenue AS revenue,
    CONCAT(ROUND((total_revenue / city_total_revenue) * 100, 2), '%') AS percentage_contribution
FROM RankedRevenue
WHERE revenue_rank = 1;



-- 6 : Repeat passenger rate 
/* this report calculates two metrics.
1.monthly repeat passenger rate : calculates the repeat passenger rate for each city and month by comparing the 
number of repeat passengers to the total passengers.
2. city-wide repeat passenger rate : calculates the  overall  repeat passenger rate for each city considering  the 
passengers across months these metrics provides insights into monthly repeat trends as well as the overall repeat 
behaviour for each  city.
fields  : city_name, month, total_passengers, repeat_passengers, monthly_repeat_passengers_rate(%), 
city_repeat_passenger_rate(%) */

with monthly_repeat_passenger_rate as
(
SELECT 
		dc.city_id as city_id,
        dc.city_name as city_name,
        monthname(fps.month) as month,
        fps.total_passengers as total_monthly_passengers,
        fps.repeat_passengers as monthly_repeat_passengers,
        concat(round((fps.repeat_passengers/fps.total_passengers)*100,2),"%") as "monthly_repeat_passenger_rate"
FROM trips_db.fact_passenger_summary fps
right JOIN trips_db.dim_city dc ON fps.city_id = dc.city_id
GROUP BY dc.city_name,monthname(fps.month)
), city_wide_repeat_passenger_rate as
(
SELECT 
		dc.city_id as city_id,
        dc.city_name as city_name,
        sum(fps.total_passengers) as total_passengers,
        sum(fps.repeat_passengers) as total_repeat_passengers,
        concat(round((sum(fps.repeat_passengers)/sum(fps.total_passengers))*100,2),"%") as "city_repeat_passenger_rate"
FROM trips_db.fact_passenger_summary fps
right JOIN trips_db.dim_city dc ON fps.city_id = dc.city_id
GROUP BY dc.city_name
)
select 
	mrpr.city_name,
    mrpr.month,
	mrpr.total_monthly_passengers,
    mrpr.monthly_repeat_passengers,
    mrpr.monthly_repeat_passenger_rate,
    cwrpr.city_repeat_passenger_rate
from monthly_repeat_passenger_rate mrpr
left join city_wide_repeat_passenger_rate cwrpr
on mrpr.city_id = cwrpr.city_id;




