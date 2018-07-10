/* JAMES monitoring scripts
	Accepted applications
*/


select  loan_list.loan_id as Loan_ID
		,loan_list.application_id as Application_ID
        ,loan_list.original_application_id as Original_Application_ID
		-- ??? ,appl.parent_loan_application_id as Parent_Application_ID
		,loan_list.issued_at as Date_of_Approval /* date of issue */
        ,loan_list.principal as Issued_Amount /* for top up = oustanding amount of previous loan + top up amount; for repayment = outstanding amount of previous loan*/
        ,loan_payment_first.actual_payment_date as First_payment_date
        ,loan_list.no_of_payments as Number_of_Payments
        ,round(((loan_list.principal + loan_list.initial_interest) - loan_list.annual_percentage_rate/365.25/100*loan_list.principal*datediff(loan_list.created_at,loan_list.issued_at))/loan_list.no_of_payments, 2) as Each_payment_avg
        /* could be a little bit different from backoffice numbers if date of confirmation is different to date of issue */
		,round(((loan_list.principal + loan_list.initial_interest) - loan_list.annual_percentage_rate/365.25/100*loan_list.principal*datediff(loan_list.created_at,loan_list.issued_at)),2) as Total_Repayable
        ,loan_type.name as Type_of_Loan
from reporting.james_loans loan_list
	join peachy_prod.type loan_type
		on loan_list.loan_type_id = loan_type.id
	join peachy_prod.loan_application appl
		on loan_list.application_id = appl.id
	join peachy_prod.loan_payment loan_payment_first
		on loan_list.loan_id = loan_payment_first.loan_id
			and loan_payment_first.is_first_payment = 1
            and loan_payment_first.deleted_at is null
    
group by loan_list.loan_id
		,loan_list.application_id
		,loan_list.original_application_id
       -- ,appl.parent_loan_application_id 
		,loan_list.issued_at
        ,loan_list.principal
        ,loan_payment_first.actual_payment_date
        ,loan_list.no_of_payments
        ,loan_type.name
order by 2 desc
;			

