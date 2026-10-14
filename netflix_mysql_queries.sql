-- ============================================================================
-- AUSPIFY TECHNOLOGIES — BUSINESS ANALYTICS INTERNSHIP PROGRAM
-- MySQL Analytical Queries & Database Schema (Tasks 1 to 6)
-- Dataset: Dataset.csv (Netflix Global Content Catalog, N = 8,790 Titles)
-- ============================================================================

CREATE DATABASE IF NOT EXISTS auspify_netflix_analytics;
USE auspify_netflix_analytics;

-- ----------------------------------------------------------------------------
-- STEP 1: TABLE SCHEMA & DATA PREPARATION
-- ----------------------------------------------------------------------------
DROP TABLE IF EXISTS netflix_catalog;
CREATE TABLE netflix_catalog (
    show_id VARCHAR(16) PRIMARY KEY,
    type VARCHAR(20) NOT NULL,
    title VARCHAR(300) NOT NULL,
    director VARCHAR(500),
    country VARCHAR(150),
    date_added VARCHAR(50),
    release_year INT NOT NULL,
    rating VARCHAR(20),
    duration VARCHAR(50),
    listed_in VARCHAR(255)
);

-- Create enriched analytical view with parsed dates, numeric durations, and segments
CREATE OR REPLACE VIEW vw_netflix_enriched AS
SELECT
    show_id,
    type,
    title,
    NULLIF(TRIM(director), 'Not Given') AS clean_director,
    director AS raw_director,
    country,
    CASE
        WHEN date_added LIKE '%/%/%' THEN STR_TO_DATE(TRIM(date_added), '%m/%d/%Y')
        WHEN date_added LIKE '%-%-%' THEN STR_TO_DATE(TRIM(date_added), '%m-%d-%Y')
        ELSE NULL
    END AS date_added_parsed,
    YEAR(
        CASE
            WHEN date_added LIKE '%/%/%' THEN STR_TO_DATE(TRIM(date_added), '%m/%d/%Y')
            WHEN date_added LIKE '%-%-%' THEN STR_TO_DATE(TRIM(date_added), '%m-%d-%Y')
            ELSE NULL
        END
    ) AS year_added,
    MONTH(
        CASE
            WHEN date_added LIKE '%/%/%' THEN STR_TO_DATE(TRIM(date_added), '%m/%d/%Y')
            WHEN date_added LIKE '%-%-%' THEN STR_TO_DATE(TRIM(date_added), '%m-%d-%Y')
            ELSE NULL
        END
    ) AS month_added,
    release_year,
    rating,
    CAST(SUBSTRING_INDEX(TRIM(duration), ' ', 1) AS UNSIGNED) AS duration_numeric,
    duration,
    listed_in,
    CASE
        WHEN rating IN ('TV-MA', 'R', 'NC-17') THEN 'Mature / Adults (18+)'
        WHEN rating IN ('TV-14', 'PG-13') THEN 'Teens & Young Adults (13-17)'
        WHEN rating IN ('TV-PG', 'PG') THEN 'Older Kids & Family (Parental Guidance)'
        WHEN rating IN ('TV-Y7', 'TV-Y7-FV') THEN 'Kids (Age 7+)'
        WHEN rating IN ('TV-Y', 'TV-G', 'G') THEN 'Young Children & All Ages'
        ELSE 'Unrated / Not Rated'
    END AS audience_segment
FROM netflix_catalog;

-- ----------------------------------------------------------------------------
-- TASK 1 (EASY): NETFLIX CONTENT PORTFOLIO ANALYSIS
-- ----------------------------------------------------------------------------
-- 1A. Content Type Distribution & Share
SELECT
    type AS content_type,
    COUNT(*) AS total_titles,
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM netflix_catalog), 2) AS portfolio_share_pct,
    ROUND(AVG(duration_numeric), 2) AS mean_duration_or_seasons,
    MIN(duration_numeric) AS min_duration_or_seasons,
    MAX(duration_numeric) AS max_duration_or_seasons
FROM vw_netflix_enriched
GROUP BY type
ORDER BY total_titles DESC;

