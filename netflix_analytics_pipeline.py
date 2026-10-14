"""
Auspify Technologies — Business Analytics Internship Program
Project Source Code: Complete Python Analytics & Visualization Pipeline (Tasks 1–6)
Dataset: Dataset.csv (Netflix Global Catalog, N = 8,790 Titles)
"""

import os
import pandas as pd
import numpy as np
import matplotlib.pyplot as plt


def load_and_clean_dataset(csv_path: str) -> pd.DataFrame:
    """Step 1: Import and prepare the Netflix dataset."""
    df = pd.read_csv(csv_path)
    
    # Standardize string columns
    for col in ['show_id', 'type', 'title', 'director', 'country', 'rating', 'duration', 'listed_in']:
        df[col] = df[col].astype(str).str.strip()
        
    # Parse mixed-format date_added (e.g., '9/25/2021' and '05-01-2021')
    df['date_added_parsed'] = pd.to_datetime(df['date_added'], format='mixed', errors='coerce')
    df['year_added'] = df['date_added_parsed'].dt.year
    df['month_added'] = df['date_added_parsed'].dt.month
    df['month_name_added'] = df['date_added_parsed'].dt.month_name()
    
    # Extract numeric duration (minutes for Movies, seasons for TV Shows)
    df['duration_value'] = df['duration'].str.extract(r'(\d+)').astype(float)
    df['content_lag_years'] = df['year_added'] - df['release_year']
    
    # Map ratings to Strategic Audience Segments (Task 3)
    segment_map = {
        'TV-MA': 'Mature / Adults (18+)', 'R': 'Mature / Adults (18+)', 'NC-17': 'Mature / Adults (18+)',
        'TV-14': 'Teens & Young Adults (13-17)', 'PG-13': 'Teens & Young Adults (13-17)',
        'TV-PG': 'Older Kids & Family (Parental Guidance)', 'PG': 'Older Kids & Family (Parental Guidance)',
        'TV-Y7': 'Kids (Age 7+)', 'TV-Y7-FV': 'Kids (Age 7+)',
        'TV-Y': 'Young Children & All Ages', 'TV-G': 'Young Children & All Ages', 'G': 'Young Children & All Ages',
        'NR': 'Unrated / Not Rated', 'UR': 'Unrated / Not Rated'
    }
    df['audience_segment'] = df['rating'].map(segment_map).fillna('Unrated / Not Rated')
    return df


def task1_portfolio_analysis(df: pd.DataFrame) -> dict:
    """Task 1 (Easy): Netflix Content Portfolio Analysis."""
    type_counts = df['type'].value_counts()
    type_share = (df['type'].value_counts(normalize=True) * 100).round(2)
    
    movies = df[df['type'] == 'Movie']
    tv_shows = df[df['type'] == 'TV Show']
    
    runtime_bins = [0, 60, 90, 120, 150, 500]
    runtime_labels = [
        'Short (<60m)', 'Standard-Short (60-90m)', 'Core Feature (91-120m)',
        'Long Feature (121-150m)', 'Epic (>150m)'
    ]
    movie_tiers = pd.cut(movies['duration_value'], bins=runtime_bins, labels=runtime_labels).value_counts()
    
    season_counts = tv_shows['duration_value'].apply(lambda x: f"{int(x)} Season(s)" if x < 6 else "6+ Seasons").value_counts()
    
    return {
        'total_titles': len(df),
        'type_counts': type_counts.to_dict(),
        'type_share_pct': type_share.to_dict(),
        'movie_mean_min': round(movies['duration_value'].mean(), 2),
        'movie_median_min': round(movies['duration_value'].median(), 2),
        'tv_mean_seasons': round(tv_shows['duration_value'].mean(), 2),
        'single_season_tv_pct': round((tv_shows['duration_value'] == 1).mean() * 100, 2),
        'movie_runtime_tiers': movie_tiers.to_dict(),
        'tv_season_tiers': season_counts.to_dict()
    }


def task2_market_performance(df: pd.DataFrame) -> pd.DataFrame:
    """Task 2 (Easy): Global Market Performance Analysis."""
    ctry = pd.crosstab(df['country'], df['type'])
    ctry['Total_Titles'] = ctry['Movie'] + ctry['TV Show']
    ctry['Global_Share_%'] = (ctry['Total_Titles'] / len(df) * 100).round(2)
    ctry['Movie_Share_%'] = (ctry['Movie'] / ctry['Total_Titles'] * 100).round(1)
    ctry['TV_Share_%'] = (ctry['TV Show'] / ctry['Total_Titles'] * 100).round(1)
    return ctry.sort_values('Total_Titles', ascending=False)


