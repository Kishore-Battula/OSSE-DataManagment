USE [Data_Validation]
GO

/****** Object:  StoredProcedure [dbo].[Sp_refresh_cohort_responsible_lea_school]    Script Date: 3/19/2018 5:04:44 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO




--Exec [dbo].[Sp_refresh_cohort_responsible_lea_school]

CREATE procedure [dbo].[Sp_refresh_cohort_responsible_lea_school]
as
Begin

if object_id('tempdb..#ini_unive') is NOt null
drop table #ini_unive

select Distinct d.USI,
d.lea_code,
d.[lea Name],
d.school_code,
d.[school name],
d.[current Enrolled Grade] as grade,
d.[First Name],
d.[Last Name],
D.[Date of Birth],
[Student Current Status],
[Enrollment Status],
d.[Enrollment Status Final],
[Stage 5 Entry Date],
[Stage 5 entry code],
[Stage 5 Exit Code],
[Stage 5 Exit Date]
into #ini_unive
from [data_validation_student_records_sy1718] d


-- Creating Degree and NOnDegreegranting Schools.

if object_id ('tempdb..#NOn_degree_granting_schools') is NOt null
drop table #NOn_degree_granting_schools
select [school_id(state)] as SchoolCode,[lea_id (State)] as lea_code into #NOn_degree_granting_schools from [dbo].degree_granting_schools where [NOn-Granting school]='Y'


if object_id('tempdb..#degree_granting_schools') is NOt null
drop table #degree_granting_Schools
Select [school_id(state)] as SchoolCode , [lea_id (State)] as lea_code into #degree_granting_schools from   [dbo].degree_granting_schools where [Degree Granting school?]='Y'


-- NOw determine the most recent enrollment to determine if the kid is currently enrolled or exited.

if object_id('tempdb..#most_recent_enrollment') is NOt null
drop table #most_recent_enrollment

select b.* into #most_recent_enrollment from 
(
select Distinct(USI),
Lea_Code,
School_code,
[Stage 5 Entry Date],
[Stage 5 Exit Date],
[Stage 5 Exit Code],
Rank() over (partition by USI order by cast([Stage 5 Entry date] as date)desc ,cast([Stage 5 Exit date] as date) desc) as r1
 from #ini_unive 
 )b where r1='1'


  if object_id('tempdb..#dupes') is NOt null
 drop table #dupes

 select * into #dupes from #most_recent_enrollment m where usi in
  (
  select usi from #most_recent_enrollment group by usi having count(*)>1
  )order by USI

  if object_id('tempdb..#degree_granting_student') is NOt null
  drop table #degree_granting_student

 select s.* into #degree_granting_student from #dupes s join #degree_granting_schools d on d.schoolcode = s.school_code
  

  if object_id('tempdb..#still_dupes') is NOt null
  drop table #still_dupes

  select s.* into #still_dupes from #dupes s  left join (  select s.USI from #dupes s join #degree_granting_schools d on d.schoolcode = s.school_code) c
  on s.usi = c.usi where isnull(c.usi,'')=''

  if object_id('tempdb..#unique_dupes') is NOt null
  drop table #unique_dupes

   select b.* 
  into #unique_dupes
  from (
  select s.*,
  Row_Number() over (partition by usi order by School_Code desc) as r2
   from #still_dupes s
   )b where r2='1'


   if object_id('tempdb..#student_current_status') is NOt null
   drop table #student_current_status

   select b.*,
   case when isnull([Stage 5 Exit date],'')='' or isnull([Stage 5 Exit code],'')='' then 'Currently Active' else 'Currently Completely Inactive' End as Current_Status
   into #student_current_Status
   from
   (
   select E.USI,E.Lea_Code,E.School_Code,E.[Stage 5 Entry Date],E.[Stage 5 Exit date], E.[Stage 5 Exit Code] from #most_recent_enrollment E left join #dupes d on E.usi  = d.usi where isnull(d.usi,'')=''
   union
   select USI,Lea_Code,School_Code,[Stage 5 Entry Date],[Stage 5 Exit date], [Stage 5 Exit Code] from #degree_granting_student
   UNIOn
   Select USI,Lea_Code,School_Code,[Stage 5 Entry Date],[Stage 5 Exit date], [Stage 5 Exit Code] from #unique_dupes 
   )b


   select * from #student_current_status

   if object_id('tempdb..#updated_univ') is NOt null
   drop table #updated_univ

   select Distinct u.*,
   case when u.[Enrollment Status] <>'Enrolled' then s.school_code  End as current_Enrolled_SchoolCode,
   case when u.[Enrollment Status] <>'Enrolled' then S.lea_code End as Current_Enrolled_LeaCode,
   case when u.[Enrollment Status] <>'Enrolled' then s.[Stage 5 Entry Date] End as Current_Enrolled_Stage5Date   
  into  #updated_univ
  from #ini_unive u left join (select * from #student_current_Status -- where current_Status not like 'Currently Active'
  ) s on u.usi = s.USI


if object_id('tempdb..#data_unive') is NOt null
drop table #data_unive

select distinct b.* into #data_unive
from
(
select * from #updated_univ where grade in ('09','9','10','11','12') or grade like 'C%'
UNION
Select a.* from #updated_univ a  join #degree_granting_schools b 
on a.school_code = b.[SchoolCode] and a.lea_code = b.[lea_code]
where  a.grade NOt in ('P3','PK3','PK4','KG','P4','01','1','02','2','03','3','04','4','05','5','06','6','07','7','08','8')
)b

/* Update the NOnpublic school Name */

   
if object_id('tempdb..#NOnpublic_schoolslist') is NOt null
drop table #NOnpublic_schoolslist

