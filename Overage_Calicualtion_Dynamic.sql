use data_validation

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


if object_id ('tempdb..#date_universe') is not null
drop table #date_universe

select distinct date
,g9=ltrim(year(dateadd(year,-15,date)))+'-09-30' 
,g10=ltrim(year(dateadd(year,-16,date)))+'-09-30'
,g11=ltrim(year(dateadd(year,-17,date)))+'-09-30'
,g12=ltrim(year(dateadd(year,-18,date)))+'-09-30' 
into #date_universe
 from ossedaarprd02.authoritative_stg.dbo.date_table a 
 where datepart(day,date)=30 and datepart(month,date)=9 and date>=dateadd(year,-1,getdate())
--where --a.schoolyear like '%'+ltrim(year(getdate()))+'%' 
-- (date=ltrim(year(getdate()))+'-09-30'
--or date=ltrim(year(dateadd(year,-1,getdate())))+'-09-30') 
order by date


select * into date_universe_overage_calicualtion from #date_universe

declare @grade_Years nvarchar(max)
set @grade_Years=
'select * into #grade_Years 
from #date_universe where DATEPART(YYYY,date)=case when DATEPART(MM,getdate()) > 9 then DATEPART(YYYY,getdate()) +1 else  DATEPART(YYYY,getdate())-1 end 
'
Exec(@grade_Years)

--build the dynamic script.

declare @where_class nvarchar(max)
set @where_class = '
select ((Grade=''09'') AND (DOB <=convert(DATETIME,'+g9+',102))
or (Grade =''10'') AND (DOB <= convert(DATETIME,'+g10+',102))
or (Grade =''11'') AND (DOB <= convert(DATETIME,'+g11+',102))
or (Grade =''12'') AND (DOB <= convert(DATETIME,'+g12+',102))
from date_universe_overage_calicualtion where DATEPART(YYYY,date)=case when DATEPART(MM,getdate()) > 9 then DATEPART(YYYY,getdate()) +1 else  DATEPART(YYYY,getdate())-1 end'

exec(@where_Class);
print(@where_class)