/* JAMES monitoring scripts
	All applications
*/

select appl.id
		,appl.created_at
        ,case when loan.loan_application_id is not null
				and loan.issued_at is not null
                and loan.cancelled_at is null
                and loan.declined_at is null
				then 'A'
			else 'R'
        end as final_decision
        ,case when loan.loan_application_id is null or loan.declined_at is not null
						then coalesce(reason.message, 'Declined by lender')
				when loan.cancelled_at is not null
					or facility.id is null
                    or (loan.confirmed_at is not null
						and loan.cancelled_at is null
                        and loan.declined_at is null
                        and loan.issued_at is null)
						then 'Withdrawn by customer'
		else null
        end as rejection_reason
        
from peachy_prod.loan_application appl
	join peachy_prod.credit_score 
		on appl.id = credit_score.loan_application_id
	join peachy_prod.credit_score_config conf
		on credit_score.credit_score_config_id = conf.id
			and conf.id = '58' -- james scoring model only
	left join (select
			la.id as app_id
			,la.created_at as created_at
			,min(nla.created_at) as next_app_created_at
		from loan_application la
			join peachy_prod.credit_score 
				on la.id = credit_score.loan_application_id
			join peachy_prod.credit_score_config conf
				on credit_score.credit_score_config_id = conf.id
			and conf.id = '58' -- james scoring model only
		left join loan_application nla on la.customer_id=nla.customer_id 
			and nla.parent_loan_application_id is null
			and la.id<nla.id
		where la.parent_loan_application_id is null 
		group by la.id
		) next_appl
        on appl.id = next_appl.app_id
	left join peachy_prod.customer_state cst
			on appl.customer_id = cst.customer_id
            and cst.customer_state_type_id <> '775'
            and cst.customer_state_reason_id is not null
			and (cst.deleted_at is null or cst.deleted_at > appl.created_at)
			and (cst.created_at between appl.created_at and least(coalesce(next_appl.next_app_created_at,date_add(next_appl.created_at, INTERVAL 100 hour)), date_add(next_appl.created_at, INTERVAL 100 hour)))
	left join peachy_prod.facility 
		on credit_score.id = facility.credit_score_id
		-- and credit_score.customer_id = facility.customer_id
	left join peachy_prod.loan
		on appl.id = loan.loan_application_id
        and loan.deleted_at is null
	left join peachy_prod.reason
		on cst.customer_state_reason_id = reason.id
/* cutting period for last month only */
where date(appl.created_at) >= date(date_add(now(), interval -1 month)) 
group by 1,2,3,4
order by 3
;	