select Distinct(LEA_Name),
LEA_ID,
School_Name,
School_Id
into #NOnpublic_schoolslist
from [OSSEDAARPRD02].[Authoritative_STG].[slims].[leas_schools_sites_current_schoolyear] where lea_id='5000'

Update i set i.[School Name]='Non-Public School' from #data_unive i join #NOnpublic_schoolslist n on i.School_Code = n.School_Id


-- NOw pull the Exits from Exit Mangement---

IF OBJECT_ID('tempdb..#f') IS NOT NULL
DROP TABLE #f
select s.displaystatus,w.status,a.* 
into #f 
from [OSSEUSIPRDDB01].[SLEDAPPS].[leap2].[ExitEnrollments] a
left outer join [OSSEUSIPRDDB01].[SLEDAPPS].[leap].[LookupExitStatus] s 
on a.exitstatusid = s.exitstatusid 
left outer join [OSSEUSIPRDDB01].[SLEDAPPS].[leap].[LookupWorkflowStatus] w
on a.workflowid = w.statusid 
where schoolYear='2017-18'

update #f set leaid ='1' where leaid='001'

if object_id('tempdb..#data_aggregation') is NOt null
drop table #data_aggregation

select d.*,
d.[Enrollment Status Final] as Enrollment_Indicator,
'YES' as ACGR_universe,
' ' as EX_MN_ExitCode,
' ' as EX_MN_ExitDate,
' ' as EX_MN_DisplayStatus,
' ' as Exit_indicator,
' ' as [Cohort Responsible LEA Indicator],
' ' as [Cohort Responsible LEA Detail],
' ' as [Cohort Responsible School Indicator],
'  ' as [Cohort Responsible School Detail]
into #data_aggregation
 from #data_unive d

   -- Alter the column lengths to accomodate larger values---

