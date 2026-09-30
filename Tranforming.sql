create schema if not exists clean;
set search_path to clean;
--- This schema will contain the cleaning script and the clean data tables

CREATE TABLE IF NOT EXISTS clean.bookings (
    booking_id       VARCHAR(50) primary key,
    passenger_name   VARCHAR(150),
    passenger_phone  VARCHAR(20),
    passenger_gender VARCHAR(20),
    passenger_city   VARCHAR(100),
    route_code       VARCHAR(50),
    route_from       VARCHAR(100),
    route_to         VARCHAR(100),
    vehicle_plate    VARCHAR(20),
    vehicle_type     VARCHAR(50),
    driver_name      VARCHAR(150),
    driver_rating    NUMERIC(3,2),
    departure_date   DATE,
    departure_time   TIME,
    seat_class       VARCHAR(50),
    seats_booked     INTEGER,
    fare_per_seat    NUMERIC(12,2),
    total_fare       NUMERIC(12,2),
    payment_method   VARCHAR(50),
    booking_status   VARCHAR(50),
    trip_rating      INTEGER
);


--1. clean the passager name by trimming, INITCAP and regexP_replace to remove the spaces in btween normalize capitalization and remove trailing spaces and then loading it into the clean data table

SELECT
    booking_id,
    INITCAP(
        REGEXP_REPLACE(
            TRIM(passenger_name),
            '\s+',
            ' ',
            'g'
        )
    ) AS cleaned_name
FROM bookings_staging;


--2. we need to normalize gender naming into only male and female

SELECT
    booking_id,
    CASE
        WHEN LOWER(TRIM(passenger_gender)) IN ('m', 'male', 'Male', 'MALE', 'M')
            THEN 'Male'

        WHEN LOWER(TRIM(passenger_gender)) IN ('f', 'female', 'FEMALE', 'F', 'Female')
            THEN 'Female'

        WHEN passenger_gender IS NULL
            THEN NULL

        WHEN TRIM(passenger_gender) = ''
            THEN NULL

        ELSE NULL
    END AS cleaned_gender
FROM bookings_staging;
	

---3. passanger city normalizayoon and blanks solvings
SELECT
    booking_id,
    CASE
        WHEN LOWER(TRIM(passenger_city)) = 'eldoret'
            THEN 'Eldoret'

        WHEN LOWER(TRIM(passenger_city)) = 'kisumu'
            THEN 'Kisumu'

        WHEN LOWER(TRIM(passenger_city)) = 'meru'
            THEN 'Meru'

        WHEN LOWER(TRIM(passenger_city)) = 'nyeri'
            THEN 'Nyeri'

        WHEN LOWER(TRIM(passenger_city)) = 'nakuru'
            THEN 'Nakuru'

        WHEN LOWER(TRIM(passenger_city)) = 'thika'
            THEN 'Thika'

        WHEN LOWER(TRIM(passenger_city)) = 'mombasa'
            THEN 'Mombasa'

        WHEN LOWER(TRIM(passenger_city)) = 'nairobi'
            THEN 'Nairobi'

        ELSE NULL
    END AS cleaned_city
FROM bookings_staging;
	
--- 4. vehicle_type case normalization

select 
	booking_id,
	case 
		when lower(trim(vehicle_type)) in ('Bus', 'bus') then ('Bus')
		when lower(trim(vehicle_type)) in ('Matatu', 'matatu') then ('Matatu')
		when lower(trim(vehicle_type)) in ('minibus', 'Minibus') then('Minibus')
		when vehicle_type is null then null 
		when trim(vehicle_type) = '' then null 
		else null
	end as clean_vehicle_type
from bookings_staging;

--- 5. casing normalization in driver naming 

SELECT
    booking_id,
    INITCAP(
        REGEXP_REPLACE(
            TRIM(driver_name),
            '\s+',
            ' ',
            'g'
        )
    ) AS clean_driver
FROM bookings_staging;

--- 6. seat_class variants normalization
SELECT
    booking_id,
    CASE
        WHEN LOWER(TRIM(seat_class)) IN
            ('bus', 'business', 'business class')
            THEN 'Business'

        WHEN LOWER(TRIM(seat_class)) IN
            ('eco', 'economy', 'economy class')
            THEN 'Economy'

        WHEN TRIM(seat_class) = ''
            THEN NULL

        WHEN seat_class IS NULL
            THEN NULL

        ELSE NULL
    END AS clean_class
FROM bookings_staging;

---7.  payment method variants casing normalization


select
	booking_id,
	case 
		when lower(trim(payment_method)) in ('mpesa',  'm-pesa') then ('mpesa')
		when lower(trim(payment_method)) in ('cash') then ('cash')
		when lower(trim(payment_method)) in ('card') then ('card')
		when payment_method is null then null 
		when trim(payment_method) = '' then null 
		else null 
	end as clean_payments 
from bookings_staging
	
