/* JAMES monitoring scripts
	All applications
*/
select 	jm_credit.id as external_id
		,appl.id
		,appl.created_at
        ,case when loan.loan_application_id is not null
				and loan.issued_at is not null
                and loan.cancelled_at is null
                and loan.declined_at is null
				then 'A'
			else 'R'
        end as final_decision
        ,case when facility.credit_score_id is null or loan.declined_at is not null
				then 'Declined'
			when loan.loan_application_id is not null
				and loan.issued_at is not null
                and loan.cancelled_at is null
                and loan.declined_at is null
				then 'Accepted'
			else 'Withdrawn by Customer'
        end as rejection_reason        
        ,appl.amount_of_credit as applied_amount
        ,fi.total_monthly_expenses
        ,fi.total_monthly_income
from peachy_prod.loan_application appl
	join peachy_prod.james_finance_application_credit_score jm_credit
		on appl.id = jm_credit.loan_application_id
        and appl.deleted_at is null 
	join peachy_prod.credit_score 
		on appl.id = credit_score.loan_application_id
        and appl.deleted_at is null
	join peachy_prod.credit_score_config conf
		on credit_score.credit_score_config_id = conf.id
			and conf.id = '58' -- james scoring model only
	left join peachy_prod.facility 
		on credit_score.id = facility.credit_score_id
	left join peachy_prod.loan
		on appl.id = loan.original_loan_application_id
        and loan.deleted_at is null
	left join peachy_prod.financial_information fi
		on appl.customer_id = fi.customer_id
        and fi.deleted_at is null
/* cutting period for last month only by the date of scoring */
where date(credit_score.created_at) between date_format(date(date_add(now(), interval -1 month)), '%Y-%m-01') -- first day of month
							and last_day(date(date_add(now(), interval -1 month))) -- last day of month
group by appl.id
		,appl.created_at
        ,case when loan.loan_application_id is not null
				and loan.issued_at is not null
                and loan.cancelled_at is null
                and loan.declined_at is null
				then 'A'
			else 'R'
        end 
        ,case when facility.credit_score_id is null or loan.declined_at is not null
				then 'Declined'
			when loan.loan_application_id is not null
				and loan.issued_at is not null
                and loan.cancelled_at is null
                and loan.declined_at is null
				then 'Accepted'
			else 'Withdrawn by Customer'
        end 
;	