with differences as (
    (
        select * from {{ ref('dim_customer') }}
        except
        select * from {{ ref('int_customer_protected') }}
    )
    union all
    (
        select * from {{ ref('int_customer_protected') }}
        except
        select * from {{ ref('dim_customer') }}
    )
)

select * from differences
