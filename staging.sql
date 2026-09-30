create schema if not exists safari_connect;
set search_path to clean;

-- Staging table: ALL columns TEXT - accepts dirty data without failing
CREATE TABLE IF NOT EXISTS bookings_staging (
    booking_id       TEXT,
    passenger_name    TEXT, 
    passenger_phone  TEXT,
    passenger_gender TEXT, 
    passenger_city    TEXT, 
    route_code       TEXT,
    route_from       TEXT, 
    route_to          TEXT, 
    vehicle_plate    TEXT,
    vehicle_type     TEXT, 
    driver_name       TEXT, 
    driver_rating    TEXT,
    departure_date   TEXT, 
    departure_time    TEXT, 
    seat_class       TEXT,
    seats_booked     TEXT, 
    fare_per_seat     TEXT, 
    total_fare       TEXT,
    payment_method   TEXT, 
    booking_status    TEXT, 
    trip_rating      TEXT
);

--- verify import
select * from bookings_staging;
select count(*) from bookings_staging; --count the total rows (290)


-- data profiling
-- 1. Naming case profiles
select distinct passenger_name
from bookings_staging
order by passenger_name; 
--- we had a total of 290 rows but 54 distict dirty passenger names (casing normalization needed and trimmings)

-- 2. Gender
select distinct 
	passenger_gender,
	Count(*) as gender_count
from bookings_staging
group by passenger_gender
order by gender_count desc;
--- Gender naming normalization is needed

-- 3. passenger_city
select distinct
	passenger_city,
	count(*) as city_count
from bookings_staging
group by passenger_city
order by city_count;
-- Audited the passengers by distinct cities and had a row_count note is that we have blanks and needs naming normalization as well

-- 4. route_to
select distinct
	route_to,
	count(*) as route_count
from bookings_staging
group by route_to
order by route_count desc;

-- 5. route_from
select distinct
	route_from,
	count(*) as route_count
from bookings_staging
group by route_from
order by route_count desc;

-- route_to and route_from do not need major changes they are well normalized

-- 6. vehicle_type

select distinct
	vehicle_type,
	count(*) as vehicle_count
from bookings_staging
group by vehicle_type
order by vehicle_count desc;

--- vehicle types need normalization especially or the naming modalities and casing as well  

--  7. driver_name

select distinct
	driver_name,
	count(*) as driver_count
from bookings_staging
group by driver_name
order by driver_count desc;

--- driver naming casing needs normalization


-- 8. seat_class variants
SELECT DISTINCT 
	seat_class, 
	COUNT(*) 
FROM bookings_staging 
GROUP BY seat_class;

--naming or seat classes needes normalized naming


-- 9. payment_method variants
SELECT DISTINCT payment_method FROM bookings_staging;


-- 10. Date format problems
SELECT
    CASE
        WHEN departure_date ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'
            THEN 'YYYY-MM-DD'

        WHEN departure_date ~ '^[0-9]{2}/[0-9]{2}/[0-9]{4}$'
            THEN 'DD/MM/YYYY'

        WHEN departure_date ~ '^[0-9]{4}/[0-9]{2}/[0-9]{2}$'
            THEN 'YYYY/MM/DD'

        WHEN departure_date ~ '^[0-9]{2}-[0-9]{2}-[0-9]{4}$'
            THEN 'DD-MM-YYYY'

        WHEN departure_date IS NULL
            THEN 'NULL'

        WHEN TRIM(departure_date) = ''
            THEN 'BLANK'

        ELSE 'OTHER/INVALID'
    END AS date_format,
    COUNT(*) AS occurrences
FROM bookings_staging
GROUP BY date_format
ORDER BY occurrences DESC;

-- we have 2 date formats the DD/MM/YYY with 281 occurences and then the DD-MM-YYYY with 9 occurences


-- 10. Phone format problems
SELECT 
	booking_id, 
	passenger_phone 
FROM bookings_staging
WHERE passenger_phone 
	LIKE '+254%' OR passenger_phone LIKE '%-%';

-- 11. Fares stored as text
SELECT 
	booking_id, 
	total_fare, 
	fare_per_seat 
FROM bookings_staging
WHERE total_fare 
	LIKE 'KES%' OR fare_per_seat LIKE 'KES%';

-- 12. Invalid trip ratings
SELECT 
	booking_id, 
	trip_rating 
FROM bookings_staging
WHERE trip_rating 
	NOT IN ('1','2','3','4','5','');

-- 13. Duplicate booking_ids
SELECT 
	booking_id, 
	COUNT(*) 
FROM bookings_staging
GROUP BY booking_id 
HAVING COUNT(*) > 1;

-- 14. Negative seats_booked
SELECT 
	booking_id, 
	seats_booked 
FROM bookings_staging
WHERE NULLIF(REGEXP_REPLACE(seats_booked,'[^0-9-]','','g'),'')::INTEGER < 1;

--- there is 1 negatively booked seat


---This is the end of data profiling for safari_connect we are moving to data cleaning in the clean schema























































