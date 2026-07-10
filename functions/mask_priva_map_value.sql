case
    when
        is_account_group_member(
            'privacy_admins'
        )
        or is_account_group_member(
            'case_users'
        )
    then raw_value
    else pseudonymous_value
end
