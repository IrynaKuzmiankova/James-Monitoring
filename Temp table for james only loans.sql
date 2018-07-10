/* create temp table for james associated loans */
create table reporting.james_loans
as -- james this month part
		select loan.id as loan_id
				,loan.loan_type_id
                ,loan.original_loan_application_id as application_id
                ,ol.original_loan_application_id as original_application_id
                ,loan.issued_at
                ,loan.created_at
				,loan.principal
                ,loan.initial_interest
                ,loan.annual_percentage_rate
                ,loan.no_of_payments
		from peachy_prod.loan 
			join peachy_prod.credit_score 
				on loan.original_loan_application_id = credit_score.loan_application_id
			join peachy_prod.credit_score_config conf
				on credit_score.credit_score_config_id = conf.id
				and conf.id = '58'  -- james scoring model 
			/* get application id of original loan if exists */
			join peachy_prod.loan ol
				on loan.id = coalesce(ol.origin_loan_id, ol.id)
                and ol.deleted_at is null
		where date(loan.created_at) between date_format(date(date_add(now(), interval -1 month)), '%Y-%m-01') -- first day of month
							and last_day(date(date_add(now(), interval -1 month))) -- last day of month
			and loan.declined_at is null
			and loan.cancelled_at is null
			and loan.issued_at is not null
		group by loan.id
				,loan.loan_type_id
                ,loan.original_loan_application_id
                ,ol.original_loan_application_id
                ,loan.issued_at
                ,loan.created_at
				,loan.principal
                ,loan.initial_interest
                ,loan.annual_percentage_rate
                ,loan.no_of_payments
		union
		-- james children part this month
		select child_loan.id as loan_id
				,child_loan.loan_type_id
                ,child_loan.original_loan_application_id as application_id
                ,james.original_loan_application_id as original_application_id
                ,child_loan.issued_at
                ,child_loan.created_at
				,child_loan.principal
                ,child_loan.initial_interest
                ,child_loan.annual_percentage_rate
                ,child_loan.no_of_payments
		from
			(select loan.id as loan_id
					,loan.original_loan_application_id
				from peachy_prod.loan 
					join peachy_prod.credit_score 
						on loan.original_loan_application_id = credit_score.loan_application_id
					join peachy_prod.credit_score_config conf
						on credit_score.credit_score_config_id = conf.id
						and conf.id = '58'  -- james scoring model 
			where loan.declined_at is null
				and loan.cancelled_at is null
				and loan.issued_at is not null
			) james
				join peachy_prod.loan child_loan
					on james.loan_id = child_loan.origin_loan_id
					and date(child_loan.created_at) between date_format(date(date_add(now(), interval -1 month)), '%Y-%m-01') -- first day of month
							and last_day(date(date_add(now(), interval -1 month))) -- last day of month
;	


drop table reporting.james_loans
;