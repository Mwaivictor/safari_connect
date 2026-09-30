/* ============================================================
   SAFARI CONNECT
   BUSINESS ANALYSIS - 6 QUESTIONS + BI VIEWS + INDEXES
   Runs on clean.bookings / v_clean_trips (see loading.sql, Tranforming.sql)
   ============================================================ */

SET search_path TO clean;


/* ============================================================
   Q1. ROUTE ANALYSIS
   Which routes earn the most? Which are most popular?
   Which is most efficient per seat sold?
   ============================================================ */

-- 1A. Revenue and bookings by route
SELECT
    route_code,
    route_from || '->' || route_to          AS route,
    COUNT(*)                                AS total_bookings,
    SUM(seats_booked)                       AS total_seats,
    SUM(calculated_fare)                    AS total_revenue,
    ROUND(AVG(fare_per_seat), 2)            AS avg_fare,
    ROUND(AVG(trip_rating), 2)              AS avg_trip_rating
FROM v_clean_trips
GROUP BY route_code, route_from, route_to
ORDER BY total_revenue DESC;

-- 1B + 1C. Revenue per seat, revenue rank and share of total (CTE + window functions)
WITH route_rev AS (
    SELECT
        route_code,
        route_from || '->' || route_to      AS route,
        SUM(calculated_fare)                AS revenue,
        SUM(seats_booked)                   AS seats
    FROM v_clean_trips
    GROUP BY route_code, route_from, route_to
)
SELECT
    route_code,
    route,
    revenue,
    seats,
    ROUND(revenue / NULLIF(seats, 0), 2)                AS revenue_per_seat,
    RANK() OVER (ORDER BY revenue DESC)                 AS revenue_rank,
    ROUND(revenue * 100.0 / SUM(revenue) OVER (), 1)    AS pct_of_total
FROM route_rev
ORDER BY revenue_rank;

-- 1D. Vehicle type performance
SELECT
    vehicle_type,
    COUNT(*)                                AS total_bookings,
    SUM(seats_booked)                       AS total_seats,
    SUM(calculated_fare)                    AS total_revenue,
    ROUND(AVG(trip_rating), 2)              AS avg_trip_rating
FROM v_clean_trips
GROUP BY vehicle_type
ORDER BY total_revenue DESC;


/* ============================================================
   Q2. DRIVER PERFORMANCE
   Who are the best drivers? Does driver rating affect satisfaction?
   ============================================================ */

-- 2A + 2B. Driver totals, overall rank and rank within vehicle type
WITH driver_totals AS (
    SELECT
        driver_name,
        vehicle_type,
        COUNT(*)                            AS total_trips,
        SUM(seats_booked)                   AS total_seats_carried,
        SUM(calculated_fare)                AS total_revenue,
        ROUND(AVG(trip_rating), 2)          AS avg_passenger_rating,
        MAX(driver_rating)                  AS driver_rating
    FROM v_clean_trips
    GROUP BY driver_name, vehicle_type
)
SELECT
    *,
    RANK() OVER (ORDER BY total_revenue DESC)                          AS overall_rank,
    RANK() OVER (PARTITION BY vehicle_type ORDER BY total_revenue DESC) AS vehicle_rank
FROM driver_totals
ORDER BY overall_rank;

-- 2C. Does a high driver rating predict happier passengers?
SELECT
    CASE WHEN driver_rating >= 4.5 THEN 'High-rated (>= 4.5)'
         ELSE 'Standard (< 4.5)'
    END                                     AS driver_group,
    COUNT(DISTINCT driver_name)             AS drivers,
    COUNT(*)                                AS trips,
    ROUND(AVG(trip_rating), 2)              AS avg_passenger_rating
FROM v_clean_trips
GROUP BY 1;

-- 2D. Correlation between driver rating and trip rating
SELECT ROUND(CORR(driver_rating, trip_rating)::NUMERIC, 3) AS rating_correlation
FROM v_clean_trips;

-- 2E. Cancellation / no-show rate per driver (all bookings)
SELECT
    driver_name,
    COUNT(*)                                AS total_bookings,
    ROUND(SUM(CASE WHEN booking_status <> 'Completed' THEN 1 ELSE 0 END)
          * 100.0 / COUNT(*), 1)            AS lost_booking_rate_pct