alter table #data_aggregation alter column EX_MN_ExitCode varchar(Max) null
alter table #data_aggregation alter column EX_MN_ExitDate varchar(Max) null
alter table #data_aggregation alter column EX_MN_DisplayStatus varchar(Max) null
alter table #data_aggregation alter column Exit_indicator varchar(Max) null
alter table #data_aggregation alter column [Cohort Responsible LEA Indicator] varchar(Max) null
alter table #data_aggregation alter column [Cohort Responsible LEA Detail] varchar(Max) null
alter table #data_aggregation alter column [Cohort Responsible School Indicator] varchar(Max) null
alter table #data_aggregation alter column [Cohort Responsible School Detail] varchar(Max) null


-- while creating the enrollments table we decreased the exit date by 1 for powerschools, so while bumping aginst the exit management data update that exit date by 1
-- if we don't add one day, its NOt going to match against the exit managment data.

if object_id('tempdb..#powerschoolleas') is NOt null
	drop table #powerschoolleas

	select b.* into #powerschoolleas
	from
	(
	select distinct lea_Code from [OSSEDAARPRD01].seds_data_Exchange.dbo.attendance_powerschool_leas with (NOLOCK) where school_year='2017-2018'
	Union
	select '1' as lea_Code
	)b

update e set e.[Stage 5 exit date]= DateADD(Day,1,cast(e.[Stage 5 exit date]as date)) 
from #data_aggregation e join #powerschoolleas p on e.lea_code = p.lea_code 
where isnull(e.[Stage 5 exit date],'')<>''

-- Update exit management data to our universe to determine the exit/enrollment indicator.

update a set a.Ex_MN_ExitCode= f.EnrollmentExitCode,
              a.Ex_MN_ExitDate= f.EnrollmentExitdate,
			  a.EX_MN_DisplayStatus =f.DisplayStatus 
			  from #data_aggregation a 
join #f f on a.usi = f.usi and a.lea_code = f.leaid 
and a.school_code = f.schoolid
and a.[Stage 5 exit code]= f.[EnrollmentExitCode]  
and cast(a.[Stage 5 Exit date] as date)= cast(f.[EnrollmentExitDate] as date)

-- update Exit and enrollment indicators.

update s set s.Enrollment_Indicator='Exited' from #data_aggregation s where isnull(Enrollment_Indicator,'')='' 
and isnull([Stage 5 Exit Date],'')<>'' and isnull([Stage 5 Exit code],'')<>''

update s set s.Enrollment_Indicator='Enrolled' from #data_aggregation s where isnull(Enrollment_Indicator,'')='' 
and (( isnull([Stage 5 Exit Date],'')='') or (isnull([Stage 5 Exit code],'')=''))

Update s set s.Enrollment_Indicator = 'Exited' from #data_aggregation s where Enrollment_Indicator = 'Withdrawn'

update #data_aggregation set Exit_Indicator='NA' where isnull(Enrollment_Indicator,'') like 'Enrolled'
update #data_aggregation set Exit_Indicator='Incomplete' where isnull(Enrollment_Indicator,'') like 'Exited' and ((isnull(EX_MN_DisplayStatus,'') like '%pending%') or (isnull(EX_MN_DisplayStatus,'') like 'OSSE NOt Accepted Exits'))
update #data_aggregation set Exit_indicator='Incomplete' where isnull(Enrollment_Indicator,'') like 'Exited'  and isnull([Stage 5 Exit Code],'')=''
update #data_aggregation set Exit_indicator='Complete' where isnull(Enrollment_Indicator,'') like 'Exited' and isnull(EX_MN_DisplayStatus,'') like '%OSSE Accepted%'
update #data_aggregation set Exit_Indicator='Complete'  where isnull(Enrollment_Indicator,'')='Exited' and isnull(Exit_indicator,'')=''


if object_id('tempdb..#cohort_responsible_lea_detail') is NOt null
drop table #cohort_responsible_lea_detail

