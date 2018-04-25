use Data_Validation

if object_id('tempdb..#Data_Initial_Universe') is not null
drop table #Data_Initial_Universe

select Distinct(USI) as USI,
lea_Code,
School_Code,
Grade,
dob,
'null'  as Overage_indicator
into #Data_initial_Universe
from [dbo].[enrollments]

select datediff(year,'2002-09-30','2017-09-30')
select distinct date
,g9=ltrim(year(dateadd(year,-15,date)))+'-09-30' 
,g10=ltrim(year(dateadd(year,-16,date)))+'-09-30'
,g11=ltrim(year(dateadd(year,-17,date)))+'-09-30'
,g12=ltrim(year(dateadd(year,-18,date)))+'-09-30' 
 from ossedaarprd02.authoritative_stg.dbo.date_table a 
 where datepart(day,date)=30 and datepart(month,date)=9 and date>=dateadd(year,-1,getdate())
--where --a.schoolyear like '%'+ltrim(year(getdate()))+'%' 
-- (date=ltrim(year(getdate()))+'-09-30'
--or date=ltrim(year(dateadd(year,-1,getdate())))+'-09-30') 
order by date

     update  #Data_initial_Universe
	  SET    [overage_indicator]='YES'
       WHERE  ((Grade = '09') AND ([dob] <= CONVERT(DATETIME, '9/30/2002', 102)) --15
              or  (Grade = '10') AND ([dob] <= CONVERT(DATETIME, '9/30/2001', 102))--16
              or  (Grade = '11') AND ([dob] <= CONVERT(DATETIME, '9/30/2000', 102))--17
              or  (Grade = '12') AND ([dob] <= CONVERT(DATETIME, '9/30/1999', 102)))--18


			  select * from #Data_initial_Universe where overage_indicator='YES'


-- Now pull the other 4 fields.

if object_id('tempdb..#other_indicators') is not null
drop table #other_indicators

select * into #other_indicators from ossedaarprd02.[Authoritative].[dbo].[osse_indicators_residency] 


if object_id('tempdb..#unique_indicators') is not null
drop table #unique_indicators

select distinct USI,
tanf_indicator,
snap_indicator,
cfsa_indicator,
housing_status
into #unique_indicators
from #other_indicators

-- to check if duplicates exists.
/*
select * from #unique_indicators where usi in 
(
select usi from #unique_indicators group by usi having count(usi)>1
) order by USi
*/

select * from #unique_indicators

if object_id('tempdb..#Staging') is not null
drop table #staging


select D.*,
u.tanf_indicator,
u.snap_indicator,
u.cfsa_indicator,
u.housing_status
--,
--u.overage_indicator
 into #staging
 from #Data_initial_Universe d left join #unique_indicators u on d.USI = u.USI


 update #staging set Overage_indicator='YES' where isnull(Overage_indicator,'') in ('Y','YES')
 update #staging set Overage_indicator=' ' where isnull(overage_indicator,'')='null'

 update #staging set tanf_indicator='YES' where isnull(tanf_indicator,'')='Y'
 update #staging set tanf_indicator='NO' where isnull(tanf_indicator,'')='N'

 update #staging set snap_indicator='YES' where isnull(snap_indicator,'')='Y'
 update #staging set snap_indicator='NO' where isnull(snap_indicator,'')='N'

 update #staging set cfsa_indicator='YES' where isnull(cfsa_indicator,'')='Y'
 update #staging set cfsa_indicator='NO' where isnull(cfsa_indicator,'')='N'

 update #staging set housing_status='YES' where isnull(housing_status,'')<>''
 update #staging set housing_status=' ' where isnull(housing_Status,'')=' '


 if object_id('tempdb..#final_data_to_push') is not null
 drop table #final_data_to_push

 select s.*,
 case  when ((isnull(Overage_indicator,'')='YES') 
 or (isnull(tanf_indicator,'')='YES')
 or (isnull(snap_indicator,'')='YES')
 or (isnull(cfsa_indicator,'')='YES')
 or (isnull(housing_status,'')='YES')
 ) then 'YES' else 'NO' End as 'At_Risk_OSSE_caliculated',
 getdate() as last_refreshed
 into #final_data_to_push
  from #staging s  


  update #final_data_to_push set At_Risk_OSSE_caliculated='NO' where grade in ('AW','AT','AL','ADULT','AN','AB','AG')

/* this grades have been included in our exclusion list.
AB	Adult Basic Education
AG	Adult GED
AL	Adult ELL
AN	Adult National External Diploma Program
AT	Adult Other 
AW	Adult Workforce Training
*/


select *  from #final_data_to_push where grade like 'A%'