FROM clean.bookings
GROUP BY driver_name
ORDER BY lost_booking_rate_pct DESC;


/* ============================================================
   Q3. REVENUE TRENDS
   How is revenue changing month by month?
   ============================================================ */

-- 3A + 3B. Monthly revenue, MoM change (LAG) and running total
WITH monthly AS (
    SELECT
        travel_month                        AS month,
        COUNT(*)                            AS bookings,
        SUM(calculated_fare)                AS revenue
    FROM v_clean_trips
    GROUP BY travel_month
)
SELECT
    month,
    bookings,
    revenue,
    LAG(revenue) OVER (ORDER BY month)                              AS prev_month,
    revenue - LAG(revenue) OVER (ORDER BY month)                    AS change,
    ROUND((revenue - LAG(revenue) OVER (ORDER BY month))
          / NULLIF(LAG(revenue) OVER (ORDER BY month), 0) * 100, 1) AS change_pct,
    SUM(revenue) OVER (ORDER BY month)                              AS running_total
FROM monthly
ORDER BY month;

-- 3C. Best and worst 3 months (full months only - Jan 2025 has 4 days of data)
WITH monthly AS (
    SELECT travel_month AS month, SUM(calculated_fare) AS revenue
    FROM v_clean_trips
    WHERE departure_date < DATE '2025-01-01'
    GROUP BY travel_month
),
ranked AS (
    SELECT
        month,
        revenue,
        RANK() OVER (ORDER BY revenue DESC) AS best_rank,
        RANK() OVER (ORDER BY revenue ASC)  AS worst_rank
    FROM monthly
)
SELECT month, revenue,
       CASE WHEN best_rank <= 3 THEN 'Top 3' ELSE 'Bottom 3' END AS bucket
FROM ranked
WHERE best_rank <= 3 OR worst_rank <= 3
ORDER BY revenue DESC;

-- 3D. Monthly revenue pivot for the top 3 routes
SELECT
    travel_month,
    SUM(CASE WHEN route_code = 'RT001' THEN calculated_fare ELSE 0 END) AS rt001_mombasa,
    SUM(CASE WHEN route_code = 'RT004' THEN calculated_fare ELSE 0 END) AS rt004_eldoret,
    SUM(CASE WHEN route_code = 'RT002' THEN calculated_fare ELSE 0 END) AS rt002_kisumu
FROM v_clean_trips
GROUP BY travel_month
ORDER BY travel_month;


/* ============================================================
   Q4. PASSENGER INSIGHTS
   Where do passengers come from? Class preference? Satisfaction?
   ============================================================ */

-- 4A. Top passenger cities (3+ bookings)
SELECT
    COALESCE(passenger_city, 'Unknown')     AS passenger_city,
    COUNT(*)                                AS total_bookings,
    SUM(seats_booked)                       AS total_seats,
    SUM(calculated_fare)                    AS total_revenue,
    ROUND(AVG(total_fare), 2)               AS avg_booking_value
FROM v_clean_trips
GROUP BY COALESCE(passenger_city, 'Unknown')
HAVING COUNT(*) >= 3
ORDER BY total_bookings DESC;

-- 4B. Gender x seat class (CASE WHEN pivot)
SELECT
    COALESCE(passenger_gender, 'Unknown')                       AS gender,
    COUNT(*)                                                    AS bookings,
    SUM(CASE WHEN seat_class = 'Economy'  THEN 1 ELSE 0 END)    AS economy,
    SUM(CASE WHEN seat_class = 'Business' THEN 1 ELSE 0 END)    AS business,
    SUM(calculated_fare)                                        AS revenue
FROM v_clean_trips
GROUP BY COALESCE(passenger_gender, 'Unknown');

-- 4C. Satisfaction breakdown (CTE + percentage of total)
WITH sat_counts AS (
    SELECT satisfaction, COUNT(*) AS cnt
    FROM v_clean_trips
    GROUP BY satisfaction
)
SELECT
    satisfaction,
    cnt,
    ROUND(cnt * 100.0 / SUM(cnt) OVER (), 1) AS pct