select Distinct USI,
lea_code,
School_Code,
[school name] as School_name,
[Stage 5 exit date] as Exit_date,
[Stage 5 exit code] as exit_Code,
[Enrollment_Indicator],
Exit_indicator,
current_Enrolled_SchoolCode,
current_Enrolled_leaCode,
'     ' as [Responsible for IDEA Services],
'     ' as [Recently Enrolled, Incomplete Exit],
'     ' as [Transfer to State],
'     ' as [Transfer to Degree-Granting],
'     ' as [Transfer to NOn-Degree-Granting],
'     ' as [Recently Enrolled, NO Transfer],
'     ' as [Exited the State],
'     ' as [Currently Enrolled]
into #cohort_responsible_lea_detail
from #data_aggregation


---2 Recently Enrolled, Incomplete Exit

update #cohort_responsible_lea_detail set [Recently Enrolled, Incomplete Exit]='YES' where isnull([Enrollment_Indicator],'')='Exited'
and isnull([Exit_indicator],'')='Incomplete' and  [Exit_code] in ('1940','1941','1942','1943','1944')

-- 3 Tranfert to State 

update #cohort_responsible_lea_detail set [Transfer to State]='YES'
 where isnull([Enrollment_Indicator],'')='Exited'
and isnull([Exit_indicator],'')='complete' and  [Exit_code]  in ('2002','2040','2041','2042','2043') and current_Enrolled_SchoolCode in
(select distinct schoolcode from #NOn_degree_granting_schools)

and
(
 isnull([Enrollment_Indicator],'')='Exited'
and isnull([Exit_indicator],'')='complete' and  [Exit_code]  in ('2002','2040','2041','2042','2043') and ((current_Enrolled_SchoolCode in
('860','861','480','948','958','7000','8100')) or Current_Enrolled_LeaCode in ('4002')) )


---- 4) Tranfer to degree granting school

update #cohort_responsible_lea_detail set [Transfer to Degree-Granting]='YES'  where isnull([Enrollment_Indicator],'')='Exited'
and isnull([Exit_indicator],'')='complete' and  [Exit_code]  in ('2002','2040','2041','2042','2043') and current_Enrolled_SchoolCode in
(select distinct schoolcode from #degree_granting_schools)

-- New logic as of Kelly email.

update #cohort_responsible_lea_detail set [Transfer to Degree-Granting]='YES'  where isnull([Enrollment_Indicator],'')='Exited'
and isnull([Exit_indicator],'')='complete'  and current_Enrolled_SchoolCode in
(
select distinct school_id from #NOnpublic_schoolslist
)

-- 5) Transfer to NOn-degree - granting 


update #cohort_responsible_lea_detail set [Transfer to NOn-Degree-Granting]='YES' where isnull([Enrollment_Indicator],'')='Exited'
and isnull([Exit_indicator],'')='complete' and  [Exit_code]  in ('2002','2040','2041','2042','2043') and current_Enrolled_SchoolCode in
(select distinct schoolcode from #NOn_degree_granting_schools)


-- 6) Recently Enrolled, NO Transfer


update #cohort_responsible_lea_detail set [Recently Enrolled, NO Transfer]='YES'  where ((isnull([Enrollment_Indicator],'')='Exited'
and isnull([Exit_indicator],'')='Incomplete' and  [Exit_code] NOt in ('1940','1941','1942','1943','1944'))
OR
(
 isnull([Enrollment_Indicator],'')='Exited'
and isnull([Exit_indicator],'')='complete' and  [Exit_code] NOt in ('2002','2040','2041','2042','2043','1940','1941','1942','1943','1944')
))

-- New updated based on Kelly email.

update #cohort_responsible_lea_detail set  [Recently Enrolled, NO Transfer]='YES' where isnull(exit_Code,'')='' 
and Enrollment_Indicator='Exited' and [Exit_indicator]='Incomplete'

 -- 7) Exited the state

update #cohort_responsible_lea_detail set [Exited the State]='YES' where isnull([Enrollment_Indicator],'')='Exited'
and isnull([Exit_indicator],'')='Complete' and  [Exit_code] in ('1940','1941','1942','1943','1944')

