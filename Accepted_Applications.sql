/* JAMES monitoring scripts
	Accepted applications
*/

select  loan.id as Loan_ID,
		loan.original_loan_application_id as Original_Application_ID
		,appl.parent_loan_application_id as Parent_Application_ID
		,loan.loan_application_id as Child_Application_ID
		,loan.issued_at as Date_of_Approval /* date of issue */
        ,loan.principal as Issued_Amount /* for top up = oustanding amount of previous loan + top up amount; for repayment = outstanding amount of previous loan*/
        ,loan_payment_first.actual_payment_date as First_payment_date
        ,loan.no_of_payments as Number_of_Payments
        ,avg(loan_payment_avg.payment) as Each_payment_avg
        /* could be a little bit different from backoffice numbers if date of confirmation is different to date of issue */
		,((loan.principal + loan.initial_interest) - loan.annual_percentage_rate/365.25/100*loan.principal*datediff(loan.created_at,loan.issued_at)) as Total_Repayable
        ,loan_type.name as Type_of_Loan
from peachy_prod.loan 
	join peachy_prod.credit_score 
		on loan.loan_application_id = credit_score.loan_application_id
	join peachy_prod.credit_score_config conf
		on credit_score.credit_score_config_id = conf.id
        and conf.id = '58'  -- james scoring model
	join peachy_prod.type loan_type
		on loan.loan_type_id = loan_type.id
	join peachy_prod.loan_application appl
		on loan.loan_application_id = appl.id
	join peachy_prod.loan_payment loan_payment_first
		on loan.id = loan_payment_first.loan_id
			and loan_payment_first.is_first_payment = 1
            and loan_payment_first.deleted_at is null
	join peachy_prod.loan_payment loan_payment_avg
		on loan.id = loan_payment_avg.loan_id
            and loan_payment_avg.deleted_at is null
where date(loan.created_at) >= date(date_add(now(), interval -1 month))
		and loan.declined_at is null
        and loan.cancelled_at is null
        and loan.issued_at is not null
group by loan.id
		,loan.original_loan_application_id
        ,appl.parent_loan_application_id 
		,loan.loan_application_id
		,loan.issued_at
        ,loan.principal
        ,loan_payment_first.actual_payment_date
        ,loan.no_of_payments
        ,loan_type.name
order by 2 desc
;			