--- 8. phone number normalization 
SELECT
    booking_id,
    CASE
        -- NULL or blank
        WHEN passenger_phone IS NULL
            THEN NULL

        WHEN TRIM(passenger_phone) = ''
            THEN NULL

        -- Kenyan +254 format
        WHEN TRIM(passenger_phone) LIKE '+254%'
            THEN '0' || SUBSTRING(
                REGEXP_REPLACE(TRIM(passenger_phone), '[^0-9]', '', 'g'),
                4
            )

        -- All other phone numbers: remove non-numeric characters
        ELSE REGEXP_REPLACE(
            TRIM(passenger_phone),
            '[^0-9]',
            '',
            'g'
        )
    END AS cleaned_phone
FROM bookings_staging;

--- 9.  date fromating  

SELECT
    booking_id,
    CASE

        -- DD/MM/YYYY
        WHEN departure_date LIKE '%/%'
            THEN TO_DATE(
                departure_date,
                'DD/MM/YYYY'
            )

        -- DD-MM-YY
        WHEN departure_date LIKE '%-%'
             AND LENGTH(departure_date) = 8
            THEN TO_DATE(
                departure_date,
                'DD-MM-YY'
            )

        -- MM-DD-YYYY
        WHEN departure_date LIKE '%-%'
             AND LENGTH(departure_date) = 10
             AND SPLIT_PART(departure_date, '-', 2)::INTEGER > 12
            THEN TO_DATE(
                departure_date,
                'MM-DD-YYYY'
            )

        ELSE NULL

    END AS cleaned_departure_date

FROM bookings_staging;

	

---10. booking status

SELECT
    booking_id,
    CASE
        WHEN UPPER(TRIM(booking_status)) = 'COMPLETED'
            THEN 'Completed'

        WHEN UPPER(TRIM(booking_status)) = 'CANCELLED'
            THEN 'Cancelled'

        WHEN UPPER(TRIM(booking_status)) = 'NO SHOW'
            THEN 'No Show'

        ELSE NULL
    END AS cleaned_status

FROM bookings_staging; 

--- fare per seat and total fare and conversion to numeric 
SELECT
    booking_id,

    CAST(
        REGEXP_REPLACE(
            total_fare,
            '[^0-9.]',
            '',
            'g'
        ) AS NUMERIC
    ) AS cleaned_total_fare,

    CAST(
        REGEXP_REPLACE(
            fare_per_seat,
            '[^0-9.]',
            '',
            'g'
        ) AS NUMERIC
    ) AS cleaned_fare_per_seat

FROM bookings_staging;


--- trip ratings  
SELECT
    booking_id,
    CASE
        WHEN TRIM(trip_rating) IN ('1', '2', '3', '4', '5')
            THEN TRIM(trip_rating):: integer 

        ELSE NULL
    END AS cleaned_trip_rating

FROM bookings_staging;

--driver ratings 
SELECT
    booking_id,
    driver_rating::numeric driver_rating 
FROM bookings_staging;

--- set the negative seats as nulls  
SELECT
    booking_id,
    CASE
        WHEN NULLIF(
            REGEXP_REPLACE(
                seats_booked,
                '[^0-9-]',
                '',
                'g'
            ),
            ''
        )::INTEGER >= 1
        THEN NULLIF(
            REGEXP_REPLACE(
                seats_booked,
                '[^0-9-]',
                '',
                'g'
            ),
            ''
        )::INTEGER

        ELSE NULL
    END AS cleaned_seats

FROM bookings_staging;


--- remove duplicates 
SELECT *
FROM (
    SELECT
        b.*,
        ROW_NUMBER() OVER (
            PARTITION BY
                booking_id,
                passenger_name,
                passenger_phone,
                passenger_city,
                driver_name,
                seat_class,
                payment_method,
                departure_date,
                booking_status,
                fare_per_seat,
                total_fare,
                trip_rating,
                seats_booked
            ORDER BY ctid
        ) AS row_num
    FROM bookings_staging b
) x
WHERE row_num = 1;





CREATE OR REPLACE view v_clean_trips   AS
SELECT *,
    TO_CHAR(departure_date, 'YYYY-MM')    AS travel_month,
    TO_CHAR(departure_date, 'Month YYYY') AS month_label,
    TO_CHAR(departure_date, 'Day')        AS day_name,
    EXTRACT(MONTH FROM departure_date)    AS month_num,
    EXTRACT(DOW FROM departure_date)      AS day_of_week,
    (fare_per_seat * seats_booked)           AS calculated_fare,
    CASE
        WHEN trip_rating BETWEEN 4 AND 5 THEN 'Satisfied'
        WHEN trip_rating = 3 THEN 'Neutral'
        WHEN trip_rating BETWEEN 1 AND 2 THEN 'Unsatisfied'
        ELSE 'No Rating'
    END AS satisfaction
FROM clean.bookings
WHERE booking_status = 'Completed';

-- Test
SELECT * FROM v_clean_trips LIMIT 10;





















