/*
JAMES monitoring scripts
Monthly payments

*/


select  -- loan.id as Loan_Id,
		loan.original_loan_application_id as Application_ID 
        ,appl.parent_loan_application_id as Parent_Application_ID
        ,loan.loan_application_id as Child_Application_ID
		,date_format(now(), '%Y-%m-01') as Reporting_Month
        ,loan_payment.actual_payment_date as Actual_Payment_Date
        ,loan_payment.paid_at_date as Paid_At_Date
		,loan_type.name as Type_of_Loan
        ,total_outstanding.principal_payable as Outstanding_Principal
        ,(total_outstanding.principal_payable + total_outstanding.interest_payable + total_outstanding.fees_payable
			+ total_outstanding.penalty_payable - total_outstanding.discount) as Outstanding_Total
        ,(payable_by_now.principal
			+ payable_by_now.interest
            + payable_by_now.fees
            + payable_by_now.penalty
            + payable_by_now.discount
            )
			as Due_payment
        ,(payable_by_now.principal_paid
			+ payable_by_now.interest_paid
            + payable_by_now.fees_paid
            + payable_by_now.penalty_paid
		 )
		   as Monthly_payment
		,(payable_by_now.principal_paid) as Principal_Paid
        ,(payable_by_now.interest_paid) as Interest_Paid
        ,(payable_by_now.penalty - payable_by_now.penalty_paid) as Late_Payment_Interest
from peachy_prod.loan
	join peachy_prod.credit_score 
		on loan.original_loan_application_id = credit_score.loan_application_id
	join peachy_prod.credit_score_config conf
		on credit_score.credit_score_config_id = conf.id
		and conf.id = '58'  -- james scoring model
	join peachy_prod.loan_application appl
		on loan.loan_application_id = appl.id
	join peachy_prod.type loan_type
		on loan.loan_type_id = loan_type.id
	join peachy_prod.loan_payment 
		on loan.id = loan_payment.loan_id
		and loan_payment.deleted_at is null
        /* payment due date falls into reporting period, not paid or paid in the same reporting period  */
        AND ((loan_payment.actual_payment_date between date(date_add(now(), interval -1 month)) and date(now())
			and (loan_payment.paid_at_date is null or loan_payment.paid_at_date between date(date_add(now(), interval -1 month)) and date(now()))
            /* payment due date before date of top up/extension/repayment plan, the check is to exclude all payments of parent loan after child loan of listed type emerged */
			and (loan_payment.actual_payment_date <= coalesce(loan.topped_up_at, loan.extended_at, loan.arranged_rp_at, '2999-12-31'))
			)
            /* payment due date is out of reporting period, but paid in the reporting period */
			or (loan_payment.paid_at_date between date(date_add(now(), interval -1 month)) and date(now())
			and loan_payment.actual_payment_date > date(now())))
        /* join all payments after already paid to calculate total outstanding amount at the current point */
	join (
    select lp.loan_id
            ,lpd.actual_payment_date as original_due_date
			,(ifnull(sum(principal),0) - ifnull(sum(principal_paid),0)) as principal_payable
            ,(ifnull(sum(interest),0) - ifnull(sum(interest_paid),0)) 	as interest_payable
            ,(ifnull(sum(fees),0) - ifnull(sum(fees_paid),0))			as fees_payable
            ,(ifnull(sum(penalty),0) - ifnull(sum(penalty_paid),0))		as penalty_payable
            ,ifnull(sum(discount),0)									as discount						
    from peachy_prod.loan_payment lp
			join ( select lp.loan_id, lp.actual_payment_date
					from peachy_prod.loan_payment lp
						join peachy_prod.loan
							on loan.id = lp.loan_id
						join peachy_prod.credit_score 
							on loan.original_loan_application_id = credit_score.loan_application_id
						join peachy_prod.credit_score_config conf
							on credit_score.credit_score_config_id = conf.id
							and conf.id = '58'  -- james scoring model
                    where lp.is_next_payment = 1
                    and lp.deleted_at is null
                     group by lp.loan_id, lp.actual_payment_date
            ) lpd
            on lp.loan_id = lpd.loan_id and lp.actual_payment_date >= lpd.actual_payment_date
    where lp.deleted_at is null
    group by lp.loan_id
    ) total_outstanding
		on loan.id = total_outstanding.loan_id	
        /* join all payments for reporting month to calculate payable amount */
    join (
    select lp.loan_id
            ,lpd.actual_payment_date as original_due_date
			,ifnull(sum(principal),0) as principal
            ,ifnull(sum(principal_paid),0) as principal_paid
            ,ifnull(sum(interest),0) as interest
            ,ifnull(sum(interest_paid),0) 	as interest_paid
            ,ifnull(sum(fees),0) as fees
            ,ifnull(sum(fees_paid),0) as fees_paid
            ,ifnull(sum(penalty),0) as penalty
            ,ifnull(sum(penalty_paid),0) as penalty_paid
            ,ifnull(sum(discount),0) as discount						
    from peachy_prod.loan_payment lp
			join ( select lp.loan_id, lp.actual_payment_date
					from peachy_prod.loan_payment lp
						join peachy_prod.loan
							on loan.id = lp.loan_id
						join peachy_prod.credit_score 
							on loan.original_loan_application_id = credit_score.loan_application_id
						join peachy_prod.credit_score_config conf
							on credit_score.credit_score_config_id = conf.id
						    and conf.id = '58'  -- james scoring model
                    where ((lp.actual_payment_date between date(date_add(now(), interval -1 month)) and date(now())
							and (lp.paid_at_date is null or lp.paid_at_date between date(date_add(now(), interval -1 month)) and date(now()))
							and (lp.actual_payment_date <= coalesce(loan.topped_up_at, loan.extended_at, loan.arranged_rp_at, '2999-12-31'))
							)
							or (lp.paid_at_date between date(date_add(now(), interval -1 month)) and date(now())
							and lp.actual_payment_date > date(now())))
						and lp.deleted_at is null
                    group by lp.loan_id, lp.actual_payment_date
            ) lpd
            on lp.loan_id = lpd.loan_id
				and lp.actual_payment_date = lpd.actual_payment_date
               
    where lp.deleted_at is null
    group by lp.loan_id
    ) payable_by_now
    on loan.id = payable_by_now.loan_id	
where loan_payment.actual_payment_date between date(date_add(now(), interval -1 month)) and date(now())
group by loan.id
		,loan.original_loan_application_id
		,date_format(now(), '%Y-%m-01')
order by loan.original_loan_application_id desc, loan.id desc
;