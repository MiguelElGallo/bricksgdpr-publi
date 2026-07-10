select
    current_customers.customer_id,
    current_customers.customer_ssn
from {{ ref('int_current_customers') }} as current_customers
inner join {{ ref('int_terminal_deleted_customer_ssns') }} as deleted
    on current_customers.customer_ssn = deleted.customer_ssn