FROM sat_counts
ORDER BY cnt DESC;

-- 4D. Passenger spend quartiles (NTILE)
WITH spend AS (
    SELECT passenger_name, COUNT(*) AS trips, SUM(total_fare) AS total_spent
    FROM v_clean_trips
    GROUP BY passenger_name
)
SELECT
    passenger_name,
    trips,
    total_spent,
    NTILE(4) OVER (ORDER BY total_spent)    AS quartile,
    CASE WHEN NTILE(4) OVER (ORDER BY total_spent) = 4
         THEN 'Top Spender' END             AS label
FROM spend
ORDER BY total_spent DESC;

-- 4E. Payment method mix
SELECT
    COALESCE(payment_method, 'Unknown')     AS payment_method,
    COUNT(*)                                AS bookings,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 1) AS pct
FROM v_clean_trips
GROUP BY 1
ORDER BY bookings DESC;


/* ============================================================
   Q5. CANCELLATIONS & LOST REVENUE
   Runs on clean.bookings - v_clean_trips only holds Completed trips
   ============================================================ */

-- 5A. Overall status breakdown
SELECT
    booking_status,
    COUNT(*)                                            AS bookings,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2)  AS pct,
    SUM(total_fare)                                     AS fare_value
FROM clean.bookings
GROUP BY booking_status;

