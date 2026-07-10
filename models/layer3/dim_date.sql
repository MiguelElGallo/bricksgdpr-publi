{{ config(tags=['layer3_dimensions']) }}

with calendar_days as (
    select explode(
        sequence(
            cast('{{ var("date_dimension_start") }}' as date),
            cast('{{ var("date_dimension_end") }}' as date),
            interval 1 day
        )
    ) as date_day
)

select
    cast(date_format(date_day, 'yyyyMMdd') as int) as date_key,
    date_day,
    year(date_day) as calendar_year,
    quarter(date_day) as calendar_quarter,
    month(date_day) as month_number,
    date_format(date_day, 'MMMM') as month_name,
    day(date_day) as day_of_month,
    dayofweek(date_day) as day_of_week,
    date_format(date_day, 'EEEE') as day_name,
    weekofyear(date_day) as iso_week_number,
    dayofweek(date_day) in (1, 7) as is_weekend
from calendar_days
