/*
JAMES monitoring scripts
Monthly payments
*/

select  loan.loan_id as Loan_Id,
		loan.application_id as Application_ID 
        ,loan.original_application_id as Original_Application_Id
		,date_format(now(), '%Y-%m-01') as Reporting_Month
		,loan_type.name as Type_of_Loan
        /* max outstanding principal is used in order to show principal before payment (so always the first payment of the month is chosen) */
        ,max(loan_payment.principal + loan_payment.balance_left) as Outstanding_Principal
        ,sum(ifnull(loan_payment.principal,0)
			+ ifnull(loan_payment.interest,0)
            + ifnull(loan_payment.fees,0)
            + ifnull(loan_payment.penalty,0)
            + ifnull(loan_payment.discount,0)
            )
			as Due_payment
            
        ,sum(loan_payment.principal_paid
			+ loan_payment.interest_paid
            + loan_payment.fees_paid
            + loan_payment.penalty_paid
		 )
		   as Monthly_payment
		,sum(loan_payment.principal_paid) as Principal_Paid
        ,sum(loan_payment.interest_paid) as Interest_Paid
        ,sum(loan_payment.penalty) as Late_Payment_Interest
from reporting.james_loans loan
	join peachy_prod.loan_application appl
		on loan.application_id = appl.id
	join peachy_prod.type loan_type
		on loan.loan_type_id = loan_type.id
	join peachy_prod.loan_payment 
		on loan.loan_id = loan_payment.loan_id
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
        
group by loan.loan_id
		,loan.application_id
        ,loan.original_application_id
		,date_format(now(), '%Y-%m-01')
order by loan.application_id desc, loan.loan_id desc
;

