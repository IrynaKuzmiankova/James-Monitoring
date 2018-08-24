/* JAMES monitoring scripts
	Accepted applications
*/

select  loan_list.loan_id as Loan_ID
		,loan_list.external_id as External_ID
		,loan_list.application_id as Application_ID
        ,loan_list.original_application_id as Original_Application_ID
		,loan_list.issued_at as Date_of_Approval /* date of issue */
        ,loan_list.principal as Issued_Amount /* for top up = oustanding amount of previous loan + top up amount; for repayment = outstanding amount of previous loan*/
        ,loan_payment_first.actual_payment_date as First_payment_date
        ,loan_list.no_of_payments as Number_of_Payments
        ,round(((loan_list.principal + loan_list.initial_interest) - loan_list.annual_percentage_rate/365.25/100*loan_list.principal*datediff(loan_list.created_at,loan_list.issued_at))/loan_list.no_of_payments, 2) as Each_payment_avg
        /* could be a little bit different from backoffice numbers if date of confirmation is different to date of issue */
		,round(((loan_list.principal + loan_list.initial_interest) - loan_list.annual_percentage_rate/365.25/100*loan_list.principal*datediff(loan_list.created_at,loan_list.issued_at)),2) as Total_Repayable
        ,loan_list.loan_type as Type_of_Loan
from reporting.james_loans loan_list
	join peachy_prod.loan_payment loan_payment_first
		on loan_list.loan_id = loan_payment_first.loan_id
			and loan_payment_first.is_first_payment = 1
            and loan_payment_first.deleted_at is null
	where date(loan_list.created_at) between date_format(date(date_add(now(), interval -1 month)), '%Y-%m-01') -- first day of month
							and last_day(date(date_add(now(), interval -1 month))) -- last day of month
		
			
     /*   where date(loan_list.created_at) between '2018-06-01' -- first day of month
							and '2018-06-30' -- last day of month
				*/
				
group by loan_list.loan_id
		,loan_list.external_id
		,loan_list.application_id
        ,loan_list.original_application_id
		,loan_list.issued_at
        ,loan_list.principal
        ,loan_payment_first.actual_payment_date
        ,loan_list.no_of_payments
        ,loan_list.loan_type
;			