def task3_audience_segmentation(df: pd.DataFrame) -> tuple:
    """Task 3 (Medium): Audience Segmentation Analysis."""
    rating_df = pd.crosstab(df['rating'], df['type'])
    rating_df['Total'] = rating_df['Movie'] + rating_df['TV Show']
    rating_df['Share_%'] = (rating_df['Total'] / len(df) * 100).round(2)
    rating_df = rating_df.sort_values('Total', ascending=False)
    
    seg_df = pd.crosstab(df['audience_segment'], df['type'])
    seg_df['Total'] = seg_df['Movie'] + seg_df['TV Show']
    seg_df['Share_%'] = (seg_df['Total'] / len(df) * 100).round(2)
    seg_df['Movie_%'] = (seg_df['Movie'] / seg_df['Total'] * 100).round(1)
    seg_df['TV_%'] = (seg_df['TV Show'] / seg_df['Total'] * 100).round(1)
    seg_df = seg_df.sort_values('Total', ascending=False)
    return rating_df, seg_df


def task4_growth_trends(df: pd.DataFrame) -> tuple:
    """Task 4 (Medium): Content Growth & Trend Analysis."""
    yearly_added = pd.crosstab(df['year_added'], df['type'])
    yearly_added['Total'] = yearly_added['Movie'] + yearly_added['TV Show']
    yearly_added['YoY_Growth_%'] = (yearly_added['Total'].pct_change() * 100).round(1)
    yearly_added['TV_Share_%'] = (yearly_added['TV Show'] / yearly_added['Total'] * 100).round(1)
    
    monthly_added = pd.crosstab(df['month_added'], df['type'])
    monthly_added['Total'] = monthly_added['Movie'] + monthly_added['TV Show']
    monthly_added['Share_%'] = (monthly_added['Total'] / len(df) * 100).round(2)
    return yearly_added, monthly_added


def task5_category_performance(df: pd.DataFrame) -> pd.DataFrame:
    """Task 5 (Advanced): Content Category Performance Analysis."""
    exploded = df.assign(genre=df['listed_in'].str.split(', ')).explode('genre')
    cat_df = pd.crosstab(exploded['genre'], exploded['type'])
    cat_df['Total_Titles'] = cat_df['Movie'] + cat_df['TV Show']
    cat_df['Catalog_Penetration_%'] = (cat_df['Total_Titles'] / len(df) * 100).round(2)
    cat_df['Mention_Share_%'] = (cat_df['Total_Titles'] / len(exploded) * 100).round(2)
    return cat_df.sort_values('Total_Titles', ascending=False)


def main():
    csv_candidates = [
        'Dataset.csv',
        '/working_dir/c_9c4d5881cc6b69b3/user_uploaded_files/ttl=63d/user_uploaded/Dataset.csv'
    ]
    csv_path = next((p for p in csv_candidates if os.path.exists(p)), csv_candidates[0])
    df = load_and_clean_dataset(csv_path)
    
    print("=" * 72)
    print("AUSPIFY BUSINESS ANALYTICS INTERNSHIP — AUTOMATED PIPELINE REPORT")
    print("=" * 72)
    
    t1 = task1_portfolio_analysis(df)
    print(f"\n[TASK 1] Total Catalog: {t1['total_titles']:,} Titles")
    print(f"  • Movies: {t1['type_counts']['Movie']:,} ({t1['type_share_pct']['Movie']}%) | Mean Runtime: {t1['movie_mean_min']} min")
    print(f"  • TV Shows: {t1['type_counts']['TV Show']:,} ({t1['type_share_pct']['TV Show']}%) | 1-Season Rate: {t1['single_season_tv_pct']}%")
    
    t2 = task2_market_performance(df)
    print("\n[TASK 2] Top 10 Global Content Markets:")
    print(t2.head(10).to_string())
    
    r_df, s_df = task3_audience_segmentation(df)
    print("\n[TASK 3] Strategic Audience Segments:")
    print(s_df.to_string())
    
    y_df, m_df = task4_growth_trends(df)
    print("\n[TASK 4] Annual Platform Additions (2015–2021):")
    print(y_df.loc[2015:2021].to_string())
    
    c_df = task5_category_performance(df)
    print("\n[TASK 5] Top 15 Content Categories:")
    print(c_df.head(15).to_string())
    print("\n[TASK 6] Pipeline execution complete.")


if __name__ == '__main__':
    main()
