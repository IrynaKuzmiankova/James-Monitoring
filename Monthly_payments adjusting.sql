select  loan.id as Loan_Id,
		loan.original_loan_application_id as Application_ID 
       -- ,loan.original_application_id as Original_Application_Id
		,date_format(now(), '%Y-%m-01') as Reporting_Month
        ,loan_payment.actual_payment_date as Actual_Payment_Date
        ,loan_payment.paid_at_date as Paid_At_Date
		,loan_type.name as Type_of_Loan
        /* before payment made */
        ,case when loan_payment.paid_at_date is not null then (ifnull(total_outstanding.principal_payable,0) + loan_payment.principal)
			else total_outstanding.principal_payable
		end as Outstanding_Principal
        /* before payment made */
        ,case when loan_payment.paid_at_date is not null then 
        (ifnull(total_outstanding.principal_payable,0) 
        + ifnull(total_outstanding.interest_payable,0) 
        + ifnull(total_outstanding.fees_payable,0)
		+ ifnull(total_outstanding.penalty_payable,0) 
        - ifnull(total_outstanding.discount,0)) 
        /* adjust by paid sum */
		+ (ifnull(loan_payment.principal,0)
			+ ifnull(loan_payment.interest,0)
            + ifnull(loan_payment.fees,0)
            + ifnull(loan_payment.penalty,0)
            + ifnull(loan_payment.discount,0)
            )
            /* if nothing paid, report full outstanding */
		else (ifnull(total_outstanding.principal_payable,0) 
        + ifnull(total_outstanding.interest_payable,0) 
        + ifnull(total_outstanding.fees_payable,0)
		+ ifnull(total_outstanding.penalty_payable,0) 
        - ifnull(total_outstanding.discount,0)) 
        end as Outstanding_Total
        ,(ifnull(loan_payment.principal,0)
			+ ifnull(loan_payment.interest,0)
            + ifnull(loan_payment.fees,0)
            + ifnull(loan_payment.penalty,0)
            + ifnull(loan_payment.discount,0)
            )
			as Due_payment
            
        ,(loan_payment.principal_paid
			+ loan_payment.interest_paid
            + loan_payment.fees_paid
            + loan_payment.penalty_paid
		 )
		   as Monthly_payment
		,(loan_payment.principal_paid) as Principal_Paid
        ,(loan_payment.interest_paid) as Interest_Paid
        ,(loan_payment.penalty - loan_payment.penalty_paid) as Late_Payment_Interest
from -- reporting.james_loans loan
	peachy_prod.loan
	join peachy_prod.loan_application appl
		on loan.original_loan_application_id = appl.id
	join peachy_prod.type loan_type
		on loan.loan_type_id = loan_type.id
	join peachy_prod.loan_payment 
		on loan.id = loan_payment.loan_id
		and loan_payment.deleted_at is null
        /* payment due date falls into reporting period, not paid or paid in the same reporting period  */
        AND ((loan_payment.actual_payment_date between date(date_add(subdate(current_date, 1), interval -1 month)) and subdate(current_date, 1)
			and (loan_payment.paid_at_date is null or loan_payment.paid_at_date between date(date_add(subdate(current_date, 1), interval -1 month)) and subdate(current_date, 1))
            /* payment due date before date of top up/extension/repayment plan, the check is to exclude all payments of parent loan after child loan of listed type emerged */
			and (loan_payment.actual_payment_date <= coalesce(loan.topped_up_at, loan.extended_at, loan.arranged_rp_at, '2999-12-31'))
			)
            /* payment due date is out of reporting period, but paid in the reporting period */
			or (loan_payment.paid_at_date between date(date_add(subdate(current_date, 1), interval -1 month)) and subdate(current_date, 1)
			and loan_payment.actual_payment_date > subdate(current_date, 1))
            /* payment before reporting period, but not yet paid, in active overdue state */
            or (loan_payment.actual_payment_date < date(date_add(subdate(current_date, 1), interval -1 month))
				and loan_payment.paid_at_date is null
            ))
        /* join all payments after already paid to calculate total outstanding amount at the current point */
	left join (
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
						join -- reporting.james_loans loan
                        peachy_prod.loan
							on loan.id = lp.loan_id
                    where lp.is_next_payment = 1
                    and lp.deleted_at is null
                    and loan.id = '703727'
                     group by lp.loan_id, lp.actual_payment_date
            ) lpd
            on lp.loan_id = lpd.loan_id and lp.actual_payment_date >= lpd.actual_payment_date
    where lp.deleted_at is null
    group by lp.loan_id
    ) total_outstanding
		on loan.id = total_outstanding.loan_id	

where /* loan_payment.actual_payment_date between date(date_add(subdate(current_date, 1), interval -1 month)) and subdate(current_date, 1)
	and */ loan.id = '703727'
group by loan.id
		,loan.original_loan_application_id
        ,loan_payment.actual_payment_date
        -- ,loan.original_application_id
		,date_format(now(), '%Y-%m-01')
order by loan.original_loan_application_id desc, loan.id desc
;