-- 8) currently Enrolled

update #cohort_responsible_lea_detail set [Currently Enrolled]='YES' where isnull([Enrollment_Indicator],'')='Enrolled'


-- 1) Responsible for IDE Services

update #cohort_responsible_lea_detail set [Responsible for IDEA Services]='YES' where 
((isnull([Enrollment_Indicator],'')='Enrolled' and School_name like 'NOn-Public School') OR
(isnull([Recently Enrolled, NO Transfer],'')='YES' and school_Name like 'NOn-Public School') OR
(isnull([Recently Enrolled, Incomplete Exit],'')='YES' and school_Name like 'NOn-public school') or
(isnull([Transfer to NOn-Degree-granting],'')='YES' and school_Name like 'NOn-public school'))


-- NOw update the original table in the sequence.

update d set d.[Cohort Responsible LEA Detail]='Responsible for IDEA Services' 
from #data_aggregation d join #cohort_responsible_lea_detail c 
on d.usi = c.usi 
and d.lea_code = c.lea_code
and d.school_code = c.school_code 
--and d.[Stage 5 Exit code]= c.Exit_code 
and d.Enrollment_Indicator= c.Enrollment_Indicator
where c.[Responsible for IDEA Services]='YES'

update d set d.[Cohort Responsible LEA Detail]='Recently Enrolled, Incomplete Exit' 
from #data_aggregation d join #cohort_responsible_lea_detail c 
on d.usi = c.usi 
and d.lea_code = c.lea_code
and d.school_code = c.school_code
and isnull(d.[Stage 5 Exit code],'')= isnull(c.Exit_code ,'')
and isnull(d.[Stage 5 Exit date],'')= isnull(c.Exit_date,'')
and d.Enrollment_Indicator= c.Enrollment_Indicator
where c.[Recently Enrolled, Incomplete Exit]='YES'
 

 update d set d.[Cohort Responsible LEA Detail]='Transfer to State' 
from #data_aggregation d join #cohort_responsible_lea_detail c 
on d.usi = c.usi 
and d.lea_code = c.lea_code 
and d.school_code = c.school_code
and isnull(d.[Stage 5 Exit code],'')= isnull(c.Exit_code ,'')
and isnull(d.[Stage 5 Exit date],'')= isnull(c.Exit_date,'')
and d.Enrollment_Indicator= c.Enrollment_Indicator
where c.[Transfer to State]='YES' 

update d set d.[Cohort Responsible LEA Detail]='Transfer to Degree-Granting' 
from #data_aggregation d join #cohort_responsible_lea_detail c 
on d.usi = c.usi 
and d.lea_code = c.lea_code 
and d.school_code = c.school_code
and isnull(d.[Stage 5 Exit code],'')= isnull(c.Exit_code ,'')
and isnull(d.[Stage 5 Exit date],'')= isnull(c.Exit_date,'')
and d.Enrollment_Indicator= c.Enrollment_Indicator
where c.[Transfer to Degree-Granting]='YES'


update d set d.[Cohort Responsible LEA Detail]='Transfer to NOn-Degree-Granting' 
from #data_aggregation d join #cohort_responsible_lea_detail c 
on d.usi = c.usi 
and d.lea_code = c.lea_code 
and d.school_code = c.school_code
and isnull(d.[Stage 5 Exit code],'')= isnull(c.Exit_code ,'')
and isnull(d.[Stage 5 Exit date],'')= isnull(c.Exit_date,'')
and d.Enrollment_Indicator= c.Enrollment_Indicator
where c.[Transfer to NOn-Degree-Granting]='YES' 