-- 1B. Movie Runtime Tiers
SELECT
    CASE
        WHEN duration_numeric < 60 THEN '1. Short (<60 min)'
        WHEN duration_numeric BETWEEN 60 AND 90 THEN '2. Standard-Short (60-90 min)'
        WHEN duration_numeric BETWEEN 91 AND 120 THEN '3. Core Feature (91-120 min)'
        WHEN duration_numeric BETWEEN 121 AND 150 THEN '4. Long Feature (121-150 min)'
        ELSE '5. Epic (>150 min)'
    END AS runtime_tier,
    COUNT(*) AS movie_count,
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM netflix_catalog WHERE type = 'Movie'), 2) AS share_of_movies_pct
FROM vw_netflix_enriched
WHERE type = 'Movie'
GROUP BY runtime_tier
ORDER BY runtime_tier;

-- 1C. TV Show Season Depth
SELECT
    CASE
        WHEN duration_numeric = 1 THEN '1 Season'
        WHEN duration_numeric = 2 THEN '2 Seasons'
        WHEN duration_numeric = 3 THEN '3 Seasons'
        WHEN duration_numeric = 4 THEN '4 Seasons'
        WHEN duration_numeric = 5 THEN '5 Seasons'
        ELSE '6+ Seasons'
    END AS season_tier,
    COUNT(*) AS tv_show_count,
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM netflix_catalog WHERE type = 'TV Show'), 2) AS share_of_tv_shows_pct
FROM vw_netflix_enriched
WHERE type = 'TV Show'
GROUP BY season_tier
ORDER BY MIN(duration_numeric);

-- ----------------------------------------------------------------------------
-- TASK 2 (EASY): GLOBAL MARKET PERFORMANCE ANALYSIS
-- ----------------------------------------------------------------------------
-- 2A. Top 20 Content Markets with Format Split
SELECT
    country,
    SUM(CASE WHEN type = 'Movie' THEN 1 ELSE 0 END) AS movies_count,
    SUM(CASE WHEN type = 'TV Show' THEN 1 ELSE 0 END) AS tv_shows_count,
    COUNT(*) AS total_titles,
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM netflix_catalog), 2) AS global_share_pct,
    ROUND(SUM(CASE WHEN type = 'Movie' THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 1) AS movie_share_pct,
    ROUND(SUM(CASE WHEN type = 'TV Show' THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 1) AS tv_share_pct
FROM netflix_catalog
GROUP BY country
ORDER BY total_titles DESC
LIMIT 20;

-- ----------------------------------------------------------------------------
-- TASK 3 (MEDIUM): AUDIENCE SEGMENTATION ANALYSIS
-- ----------------------------------------------------------------------------
-- 3A. Strategic Audience Segments by Format
SELECT
    audience_segment,
    SUM(CASE WHEN type = 'Movie' THEN 1 ELSE 0 END) AS movies_count,
    SUM(CASE WHEN type = 'TV Show' THEN 1 ELSE 0 END) AS tv_shows_count,
    COUNT(*) AS total_titles,
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM netflix_catalog), 2) AS catalog_share_pct,
    ROUND(SUM(CASE WHEN type = 'Movie' THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 1) AS movie_pct,
    ROUND(SUM(CASE WHEN type = 'TV Show' THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 1) AS tv_pct
FROM vw_netflix_enriched
GROUP BY audience_segment
ORDER BY total_titles DESC;

-- 3B. Granular Rating Breakdown
SELECT
    rating,
    audience_segment,
    SUM(CASE WHEN type = 'Movie' THEN 1 ELSE 0 END) AS movies_count,
    SUM(CASE WHEN type = 'TV Show' THEN 1 ELSE 0 END) AS tv_shows_count,
    COUNT(*) AS total_titles,
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM netflix_catalog), 2) AS catalog_share_pct
FROM vw_netflix_enriched
GROUP BY rating, audience_segment
ORDER BY total_titles DESC;

