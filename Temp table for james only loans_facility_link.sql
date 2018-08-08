/* create temp table for james associated loans */
create table reporting.james_loans
as -- james this month part
		select loan.id as loan_id
				,loan_type.name as loan_type
                ,jm_credit.id as external_id
                ,loan.original_loan_application_id as application_id
                ,ol.original_loan_application_id as original_application_id
                ,loan.issued_at
                ,loan.created_at
				,loan.principal
                ,loan.initial_interest
                ,loan.annual_percentage_rate
                ,loan.no_of_payments
                ,date(loan.topped_up_at) as topped_up_at
                ,date(loan.extended_at) as extended_at
                ,date(loan.arranged_rp_at) as arranged_rp_at
		from peachy_prod.loan 
			/* join peachy_prod.credit_score 
				on loan.original_loan_application_id = credit_score.loan_application_id
			join peachy_prod.credit_score_config conf
				on credit_score.credit_score_config_id = conf.id
				and conf.id = '58' */ -- james scoring model 
                
			join facility_has_loan fhl
				on fhl.loan_id=l.id
			join facility 
				on facility.id=fhl.facility_id
			join credit_score cs
				on credit_score.id=facility.credit_score_id and date(facility.created_at)=date(credit_score.created_at)
			join credit_score_config conf
				on conf.id=credit_score.credit_score_config_id and conf.id=58
			join loan_application la
				on la.id=credit_score.loan_application_id
            
			/* james model external ids*/
			join peachy_prod.james_finance_application_credit_score jm_credit
				on la.id = jm_credit.loan_application_id
			/* get application id of original loan if exists */
			join peachy_prod.loan ol
				on loan.id = coalesce(ol.origin_loan_id, ol.id)
                and ol.deleted_at is null
			join peachy_prod.type as loan_type
				on loan.loan_type_id = loan_type.id
	/*	where date(loan.created_at) between date_format(date(date_add(now(), interval -1 month)), '%Y-%m-01') -- first day of month
							and last_day(date(date_add(now(), interval -1 month))) -- last day of month
		*/
        where date(loan.created_at) between '2018-06-01' -- first day of month
							and '2018-06-30' -- last day of month
			and loan.declined_at is null
			and loan.cancelled_at is null
			and loan.issued_at is not null
		group by loan.id
				,loan_type.name
                ,jm_credit.id
                ,loan.original_loan_application_id
                ,ol.original_loan_application_id
                ,loan.issued_at
                ,loan.created_at
				,loan.principal
                ,loan.initial_interest
                ,loan.annual_percentage_rate
                ,loan.no_of_payments
				,date(loan.topped_up_at)
                ,date(loan.extended_at)
                ,date(loan.arranged_rp_at)
		union
		-- james children part this month
		select child_loan.id as loan_id
				,loan_type.name as loan_type
                ,coalesce(jm_credit.id, james.external_id) as external_id
                ,child_loan.original_loan_application_id as application_id
                ,james.original_loan_application_id as original_application_id
                ,child_loan.issued_at
                ,child_loan.created_at
				,child_loan.principal
                ,child_loan.initial_interest
                ,child_loan.annual_percentage_rate
                ,child_loan.no_of_payments
                ,date(child_loan.topped_up_at) as topped_up_at
                ,date(child_loan.extended_at) as extended_at
                ,date(child_loan.arranged_rp_at) as arranged_rp_at
		from
			(select loan.id as loan_id
					,la.id as original_loan_application_id
                    ,jm_credit.id as external_id
				from peachy_prod.loan 
					/* join peachy_prod.credit_score 
						on loan.original_loan_application_id = credit_score.loan_application_id
					join peachy_prod.credit_score_config conf
						on credit_score.credit_score_config_id = conf.id
						and conf.id = '58' */ -- james scoring model 
                        
					join facility_has_loan fhl
						on fhl.loan_id=l.id
					join facility 
						on facility.id=fhl.facility_id
					join credit_score cs
						on credit_score.id=facility.credit_score_id and date(facility.created_at)=date(credit_score.created_at)
					join credit_score_config conf
						on conf.id=credit_score.credit_score_config_id and conf.id=58
					join loan_application la
						on la.id=credit_score.loan_application_id
            
			/* james model external ids*/
			join peachy_prod.james_finance_application_credit_score jm_credit
				on la.id = jm_credit.loan_application_id
                
			where loan.declined_at is null
				and loan.cancelled_at is null
				and loan.issued_at is not null
			) james
				join peachy_prod.loan child_loan
					on james.loan_id = child_loan.origin_loan_id
					and date(child_loan.created_at) between date_format(date(date_add(now(), interval -1 month)), '%Y-%m-01') -- first day of month
							and last_day(date(date_add(now(), interval -1 month))) -- last day of month
			join peachy_prod.type as loan_type
				on child_loan.loan_type_id = loan_type.id
			left join peachy_prod.james_finance_application_credit_score jm_credit
						on child_loan.original_loan_application_id = jm_credit.loan_application_id
			group by child_loan.id
				,loan_type.name
                ,child_loan.original_loan_application_id
                ,james.original_loan_application_id
                ,child_loan.issued_at
                ,child_loan.created_at
				,child_loan.principal
                ,child_loan.initial_interest
                ,child_loan.annual_percentage_rate
                ,child_loan.no_of_payments
				,date(child_loan.topped_up_at)
                ,date(child_loan.extended_at)
                ,date(child_loan.arranged_rp_at)
;	


drop table reporting.james_loans
;