update d set d.[Cohort Responsible LEA Detail]='Recently Enrolled, NO Transfer' 
from #data_aggregation d join #cohort_responsible_lea_detail c 
on d.usi = c.usi 
and d.lea_code = c.lea_code 
and d.school_code = c.school_code
and isnull(d.[Stage 5 Exit code],'')= isnull(c.Exit_code ,'')
and isnull(d.[Stage 5 Exit date],'')= isnull(c.Exit_date,'')
and d.Enrollment_Indicator= c.Enrollment_Indicator
where c.[Recently Enrolled, NO Transfer]='YES'

update d set d.[Cohort Responsible LEA Detail]='Exited the State' 
from #data_aggregation d join #cohort_responsible_lea_detail c 
on d.usi = c.usi 
and d.lea_code = c.lea_code
and d.school_code = c.school_code 
and isnull(d.[Stage 5 Exit code],'')= isnull(c.Exit_code ,'')
and isnull(d.[Stage 5 Exit date],'')= isnull(c.Exit_date,'')
and d.Enrollment_Indicator= c.Enrollment_Indicator
where c.[Exited the State]='YES'

update d set d.[Cohort Responsible LEA Detail]='Currently Enrolled' 
from #data_aggregation d join #cohort_responsible_lea_detail c 
on d.usi = c.usi 
and d.lea_code = c.lea_code
and d.school_code = c.school_code 
and d.Enrollment_Indicator= c.Enrollment_Indicator
where c.[Currently Enrolled]='YES'

-- The following two updates are made based on Kelly's email.

update d set d.[Cohort Responsible LEA Detail]='Transfer to NOn-Degree-Granting'  from
#data_aggregation d    where 
School_Code='947' and Enrollment_Indicator='Enrolled'

update d set d.[Cohort Responsible LEA Detail]='Transfer to State'  from
#data_aggregation d    
where
school_code in ('861','480') and enrollment_Indicator='Enrolled'