-- ----------------------------------------------------------------------------
-- TASK 4 (MEDIUM): CONTENT GROWTH & TREND ANALYSIS
-- ----------------------------------------------------------------------------
-- 4A. Annual Catalog Additions & YoY Trajectory
WITH annual_additions AS (
    SELECT
        year_added,
        SUM(CASE WHEN type = 'Movie' THEN 1 ELSE 0 END) AS movies_added,
        SUM(CASE WHEN type = 'TV Show' THEN 1 ELSE 0 END) AS tv_shows_added,
        COUNT(*) AS total_added
    FROM vw_netflix_enriched
    WHERE year_added IS NOT NULL
    GROUP BY year_added
)
SELECT
    year_added,
    movies_added,
    tv_shows_added,
    total_added,
    ROUND(tv_shows_added * 100.0 / total_added, 1) AS tv_share_pct,
    LAG(total_added) OVER (ORDER BY year_added) AS prev_year_added,
    ROUND((total_added - LAG(total_added) OVER (ORDER BY year_added)) * 100.0 /
          NULLIF(LAG(total_added) OVER (ORDER BY year_added), 0), 1) AS yoy_growth_pct
FROM annual_additions
ORDER BY year_added;

-- 4B. Release Year Vintage Trends (2000-2021)
SELECT
    release_year,
    SUM(CASE WHEN type = 'Movie' THEN 1 ELSE 0 END) AS movies_released,
    SUM(CASE WHEN type = 'TV Show' THEN 1 ELSE 0 END) AS tv_shows_released,
    COUNT(*) AS total_released
FROM netflix_catalog
WHERE release_year >= 2000
GROUP BY release_year
ORDER BY release_year DESC;

-- ----------------------------------------------------------------------------
-- TASK 5 (ADVANCED): CONTENT CATEGORY PERFORMANCE ANALYSIS
-- ----------------------------------------------------------------------------
-- Recursive CTE to split comma-separated 'listed_in' genres in MySQL 8.0+
WITH RECURSIVE genre_split AS (
    SELECT
        show_id,
        type,
        country,
        rating,
        TRIM(SUBSTRING_INDEX(listed_in, ',', 1)) AS genre,
         CASE
            WHEN LOCATE(',', listed_in) > 0 THEN TRIM(SUBSTRING(listed_in, LOCATE(',', listed_in) + 1))
            ELSE ''
        END AS remaining_genres
    FROM netflix_catalog
    UNION ALL
    SELECT
        show_id,
        type,
        country,
        rating,
        TRIM(SUBSTRING_INDEX(remaining_genres, ',', 1)) AS genre,
        CASE
            WHEN LOCATE(',', remaining_genres) > 0 THEN TRIM(SUBSTRING(remaining_genres, LOCATE(',', remaining_genres) + 1))
            ELSE ''
        END AS remaining_genres
    FROM genre_split
    WHERE remaining_genres <> ''
)
SELECT
    genre AS category_name,
    SUM(CASE WHEN type = 'Movie' THEN 1 ELSE 0 END) AS movie_count,
    SUM(CASE WHEN type = 'TV Show' THEN 1 ELSE 0 END) AS tv_show_count,
    COUNT(*) AS total_mentions,
    ROUND(COUNT(*) * 100.0 / 8790, 2) AS catalog_penetration_pct,
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM genre_split), 2) AS mention_share_pct
FROM genre_split
GROUP BY genre
ORDER BY total_mentions DESC;

-- ----------------------------------------------------------------------------
-- TASK 6 (ADVANCED): EXECUTIVE KPI SUMMARY VIEW
-- ----------------------------------------------------------------------------
SELECT
    COUNT(*) AS total_catalog_titles,
    SUM(CASE WHEN type = 'Movie' THEN 1 ELSE 0 END) AS total_movies,
    SUM(CASE WHEN type = 'TV Show' THEN 1 ELSE 0 END) AS total_tv_shows,
    COUNT(DISTINCT NULLIF(country, 'Not Given')) AS active_countries,
    SUM(CASE WHEN audience_segment = 'Mature / Adults (18+)' THEN 1 ELSE 0 END) AS mature_18_plus_titles,
    SUM(CASE WHEN (year_added - release_year) <= 0 THEN 1 ELSE 0 END) AS same_year_original_releases
FROM vw_netflix_enriched;