-- 5B. Cancellation rate by route
SELECT
    route_code,
    route_from || '->' || route_to                                  AS route,
    COUNT(*)                                                        AS total,
    SUM(CASE WHEN booking_status = 'Completed' THEN 1 ELSE 0 END)   AS completed,
    SUM(CASE WHEN booking_status = 'Cancelled' THEN 1 ELSE 0 END)   AS cancelled,
    SUM(CASE WHEN booking_status = 'No Show'   THEN 1 ELSE 0 END)   AS no_show,
    ROUND(SUM(CASE WHEN booking_status IN ('Cancelled', 'No Show')
                   THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 1)        AS cancel_rate_pct
FROM clean.bookings
GROUP BY route_code, route_from, route_to
ORDER BY cancel_rate_pct DESC;

-- 5C. Revenue lost to cancellations and no-shows
SELECT
    SUM(CASE WHEN booking_status = 'Cancelled' THEN total_fare ELSE 0 END) AS lost_cancelled,
    SUM(CASE WHEN booking_status = 'No Show'   THEN total_fare ELSE 0 END) AS lost_no_show,
    SUM(CASE WHEN booking_status <> 'Completed' THEN total_fare ELSE 0 END) AS total_lost
FROM clean.bookings;

-- 5D. Cancellation rate by payment method
SELECT
    payment_method,
    COUNT(*)                                AS bookings,
    ROUND(SUM(CASE WHEN booking_status <> 'Completed' THEN 1 ELSE 0 END)
          * 100.0 / COUNT(*), 1)            AS lost_booking_rate_pct
FROM clean.bookings
GROUP BY payment_method
ORDER BY lost_booking_rate_pct DESC;


/* ============================================================
   Q6. OPERATIONAL PATTERNS
   Busiest days and times - when should we add vehicles?
   ============================================================ */

-- 6A. Revenue by day of week
SELECT
    day_of_week,
    TRIM(day_name)                          AS day_name,
    COUNT(*)                                AS total_bookings,
    SUM(calculated_fare)                    AS total_revenue,
    ROUND(AVG(total_fare), 2)               AS avg_booking_value
FROM v_clean_trips
GROUP BY day_of_week, day_name
ORDER BY day_of_week;

-- 6B. Busiest departure times
SELECT
    departure_time,
    COUNT(*)                                AS bookings,
    SUM(seats_booked)                       AS passengers,
    SUM(calculated_fare)                    AS revenue
FROM v_clean_trips
GROUP BY departure_time
ORDER BY revenue DESC;

-- 6C. Seat utilisation by vehicle type
SELECT
    vehicle_type,
    ROUND(AVG(seats_booked), 2)             AS avg_seats_booked,
    CASE WHEN AVG(seats_booked) > 3  THEN 'High Load'
         WHEN AVG(seats_booked) >= 2 THEN 'Medium Load'
         ELSE 'Low Load'
    END                                     AS load_label
FROM v_clean_trips
GROUP BY vehicle_type;


/* ============================================================
   BI VIEWS - Power BI connects to these, never to raw tables
   ============================================================ */

CREATE OR REPLACE VIEW v_route_performance AS
SELECT
    route_code,
    route_from || '->' || route_to          AS route,
    COUNT(*)                                AS bookings,
    SUM(seats_booked)                       AS seats,
    ROUND(AVG(fare_per_seat), 2)            AS avg_fare,
    ROUND(AVG(trip_rating), 2)              AS avg_trip_rating,
    SUM(calculated_fare)                    AS total_revenue
FROM v_clean_trips
GROUP BY route_code, route_from, route_to;

CREATE OR REPLACE VIEW v_driver_performance AS
SELECT
    driver_name,
    vehicle_type,
    COUNT(*)                                AS total_trips,
    SUM(seats_booked)                       AS total_seats_carried,
    SUM(calculated_fare)                    AS total_revenue,
    ROUND(AVG(trip_rating), 2)              AS avg_trip_rating,
    MAX(driver_rating)                      AS driver_rating
FROM v_clean_trips
GROUP BY driver_name, vehicle_type;

CREATE OR REPLACE VIEW v_monthly_revenue AS
WITH monthly AS (
    SELECT travel_month AS month, COUNT(*) AS bookings, SUM(calculated_fare) AS revenue
    FROM v_clean_trips
    GROUP BY travel_month
)
SELECT
    month,
    bookings,
    revenue,
    LAG(revenue) OVER (ORDER BY month)                              AS prev_month,
    ROUND((revenue - LAG(revenue) OVER (ORDER BY month))
          / NULLIF(LAG(revenue) OVER (ORDER BY month), 0) * 100, 1) AS mom_pct,
    SUM(revenue) OVER (ORDER BY month)                              AS running_total
FROM monthly;

CREATE OR REPLACE VIEW v_cancellation_analysis AS
SELECT
    route_code,
    route_from || '->' || route_to                                  AS route,
    COUNT(*)                                                        AS total,
    SUM(CASE WHEN booking_status = 'Completed' THEN 1 ELSE 0 END)   AS completed,
    SUM(CASE WHEN booking_status = 'Cancelled' THEN 1 ELSE 0 END)   AS cancelled,
    SUM(CASE WHEN booking_status = 'No Show'   THEN 1 ELSE 0 END)   AS no_show,
    SUM(CASE WHEN booking_status <> 'Completed' THEN total_fare ELSE 0 END) AS lost_revenue
FROM clean.bookings
GROUP BY route_code, route_from, route_to;

CREATE OR REPLACE VIEW v_passenger_insights AS
SELECT
    COALESCE(passenger_city, 'Unknown')     AS passenger_city,
    COUNT(*)                                AS total_bookings,
    SUM(seats_booked)                       AS total_seats,
    SUM(calculated_fare)                    AS total_revenue,
    ROUND(AVG(total_fare), 2)               AS avg_booking_value
FROM v_clean_trips
GROUP BY COALESCE(passenger_city, 'Unknown');


/* ============================================================
   INDEXES - speed up the filters and GROUP BYs used above
   ============================================================ */

CREATE INDEX IF NOT EXISTS idx_bookings_depdate  ON clean.bookings (departure_date);
CREATE INDEX IF NOT EXISTS idx_bookings_route    ON clean.bookings (route_code);
CREATE INDEX IF NOT EXISTS idx_bookings_driver   ON clean.bookings (driver_name);
CREATE INDEX IF NOT EXISTS idx_bookings_status   ON clean.bookings (booking_status);
CREATE INDEX IF NOT EXISTS idx_bookings_payment  ON clean.bookings (payment_method);
CREATE INDEX IF NOT EXISTS idx_bookings_vehicle  ON clean.bookings (vehicle_type);
CREATE INDEX IF NOT EXISTS idx_bookings_passcity ON clean.bookings (passenger_city);

-- Verify
SELECT tablename, indexname FROM pg_indexes WHERE schemaname = 'clean';