------ Update Cohort Responsible lea indicator.

  -- cohort responsible lea indicator.

	update d set d.[cohort Responsible lea indicator]= 'YES' from  #data_aggregation d where [Cohort Responsible LEA Detail]='Responsible for IDEA Services'
	update d set d.[cohort Responsible lea indicator]= 'NO' from  #data_aggregation d where [Cohort Responsible LEA Detail]='Transfer to State'
	update d set d.[cohort Responsible lea indicator]= 'YES' from  #data_aggregation d where [Cohort Responsible LEA Detail]='Recently Enrolled, Incomplete Exit'
	update d set d.[cohort Responsible lea indicator]= 'NO' from  #data_aggregation d where [Cohort Responsible LEA Detail]='Transfer to Degree-Granting'
	update d set d.[cohort Responsible lea indicator]= 'YES' from  #data_aggregation d where [Cohort Responsible LEA Detail]='Transfer to NOn-Degree-Granting'
	update d set d.[cohort Responsible lea indicator]= 'NO' from  #data_aggregation d where [Cohort Responsible LEA Detail]='Exited the State'
	update d set d.[cohort Responsible lea indicator]= 'YES' from  #data_aggregation d where [Cohort Responsible LEA Detail]='Recently Enrolled, NO Transfer'
	update d set d.[cohort Responsible lea indicator]= 'YES' from  #data_aggregation d where  [Cohort Responsible LEA Detail]='Currently Enrolled'
	and School_code in (select schoolcode from #degree_granting_schools) or (([School Name] like 'NOn-Public School') and ([Cohort Responsible LEA Detail]='Currently Enrolled'))

	-- Update the Responsible school detail.
update d set d.[Cohort Responsible School Detail]='Responsible for IDEA Services' 
from #data_aggregation d join #cohort_responsible_lea_detail c 
on d.usi = c.usi 
and d.lea_code = c.lea_code
and d.school_code = c.school_code 
--and d.[Stage 5 Exit code]= c.Exit_code 
and d.Enrollment_Indicator= c.Enrollment_Indicator
where c.[Responsible for IDEA Services]='YES'


update d set d.[Cohort Responsible school Detail]='Recently Enrolled, Incomplete Exit' 
from #data_aggregation d join #cohort_responsible_lea_detail c 
on d.usi = c.usi 
and d.lea_code = c.lea_code 
and d.school_code = c.school_code
and isnull(d.[Stage 5 Exit code],'')= isnull(c.Exit_code ,'')
and isnull(d.[Stage 5 Exit date],'')= isnull(c.Exit_date,'')
and d.Enrollment_Indicator= c.Enrollment_Indicator
where c.[Recently Enrolled, Incomplete Exit]='YES'

update d set d.[Cohort Responsible school Detail]='Transfer to State' 
from #data_aggregation d join #cohort_responsible_lea_detail c 
on d.usi = c.usi 
and d.lea_code = c.lea_code 
and d.school_code = c.school_code
and isnull(d.[Stage 5 Exit code],'')= isnull(c.Exit_code ,'')
and isnull(d.[Stage 5 Exit date],'')= isnull(c.Exit_date,'')
and d.Enrollment_Indicator= c.Enrollment_Indicator
where c.[Transfer to State]='YES'   


update d set d.[Cohort Responsible School Detail]='Transfer to Degree-Granting' 
from #data_aggregation d join #cohort_responsible_lea_detail c 
on d.usi = c.usi 
and d.lea_code = c.lea_code 
and d.school_code = c.school_code
and isnull(d.[Stage 5 Exit code],'')= isnull(c.Exit_code ,'')
and isnull(d.[Stage 5 Exit date],'')= isnull(c.Exit_date,'')
and d.Enrollment_Indicator= c.Enrollment_Indicator
where c.[Transfer to Degree-Granting]='YES'


update d set d.[Cohort Responsible School Detail]='Transfer to NOn-Degree-Granting' 
from #data_aggregation d join #cohort_responsible_lea_detail c 
on d.usi = c.usi 
and d.lea_code = c.lea_code 
and d.school_code = c.school_code
and isnull(d.[Stage 5 Exit code],'')= isnull(c.Exit_code ,'')
and isnull(d.[Stage 5 Exit date],'')= isnull(c.Exit_date,'')
and d.Enrollment_Indicator= c.Enrollment_Indicator
where c.[Transfer to NOn-Degree-Granting]='YES' 



update d set d.[Cohort Responsible School Detail]='Recently Enrolled, NO Transfer' 
from #data_aggregation d join #cohort_responsible_lea_detail c 
on d.usi = c.usi 
and d.lea_code = c.lea_code 
and d.school_code = c.school_code
and isnull(d.[Stage 5 Exit code],'')= isnull(c.Exit_code ,'')
and isnull(d.[Stage 5 Exit date],'')= isnull(c.Exit_date,'')
and d.Enrollment_Indicator= c.Enrollment_Indicator
where c.[Recently Enrolled, NO Transfer]='YES'

update d set d.[Cohort Responsible School Detail] ='Exited the State' 
from #data_aggregation d join #cohort_responsible_lea_detail c 
on d.usi = c.usi 
and d.lea_code = c.lea_code 
and d.school_code = c.school_code
and isnull(d.[Stage 5 Exit code],'')= isnull(c.Exit_code ,'')
and isnull(d.[Stage 5 Exit date],'')= isnull(c.Exit_date,'')
and d.Enrollment_Indicator= c.Enrollment_Indicator
where c.[Exited the State]='YES'



update d set d.[Cohort Responsible School Detail] ='Currently Enrolled' 
from #data_aggregation d join #cohort_responsible_lea_detail c 
on d.usi = c.usi 
and d.lea_code = c.lea_code 
and d.school_code = c.school_code
and d.Enrollment_Indicator= c.Enrollment_Indicator
where c.[Currently Enrolled]='YES'

update d set d.[Cohort Responsible school Detail]='Transfer to NOn-Degree-Granting'  from
#data_aggregation d    where 
School_Code='947' and Enrollment_Indicator='Enrolled'



update d set d.[Cohort Responsible school Detail]='Transfer to State'  from
#data_aggregation d    
where
school_code in ('861','480') and enrollment_Indicator='Enrolled'


-- update the cohort responsible school indicator.

		
	update d set d.[cohort Responsible school indicator]= 'YES' from  #data_aggregation d where  [Cohort Responsible school Detail]='Currently Enrolled'
	and School_code in (Select schoolcode from #degree_granting_schools) or (([School Name] like 'NOn-Public School') and ([Cohort Responsible School Detail] ='Currently Enrolled'))
	update d set d.[cohort Responsible school indicator]= 'YES' from  #data_aggregation d where [Cohort Responsible school Detail]='Recently Enrolled, NO Transfer'
	update d set d.[cohort Responsible school indicator]= 'YES' from  #data_aggregation d where [Cohort Responsible school Detail]='Recently Enrolled, Incomplete Exit'
	update d set d.[cohort Responsible school indicator]= 'NO' from  #data_aggregation d where [Cohort Responsible school Detail]='Transfer to Degree-Granting'
	update d set d.[cohort Responsible school indicator]= 'YES' from  #data_aggregation d where [Cohort Responsible school Detail]='Transfer to NOn-Degree-Granting'
	update d set d.[cohort Responsible school indicator]= 'NO' from  #data_aggregation d where [Cohort Responsible school Detail]='Transfer to State'
	update d set d.[cohort Responsible school indicator]= 'YES' from  #data_aggregation d where [Cohort Responsible school Detail]='Responsible for IDEA Services'
	update d set d.[cohort Responsible school indicator]= 'NO' from  #data_aggregation d where [Cohort Responsible school Detail]='Exited the State'
	
	
	if object_id('tempdb..#multiple_cohorts_universe') is NOt null
	drop table #multiple_cohorts_universe

	select * into #multiple_cohorts_universe from #data_aggregation where usi in  
	(
	select b.usi from 
	(
	select usi,count([Cohort Responsible LEA Indicator]) as cnt from #data_aggregation
	where isnull([Cohort Responsible LEA Indicator],'')='YES' group by usi,[Cohort Responsible LEA Indicator] 
     ) b where cnt>1
	)

	if object_id('tempdb..#multipleuniverse_currentlyenrolled') is NOt null
	drop table #multipleuniverse_currentlyenrolled
	select * into #multipleuniverse_currentlyenrolled from #multiple_cohorts_universe where [cohort responsible lea detail]='Currently Enrolled'

	

	update  d   set [Cohort Responsible LEA Indicator]='NO' ,
	[Cohort Responsible School Indicator] = 'NO'
    from
	 #data_aggregation d  join #multipleuniverse_currentlyenrolled c on d.usi = c.usi 
	where isnull(d.[Cohort Responsible LEA Detail],'')<>'Currently Enrolled'



	truncate table cohort_data_aggregation
	insert into cohort_data_aggregation
	select distinct * from #data_aggregation

	select * from cohort_data_aggregation where enrollment_indicator='Exited'

	-- Refresh the table that Qlik App uses.

truncate table data_validation.dbo.cohort_data_aggregation_Qlik_data

insert into data_validation.dbo.cohort_data_aggregation_Qlik_data
select Distinct [LEA Name],
[LEA_Code],
[School Name],
[School_Code],
USI,
[First Name] as [Student First Name],
[Last Name ] as [Student Last Name],
[Date of Birth] as [Student Date of BIrth],
[ACGR_Universe],
[Enrollment_Indicator],
[Exit_Indicator],
[cohort Responsible lea indicator],
[cohort Responsible Lea Detail],
[cohort responsible School indicator],
[cohort responsible school detail]
from
data_validation.dbo.cohort_data_aggregation





	End


	




GO


