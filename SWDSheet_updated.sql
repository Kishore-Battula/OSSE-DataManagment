create procedure Sp_refresh_currentsped
as
begin

if object_id('tempdb..#eacc') is not null
drop table #eacc

select distinct s.id as Student_id,
a.*,
null as curiepeventid,
null as EligibilityEventID 
into #eacc
from  (select distinct usi as Studentcode,case when isnull(lea_code,'') = '001' then '1' else lea_code end as [district code], school_code from enrollments ) a
inner join (select * from [OSSEDAARPRD01].[seds_data_exchange].dbo.easyiep_students) s
on a.Studentcode = s.studentcode and a.[district code] = s.[district code]


if object_id('tempdb..#easyiep_events') is not null
drop table #easyiep_events

select * into #easyiep_events from 
[OSSEDAARPRD01].[seds_data_exchange].dbo.easyiep_events 
where inactive = '0' and eventtype in ('1','2','7','54','55','110','147') 


if object_id('tempdb..#events') is not null
drop table #events

select a.studentcode,
a.[district code],
a.student_id as studentid,
e.id,
e.eventtype,
e.eventdate,
e.begindate,
e.enddate,
e.DateCreated,
e.parenteventid,
e.sourcecustomername,
e.PrimaryDisability
into #events from #eacc a
inner join (select * from #easyiep_events where inactive = '0') e
on a.student_id = e.studentid and a.[district code] = e.[district code]


if object_id('tempdb..#MaxIEP_EligEvents') is not null
drop table #MaxIEP_EligEvents

Select TOP 100 PERCENT [District Code], Studentcode, studentid,eventtype, eventdate,id,begindate,enddate,parenteventid,sourcecustomername,datecreated, ROW_NUMBER() OVER (PARTITION BY StudentCode,EventType,[District Code] ORDER BY cast(eventdate as datetime) desc, cast(datecreated as datetime) desc,cast(id as int) desc) AS "Rank"  
into #MaxIEP_EligEvents from
(select * from #events where EventType in ('1','2')) a
Order by StudentCode



update a set a.curiepeventid = iep.id from #eacc a
inner join
(select * from #MaxIEP_EligEvents where eventtype = '2' and RANK = 1) iep
on a.studentcode = iep.studentcode and a.[district code] = iep.[district code]


if object_id('tempdb..#univ') is not null
drop table #univ

select a.*,iep.DateCreated as IEPDateCreated,iep.eventdate as IEPEventDate,iep.begindate as IEPBeginDate,iep.enddate as IEPEndDate,
elig.DateCreated as EligDateCreated,elig.EventDate as EligEventDate,elig.BeginDate as EligBeginDate,elig.EndDate as EligEndDate,iep.PrimaryDisability as IEP_PD 
into #univ from #eacc a
left outer join (select * from #events where eventtype = '2') iep
on a.studentcode = iep.studentcode and a.[district code] = iep.[district code] and a.curiepeventid = iep.id
left outer join (select * from #events where eventtype = '1') elig
on a.studentcode = elig.studentcode and a.[district code] = elig.[district code] and a.EligibilityEventID = elig.id



if object_id('tempdb..#AllNegaMaxEvents') is not null
drop table #AllNegaMaxEvents

Select TOP 100 PERCENT [District Code], Studentcode, studentid,eventtype, eventdate,id,begindate,enddate,parenteventid,sourcecustomername,datecreated, ROW_NUMBER() OVER (PARTITION BY StudentCode,[District Code] ORDER BY cast(eventdate as datetime) desc, cast(datecreated as datetime) desc,cast(id as int) desc) AS "Rank"  
into #AllNegaMaxEvents from
(select * from #events where EventType in ('7','54','55','110','147')) a
Order by StudentCode


---negative events after current iep---

select f.* into #negIEP from 
(
select iep.*   from
(select * from #univ where ISNULL(curiepeventid,'') <> '') iep 
inner join
(select * from #AllNegaMaxEvents where rank = '1') ne
on iep.studentcode = ne.studentcode and iep.[district code] = ne.[district code]
where cast(iep.IEPEventDate as datetime) = cast(ne.eventdate as datetime)  and cast(iep.IEPDateCreated as datetime) < cast(ne.datecreated as datetime)

union
select iep.*   from
(select * from #univ where ISNULL(curiepeventid,'') <> '') iep 
inner join
(select * from #AllNegaMaxEvents where rank = '1') ne
on iep.studentcode = ne.studentcode and iep.[district code] = ne.[district code]
where cast(iep.IEPEventDate as datetime) = cast(ne.eventdate as datetime)  and cast(iep.IEPDateCreated as datetime) = cast(ne.datecreated as datetime)
and CAST(iep.CurIEPEventID as int)  <  CAST(ne.ID  as int) 

union
select iep.*   from
(select * from #univ where ISNULL(curiepeventid,'') <> '') iep 
inner join
(select * from #AllNegaMaxEvents where rank = '1') ne
on iep.studentcode = ne.studentcode and iep.[district code] = ne.[district code]
where cast(iep.IEPEventDate as datetime) < cast(ne.eventdate as datetime)  
) f



update a 
set a.curiepeventid = NULL,
A.IEPDateCreated = NULL,
A.IEPEventDate = NULL,
A.IEPBeginDate = NULL,
A.IEPEndDate = NULL,
IEP_PD = null
from #univ a
inner join #negIEP b
on a.StudentCode = b.StudentCode and a.[District Code] = b.[District Code]


-- Elig

if object_id('tempdb..#negElig') is not null
drop table #negElig

select f.* into #negElig from 
(
select elig.*   from
(select * from #univ where ISNULL(EligibilityEventID,'') <> '') elig 
inner join
(select * from #AllNegaMaxEvents where rank = '1') ne
on elig.studentcode = ne.studentcode and elig.[district code] = ne.[district code]
where cast(elig.EligBeginDate as datetime) = cast(ne.eventdate as datetime)  and cast(elig.EligDateCreated as datetime) < cast(ne.datecreated as datetime)

union
select elig.*   from
(select * from #univ where ISNULL(EligibilityEventID,'') <> '') elig 
inner join
(select * from #AllNegaMaxEvents where rank = '1') ne
on elig.studentcode = ne.studentcode and elig.[district code] = ne.[district code]
where cast(elig.EligBeginDate as datetime) = cast(ne.eventdate as datetime)  and cast(elig.EligDateCreated as datetime) = cast(ne.datecreated as datetime)
and CAST(elig.EligibilityEventID as int)  <  CAST(ne.ID  as int) 

union
select elig.*   from
(select * from #univ where ISNULL(EligibilityEventID,'') <> '') elig 
inner join
(select * from #AllNegaMaxEvents where rank = '1') ne
on elig.studentcode = ne.studentcode and elig.[district code] = ne.[district code]
where cast(elig.EligBeginDate as datetime) < cast(ne.eventdate as datetime) 
) f




--remove negative elig from univ--
update #univ set EligibilityEventID = '',EligDateCreated = '',EligBeginDate = '',EligEndDate = '' where StudentCode in 
(select StudentCode  from #negElig)


--**********************only to get event dates-------------------
----- remove iep amendments only for event dates-----
select * into #IEP from #events where eventtype = '2'



---deleting the ammendment events from events ----
delete a from #iep as a
inner join 
(select studentcode ,studentid,lea,eventid,[IEPtype] as [IEP Type],AmendmentCategory from [OSSEDAARPRD01].[seds_data_exchange].dbo.SEDSGENUINEDATA_IEPamendment ) b
on a.studentid = b.studentid and a.[district code] = b.lea and a.[id] = b.eventid




--- max IEP event date (for event date, if there is amendment) --

IF OBJECT_ID('tempdb..#maxEvents_IEP_fordate') IS NOT NULL
drop table #maxEvents_IEP_fordate

select top 100 percent f.studentcode ,f.studentid,f.[district code],f.eventtype,f.id eventid,f.datecreated,f.eventdate,f.begindate,f.enddate,row_number() over(partition by f.studentcode,f.eventtype,[District Code] ORDER BY cast(f.eventdate as datetime) desc,cast(f.datecreated as datetime) desc,cast(f.id as int) desc) AS "Rank"
into #maxEvents_IEP_fordate 
from #IEP f
order by f.studentcode 




select f.* into #neg from 
(
select iep.*   from
(select * from #maxEvents_IEP_fordate where RANK = 1) iep 
inner join
(select * from #AllNegaMaxEvents where rank = '1') ne
on iep.studentcode = ne.studentcode and iep.[district code] = ne.[district code]
where cast(iep.EventDate as datetime) = cast(ne.eventdate as datetime)  and cast(iep.DateCreated as datetime) < cast(ne.datecreated as datetime)

union
select iep.*   from
(select * from #maxEvents_IEP_fordate where RANK = 1) iep 
inner join
(select * from #AllNegaMaxEvents where rank = '1') ne
on iep.studentcode = ne.studentcode and iep.[district code] = ne.[district code]
where cast(iep.EventDate as datetime) = cast(ne.eventdate as datetime)  and cast(iep.DateCreated as datetime) = cast(ne.datecreated as datetime)
and CAST(iep.eventid as int)  <  CAST(ne.ID  as int) 

union
select iep.*   from
(select * from #maxEvents_IEP_fordate where RANK = 1) iep 
inner join
(select * from #AllNegaMaxEvents where rank = '1') ne
on iep.studentcode = ne.studentcode and iep.[district code] = ne.[district code]
where cast(iep.EventDate as datetime) < cast(ne.eventdate as datetime)  
) f



update a 
set a.eventid = NULL,
A.datecreated = NULL,
A.eventdate = NULL,
A.begindate = NULL,
A.enddate = NULL

from (select * from #maxEvents_IEP_fordate where rank = 1) a
inner join #neg b
on a.StudentCode = b.StudentCode and a.[District Code] = b.[District Code] 

if object_id('tempdb..#univ_ini') is not null
drop table #univ_ini

select u.StudentCode,u.Student_id as StudentID,null as STARS_ID, u.[District Code] as LEACode,ln.lea_name as LEAname,
c.SchoolType as LEAtype,u.school_code as SchoolCode ,sch.name as SchoolName,c.[description] as SchoolType,u.IEP_PD as  PrimaryDisability,
null as ReferralDate,u.EligibilityEventID as eid_idea,
convert(varchar(10),CAST(u.EligEventDate as datetime),101) as eEventDate_idea,
convert(varchar(10),CAST(u.EligBeginDate as datetime),101) as eBeginDate_idea,
convert(varchar(10),CAST(u.EligEndDate as datetime),101) as eEndDate_idea,
u.EligDateCreated eDateCreated_idea,
u.CurIEPEventID as iid_idea_fin,
Case when ISNULL(u.CurIEPEventID,'') <> '' then 
convert(varchar(10),CAST(u.IEPEventDate as datetime),101) else NULL END AS iEventDate_idea_fin,
Case when ISNULL(u.CurIEPEventID,'') <> '' then
convert(varchar(10),CAST(u.IEPBeginDate as datetime),101) ELSE NULL END AS iBeginDate_idea_fin,
Case when ISNULL(u.CurIEPEventID,'') <> '' then
convert(varchar(10),CAST(u.IEPEndDate as datetime),101) ELSE NULL END AS iEndDate_idea_fin,
u.IEPDateCreated as iDateCreated_idea_fin,
u.IEP_PD as iepPD_idea_fin,
iep.eventid as iid_fordate,
convert(varchar(10),CAST(iep.EventDate  as datetime),101) as iEventDate_fordate,
convert(varchar(10),CAST(iep.BeginDate  as datetime),101) as iBeginDate_fordate,
convert(varchar(10),CAST(iep.EndDate  as datetime),101) as iEndDate_fordate,
iep.DateCreated as iDateCreated_fordate
into #univ_ini from (select * from #univ  where ISNULL(curiepeventid,'') <> '' or ISNULL(EligibilityEventID,'') <> '')  u
left outer join (select * from #maxEvents_IEP_fordate where RANK = 1) iep
on u.StudentCode = iep.StudentCode and u.[District Code] = iep.[District Code]
left outer join 
(select * from [OSSEDAARPRD01].[seds_data_exchange].dbo.easyiep_schools where inactive = '0') sch
on u.[district code] = sch.[district code] and u.school_code = sch.schoolcode
left outer join  
[OSSEDAARPRD01].[seds_data_exchange].dbo.EasyIEP_LookUp_Category c
ON c.ID = Sch.Category  
left outer join 
(
select distinct  IIF(lea_id = 1, '001', lea_id) lea_code, lea_name from ossedaarprd02.authoritative_stg.slims.LEAS_SCHOOLS_SITES_CURRENT_SCHOOLYEAR
) ln
on u.[district code] = ln.lea_code




---recv services under IDEA as of today---
select *,
case 
when cast(iEventDate_idea_fin   as datetime) <= GETDATE() and cast(iEndDate_idea_fin   AS datetime) >= GETDATE() then 'YES'
 when (cast(eEventDate_idea   as datetime) <= GETDATE() and cast(eEnddate_idea   AS datetime) >= GETDATE())  and (cast(iEndDate_idea_fin AS datetime) < GETDATE())   then 'YES'
end as [Special Ed Eligibility Status] 
into #univ_sped from #univ_ini 


update #univ_ini set ieppd_idea_fin = PrimaryDisability where ISNULL(iepPD_idea_fin ,'') = ''



select * into #univ_ell from #univ_ini


----[view_HServices_Total_Mins_new_86]----
---outside mins---

--ipe end date < getdate---
Select allservices.Studentcode,allservices.[District Code], 
	Sum(Case allservices.TimePeriod
			When '1' 
					--Then ((CASE WHEN TimeSpent = '' THEN 0 ELSE Convert(decimal(10,2), TimeSpent) END) * ((Case Timeunits When '1' Then 1 Else 60 END) * 5 )* Case When NumSessions IS NULL Then 1 Else Convert(int, NumSessions) END)
					 Then (((CASE WHEN isnull(allservices.TimeSpent,'') <> '' THEN Convert(decimal(10,2), allservices.TimeSpent) else 0 END) * (Case allservices.Timeunits When '1' Then 1 Else 60 END)) * 5 )* (Case When isnull(allservices.NumSessions,'') = '' Then 1 Else Convert(int, allservices.NumSessions) END)
			When '2' 
					Then (((CASE WHEN isnull(allservices.TimeSpent,'') <> '' THEN Convert(decimal(10,2), allservices.TimeSpent) else 0 END) * (Case allservices.Timeunits When '1' Then 1 Else 60 END)) * 1 )* (Case When isnull(allservices.NumSessions,'') = '' Then 1 Else Convert(int, allservices.NumSessions) END)
			When '3' 
					Then (((CASE WHEN isnull(allservices.TimeSpent,'') <> '' THEN Convert(decimal(10,2), allservices.TimeSpent) else 0 END) * (Case allservices.Timeunits When '1' Then 1 Else 60 END))/4)* (Case When isnull(allservices.NumSessions,'') = '' Then 1 Else Convert(int, allservices.NumSessions) end)
			When '6' 
					Then (((CASE WHEN isnull(allservices.TimeSpent,'') <> '' THEN Convert(decimal(10,2), allservices.TimeSpent) else 0 END) * (Case allservices.Timeunits When '1' Then 1 Else 60 END)) / 36)* (Case When isnull(allservices.NumSessions,'') = '' Then 1 Else Convert(int, allservices.NumSessions) END)
	End) As After_Cal_TimePeriod
into #HServices_Total_Mins_exp_86
From 


(select services.*,iep.StudentCode,iep.iid_idea_fin MaxIEPID,iep.ibegindate_idea_fin maxIEPBeginDate,iep.ienddate_idea_fin maxIEPEndDate
from
(Select  h.[District Code], h.ID, h.StudentID, h.EventID, h.ServiceID,h.ServiceText, h.TimeSpent, h.TimeUnits, h.TimePeriod, h.NumSessions, h.Location, h.Inactive, h.BeginDate as IEPBeginDate ,h.ProviderID
From [OSSEDAARPRD01].[seds_data_exchange].dbo.EasyIEP_HStudentServices h 
inner join [OSSEDAARPRD01].[seds_data_exchange].dbo.EasyIEP_ServiceTypes t
on h.serviceid = t.serviceid
Where h.Location = '86'  
--AND (h.Consultation = '0' OR h.Consultation is NULL) 
and  (isnull(consultation,'') = '' or isnull(consultation,'') ='0')
AND (h.ExtendedSchoolYear = 'False' or isnull(h.ExtendedSchoolYear,'') = '' or h.extendedschoolyear = '0') And  (isnull(t.excludefrom618,'') = '') And (h.inactive = '0')) services
inner join (select distinct studentcode,StudentID,LEACode,iid_idea_fin,ibegindate_idea_fin,ienddate_idea_fin from #univ_ell ) iep

on services.studentid = iep.studentid and services.[district code] = iep.LEACode and services.eventid = iep.iid_idea_fin
where cast(iep.ienddate_idea_fin as datetime) < convert(varchar(10),GETDATE(),101)
) allservices
Group by allservices.Studentcode,allservices.[District Code]




--iep enddate> getdate()

Select allservices.Studentcode,allservices.[District Code], 
	Sum(Case allservices.TimePeriod
			When '1' 
					--Then ((CASE WHEN TimeSpent = '' THEN 0 ELSE Convert(decimal(10,2), TimeSpent) END) * ((Case Timeunits When '1' Then 1 Else 60 END) * 5 )* Case When NumSessions IS NULL Then 1 Else Convert(int, NumSessions) END)
					 Then (((CASE WHEN isnull(allservices.TimeSpent,'') <> '' THEN Convert(decimal(10,2), allservices.TimeSpent) else 0 END) * (Case allservices.Timeunits When '1' Then 1 Else 60 END)) * 5 )* (Case When isnull(allservices.NumSessions,'') = '' Then 1 Else Convert(int, allservices.NumSessions) END)
			When '2' 
					Then (((CASE WHEN isnull(allservices.TimeSpent,'') <> '' THEN Convert(decimal(10,2), allservices.TimeSpent) else 0 END) * (Case allservices.Timeunits When '1' Then 1 Else 60 END)) * 1 )* (Case When isnull(allservices.NumSessions,'') = '' Then 1 Else Convert(int, allservices.NumSessions) END)
			When '3' 
					Then (((CASE WHEN isnull(allservices.TimeSpent,'') <> '' THEN Convert(decimal(10,2), allservices.TimeSpent) else 0 END) * (Case allservices.Timeunits When '1' Then 1 Else 60 END))/4)* (Case When isnull(allservices.NumSessions,'') = '' Then 1 Else Convert(int, allservices.NumSessions) end)
			When '6' 
					Then (((CASE WHEN isnull(allservices.TimeSpent,'') <> '' THEN Convert(decimal(10,2), allservices.TimeSpent) else 0 END) * (Case allservices.Timeunits When '1' Then 1 Else 60 END)) / 36)* (Case When isnull(allservices.NumSessions,'') = '' Then 1 Else Convert(int, allservices.NumSessions) END)
	End) As After_Cal_TimePeriod
into #HServices_Total_Mins_curr_86
From 


(select services.*,iep.StudentCode,iep.iid_idea_fin MaxIEPID,iep.ibegindate_idea_fin maxIEPBeginDate,iep.ienddate_idea_fin maxIEPEndDate
from
(Select  h.[District Code], h.ID, h.StudentID, h.EventID, h.ServiceID,h.ServiceText, h.TimeSpent, h.TimeUnits, h.TimePeriod, h.NumSessions, h.Location, h.Inactive, h.BeginDate as ServiceBeginDate ,h.EndDate as ServiceEndDate,h.ProviderID
From [OSSEDAARPRD01].[seds_data_exchange].dbo.EasyIEP_HStudentServices h 
inner join [OSSEDAARPRD01].[seds_data_exchange].dbo.EasyIEP_ServiceTypes t
on h.serviceid = t.serviceid
Where h.Location = '86'  
--AND (h.Consultation = '0' OR h.Consultation is NULL) 
and  (isnull(consultation,'') = '' or isnull(consultation,'') ='0')
AND (h.ExtendedSchoolYear = 'False' or isnull(h.ExtendedSchoolYear,'') = '' or h.extendedschoolyear = '0') And  (isnull(t.excludefrom618,'') = '') And (h.inactive = '0')) services
-- iep active on 12/1/2012----
inner join (select distinct studentcode,StudentID,LEACode,iid_idea_fin,ibegindate_idea_fin,ienddate_idea_fin from #univ_ell ) iep

on services.studentid = iep.studentid and services.[district code] = iep.LEACode and services.eventid = iep.iid_idea_fin
where (cast(iep.ienddate_idea_fin as datetime) >= convert(varchar(10),GETDATE(),101)) and (cast(services.ServiceBeginDate as datetime) <= convert(varchar(10),GETDATE(),101)) and (cast(services.ServiceEndDate as datetime) >= convert(varchar(10),GETDATE(),101))

) allservices
Group by allservices.Studentcode,allservices.[District Code]

 
--- final services outside---
select f.* into #HServices_Total_Mins_new_86 from
(
select * from #HServices_Total_Mins_exp_86
union
select * from #HServices_Total_Mins_curr_86
) f



---[view_HServices_Total_Mins_new_83]----------

---inside mins---

--ipe end date < getdate---
Select allservices.Studentcode,allservices.[District Code], 
	Sum(Case allservices.TimePeriod
			When '1' 
					--Then ((CASE WHEN TimeSpent = '' THEN 0 ELSE Convert(decimal(10,2), TimeSpent) END) * ((Case Timeunits When '1' Then 1 Else 60 END) * 5 )* Case When NumSessions IS NULL Then 1 Else Convert(int, NumSessions) END)
					 Then (((CASE WHEN isnull(allservices.TimeSpent,'') <> '' THEN Convert(decimal(10,2), allservices.TimeSpent) else 0 END) * (Case allservices.Timeunits When '1' Then 1 Else 60 END)) * 5 )* (Case When isnull(allservices.NumSessions,'') = '' Then 1 Else Convert(int, allservices.NumSessions) END)
			When '2' 
					Then (((CASE WHEN isnull(allservices.TimeSpent,'') <> '' THEN Convert(decimal(10,2), allservices.TimeSpent) else 0 END) * (Case allservices.Timeunits When '1' Then 1 Else 60 END)) * 1 )* (Case When isnull(allservices.NumSessions,'') = '' Then 1 Else Convert(int, allservices.NumSessions) END)
			When '3' 
					Then (((CASE WHEN isnull(allservices.TimeSpent,'') <> '' THEN Convert(decimal(10,2), allservices.TimeSpent) else 0 END) * (Case allservices.Timeunits When '1' Then 1 Else 60 END))/4)* (Case When isnull(allservices.NumSessions,'') = '' Then 1 Else Convert(int, allservices.NumSessions) end)
			When '6' 
					Then (((CASE WHEN isnull(allservices.TimeSpent,'') <> '' THEN Convert(decimal(10,2), allservices.TimeSpent) else 0 END) * (Case allservices.Timeunits When '1' Then 1 Else 60 END)) / 36)* (Case When isnull(allservices.NumSessions,'') = '' Then 1 Else Convert(int, allservices.NumSessions) END)
	End) As After_cal_timePeriod_83
into #HServices_Total_Mins_exp_83
From 


(select services.*,iep.StudentCode,iep.iid_idea_fin MaxIEPID,iep.ibegindate_idea_fin maxIEPBeginDate,iep.ienddate_idea_fin maxIEPEndDate
from
(Select  h.[District Code], h.ID, h.StudentID, h.EventID, h.ServiceID,h.ServiceText, h.TimeSpent, h.TimeUnits, h.TimePeriod, h.NumSessions, h.Location, h.Inactive, h.BeginDate as IEPBeginDate ,h.ProviderID
From [OSSEDAARPRD01].[seds_data_exchange].dbo.EasyIEP_HStudentServices h 
inner join [OSSEDAARPRD01].[seds_data_exchange].dbo.EasyIEP_ServiceTypes t
on h.serviceid = t.serviceid
Where h.Location = '83'  
--AND (h.Consultation = '0' OR h.Consultation is NULL) 
and  (isnull(consultation,'') = '' or isnull(consultation,'') ='0')
AND (h.ExtendedSchoolYear = 'False' or isnull(h.ExtendedSchoolYear,'') = '' or h.extendedschoolyear = '0') And  (isnull(t.excludefrom618,'') = '') And (h.inactive = '0')) services
-- iep active on 12/1/2012----
inner join (select distinct studentcode,StudentID,LEACode,iid_idea_fin,ibegindate_idea_fin,ienddate_idea_fin from #univ_ell ) iep

on services.studentid = iep.studentid and services.[district code] = iep.LEACode and services.eventid = iep.iid_idea_fin
where cast(iep.ienddate_idea_fin as datetime) < convert(varchar(10),GETDATE(),101)
) allservices
Group by allservices.Studentcode,allservices.[District Code]





--iep enddate> getdate()

Select allservices.Studentcode,allservices.[District Code], 
	Sum(Case allservices.TimePeriod
			When '1' 
					--Then ((CASE WHEN TimeSpent = '' THEN 0 ELSE Convert(decimal(10,2), TimeSpent) END) * ((Case Timeunits When '1' Then 1 Else 60 END) * 5 )* Case When NumSessions IS NULL Then 1 Else Convert(int, NumSessions) END)
					 Then (((CASE WHEN isnull(allservices.TimeSpent,'') <> '' THEN Convert(decimal(10,2), allservices.TimeSpent) else 0 END) * (Case allservices.Timeunits When '1' Then 1 Else 60 END)) * 5 )* (Case When isnull(allservices.NumSessions,'') = '' Then 1 Else Convert(int, allservices.NumSessions) END)
			When '2' 
					Then (((CASE WHEN isnull(allservices.TimeSpent,'') <> '' THEN Convert(decimal(10,2), allservices.TimeSpent) else 0 END) * (Case allservices.Timeunits When '1' Then 1 Else 60 END)) * 1 )* (Case When isnull(allservices.NumSessions,'') = '' Then 1 Else Convert(int, allservices.NumSessions) END)
			When '3' 
					Then (((CASE WHEN isnull(allservices.TimeSpent,'') <> '' THEN Convert(decimal(10,2), allservices.TimeSpent) else 0 END) * (Case allservices.Timeunits When '1' Then 1 Else 60 END))/4)* (Case When isnull(allservices.NumSessions,'') = '' Then 1 Else Convert(int, allservices.NumSessions) end)
			When '6' 
					Then (((CASE WHEN isnull(allservices.TimeSpent,'') <> '' THEN Convert(decimal(10,2), allservices.TimeSpent) else 0 END) * (Case allservices.Timeunits When '1' Then 1 Else 60 END)) / 36)* (Case When isnull(allservices.NumSessions,'') = '' Then 1 Else Convert(int, allservices.NumSessions) END)
	End) As After_cal_timePeriod_83
into #HServices_Total_Mins_curr_83
From 


(select services.*,iep.StudentCode,iep.iid_idea_fin MaxIEPID,iep.ibegindate_idea_fin maxIEPBeginDate,iep.ienddate_idea_fin maxIEPEndDate
from
(Select  h.[District Code], h.ID, h.StudentID, h.EventID, h.ServiceID,h.ServiceText, h.TimeSpent, h.TimeUnits, h.TimePeriod, h.NumSessions, h.Location, h.Inactive, h.BeginDate as ServiceBeginDate ,h.EndDate as ServiceEndDate,h.ProviderID
From [OSSEDAARPRD01].[seds_data_exchange].dbo.EasyIEP_HStudentServices h 
inner join [OSSEDAARPRD01].[seds_data_exchange].dbo.EasyIEP_ServiceTypes t
on h.serviceid = t.serviceid
Where h.Location = '83'  
--AND (h.Consultation = '0' OR h.Consultation is NULL) 
and  (isnull(consultation,'') = '' or isnull(consultation,'') ='0')
AND (h.ExtendedSchoolYear = 'False' or isnull(h.ExtendedSchoolYear,'') = '' or h.extendedschoolyear = '0') And  (isnull(t.excludefrom618,'') = '') And (h.inactive = '0')) services
-- iep active on 12/1/2012----
inner join (select distinct studentcode,StudentID,LEACode,iid_idea_fin,ibegindate_idea_fin,ienddate_idea_fin from #univ_ell ) iep

on services.studentid = iep.studentid and services.[district code] = iep.LEACode and services.eventid = iep.iid_idea_fin
where (cast(iep.ienddate_idea_fin as datetime) >= convert(varchar(10),GETDATE(),101)) and (cast(services.ServiceBeginDate as datetime) <= convert(varchar(10),GETDATE(),101)) and (cast(services.ServiceEndDate as datetime) >= convert(varchar(10),GETDATE(),101))

) allservices
Group by allservices.Studentcode,allservices.[District Code]


--- final services inside---
select f.* into #HServices_Total_Mins_new_83 from
(
select * from #HServices_Total_Mins_exp_83
union
select * from #HServices_Total_Mins_curr_83
) f




----- dedicated aide hours----
--iep enddate < getdate()

Select allservices.Studentcode,allservices.[District Code],
Sum(Case allservices.TimePeriod
			When '1' 
					--Then ((CASE WHEN TimeSpent = '' THEN 0 ELSE Convert(decimal(10,2), TimeSpent) END) * ((Case Timeunits When '1' Then 1 Else 60 END) * 5 )* Case When NumSessions IS NULL Then 1 Else Convert(int, NumSessions) END)
					 Then (((CASE WHEN isnull(allservices.TimeSpent,'') <> '' THEN Convert(decimal(10,2), allservices.TimeSpent) else 0 END) * (Case allservices.Timeunits When '1' Then 1 Else 60 END)) * 5 )* (Case When isnull(allservices.NumSessions,'') = '' Then 1 Else Convert(int, allservices.NumSessions) END)
			When '2' 
					Then (((CASE WHEN isnull(allservices.TimeSpent,'') <> '' THEN Convert(decimal(10,2), allservices.TimeSpent) else 0 END) * (Case allservices.Timeunits When '1' Then 1 Else 60 END)) * 1 )* (Case When isnull(allservices.NumSessions,'') = '' Then 1 Else Convert(int, allservices.NumSessions) END)
			When '3' 
					Then (((CASE WHEN isnull(allservices.TimeSpent,'') <> '' THEN Convert(decimal(10,2), allservices.TimeSpent) else 0 END) * (Case allservices.Timeunits When '1' Then 1 Else 60 END))/4)* (Case When isnull(allservices.NumSessions,'') = '' Then 1 Else Convert(int, allservices.NumSessions) end)
			When '6' 
					Then (((CASE WHEN isnull(allservices.TimeSpent,'') <> '' THEN Convert(decimal(10,2), allservices.TimeSpent) else 0 END) * (Case allservices.Timeunits When '1' Then 1 Else 60 END)) / 36)* (Case When isnull(allservices.NumSessions,'') = '' Then 1 Else Convert(int, allservices.NumSessions) END)
	End) As Dedicated_Aide_mins
into #dedicateAideMins_exp
From 
(select services.*,iep.studentcode from
(select * from [OSSEDAARPRD01].[seds_data_exchange].dbo.EasyIEP_HStudentServices  where ServiceID = '584' and inactive = '0') services
inner join (select distinct studentcode,StudentID,LEACode,iid_idea_fin,ibegindate_idea_fin,ienddate_idea_fin from #univ_ell ) iep 
on services.studentid = iep.studentid and services.[district code] = iep.LEACode and services.eventid = iep.iid_idea_fin
where CAST(iep.ienddate_idea_fin as datetime) < convert(varchar(10),GETDATE(),101)
) allservices
Group by allservices.Studentcode,allservices.[District Code]


--iep end date > getdate()--

Select allservices.Studentcode,allservices.[District Code],
Sum(Case allservices.TimePeriod
			When '1' 
					--Then ((CASE WHEN TimeSpent = '' THEN 0 ELSE Convert(decimal(10,2), TimeSpent) END) * ((Case Timeunits When '1' Then 1 Else 60 END) * 5 )* Case When NumSessions IS NULL Then 1 Else Convert(int, NumSessions) END)
					 Then (((CASE WHEN isnull(allservices.TimeSpent,'') <> '' THEN Convert(decimal(10,2), allservices.TimeSpent) else 0 END) * (Case allservices.Timeunits When '1' Then 1 Else 60 END)) * 5 )* (Case When isnull(allservices.NumSessions,'') = '' Then 1 Else Convert(int, allservices.NumSessions) END)
			When '2' 
					Then (((CASE WHEN isnull(allservices.TimeSpent,'') <> '' THEN Convert(decimal(10,2), allservices.TimeSpent) else 0 END) * (Case allservices.Timeunits When '1' Then 1 Else 60 END)) * 1 )* (Case When isnull(allservices.NumSessions,'') = '' Then 1 Else Convert(int, allservices.NumSessions) END)
			When '3' 
					Then (((CASE WHEN isnull(allservices.TimeSpent,'') <> '' THEN Convert(decimal(10,2), allservices.TimeSpent) else 0 END) * (Case allservices.Timeunits When '1' Then 1 Else 60 END))/4)* (Case When isnull(allservices.NumSessions,'') = '' Then 1 Else Convert(int, allservices.NumSessions) end)
			When '6' 
					Then (((CASE WHEN isnull(allservices.TimeSpent,'') <> '' THEN Convert(decimal(10,2), allservices.TimeSpent) else 0 END) * (Case allservices.Timeunits When '1' Then 1 Else 60 END)) / 36)* (Case When isnull(allservices.NumSessions,'') = '' Then 1 Else Convert(int, allservices.NumSessions) END)
	End) As Dedicated_Aide_mins
into #dedicateAideMins_curr
From 
(select services.*,iep.studentcode from
(select * from [OSSEDAARPRD01].[seds_data_exchange].dbo.EasyIEP_HStudentServices  where ServiceID = '584' and inactive = '0') services
inner join (select distinct studentcode,StudentID,LEACode,iid_idea_fin,ibegindate_idea_fin,ienddate_idea_fin from #univ_ell ) iep 
on services.studentid = iep.studentid and services.[district code] = iep.LEACode and services.eventid = iep.iid_idea_fin
where (cast(iep.ienddate_idea_fin as datetime) >= convert(varchar(10),GETDATE(),101)) and (cast(services.BeginDate as datetime) <= convert(varchar(10),GETDATE(),101)) and (cast(services.EndDate as datetime) >= convert(varchar(10),GETDATE(),101))
) allservices
Group by allservices.Studentcode,allservices.[District Code]

--fin dedicated hours--
select f.* into #dedicateAideMins from 
(
select * from #dedicateAideMins_curr
union
select * from #dedicateAideMins_exp
) f


------------temp tables for below---------
select * into #student_race from [OSSEDAARPRD01].[seds_data_exchange].dbo.Student_Race
select * into #pd from [OSSESDEV03\SQLSERVERSDEV03].[seds_data_exchange].dbo.EasyIEP_PrimaryDisabilities where inactive = '0' and [district code] = '1'
select * into #schools from [OSSEDAARPRD01].[seds_data_exchange].dbo.easyiep_schools where inactive = '0'
select * into #DistrictCodeByLEA from [OSSEDAARPRD01].[seds_data_exchange].dbo.DistrictCodeByLEA
update #schools set unitsperDay='1' where isnull(unitsperday,'')='0'
----------------------------------------------------------------------------------


select * into #easyiep_HStudentCustomData from [OSSEDAARPRD01].[seds_data_exchange].dbo.easyiep_HStudentCustomData where name in ('AideRequired','LREFullTime')


select fin.*,
--feeds.dbo.fn_CalculateAge(dob,getdate()) as  Age,

r.raceethnicity Racecode,r.Race_fin [Race Description],pd.Name as PrimaryDisablityName,pd.[618 code],
da.value as [Dedicated Aide],Convert(decimal(10,4), isnull(DA_mins.dedicated_aide_mins,0)) as DA_mins,Convert(decimal(10,2),DA_mins.dedicated_aide_mins/60) as [Dedicated Aide Hours],
actSch.UnitsPerDay * 5 AS [School Hours/Week],services.[After_cal_timePeriod] as [Mins. Outside Class],inside.[After_cal_timePeriod_83] as  [Mins. Inside Class],
(Convert(decimal(10,4), isnull(services.[After_cal_timePeriod],0)) + Convert(decimal(10,4), isnull(inside.[After_cal_timePeriod_83],0))) as [Total Mins],

Convert(decimal(10,2),ISNULL(services.[After_cal_timePeriod],0)/60) as [Hours. Outside Class],
Convert(decimal(10,2),ISNULL(inside.[After_cal_timePeriod_83],0)/60) as  [Hours. Inside Class],
Convert(decimal(10,2),(isnull(services.[After_cal_timePeriod],0) + isnull(inside.[After_cal_timePeriod_83],0)) /60 ) as [Total Hours],
--(Convert(decimal(10,2), isnull(services.[After_cal_timePeriod],0)) + Convert(decimal(10,2), isnull(inside.[After_cal_timePeriod_83],0))) /60 as [Total Hours],

round(Convert(decimal(10,2), (ISNULL(services.After_Cal_TimePeriod,0)/(actsch.UnitsPerDay * 5 * 60))* 100),0) as [% Outside Class],
round(convert(decimal(10,2),(((actsch.UnitsPerDay * 5 * 60) - Convert(decimal(10,2), isnull(services.[After_cal_timePeriod],0)))/(actsch.UnitsPerDay * 5 * 60)) * 100),0) as [% inside Class],

Case  
			When isnull(round(Convert(decimal(10,0), (services.After_Cal_TimePeriod/(actsch.UnitsPerDay * 5 *60))* 100),0),0) Between   0 AND  20  Then 'A: 0-20%'
			When isnull(round(Convert(decimal(10,0), (services.After_Cal_TimePeriod/(actsch.UnitsPerDay * 5 *60))* 100),0),0) Between  21 AND  60  Then 'B: 21-60%' 
			When isnull(round(Convert(decimal(10,0), (services.After_Cal_TimePeriod/(actsch.UnitsPerDay * 5 *60))* 100),0),0) > 60  Then 'C: 60+ %' 
		--	Else 'NULL'
		END as 'LRE'
--		Case  
--			When (isnull(Convert(int, (services.After_Cal_TimePeriod/(actsch.UnitsPerDay * 5 *60))* 100),0) Between   0 AND  39) and (cast([age on 12/1/2009] as int) between 6 and 21)  Then 'C'
--			When isnull(Convert(int, (services.After_Cal_TimePeriod/(actsch.UnitsPerDay * 5 *60))* 100),0) Between  21 AND  60  Then 'B: 21-60%' 
--			When isnull(Convert(int, (services.After_Cal_TimePeriod/(actsch.UnitsPerDay * 5 *60))* 100),0) >  60 Then 'A: 60+ %' 
--		--	Else 'NULL'
--		END as 'WestStat LRE',
--Case Stud_618.Category when 1 then 'Separate Class'	
--						   when 2 then 'Home'
--                           when 3 then 'Service Provider Location'
--						   when 4 then 'Home-Hospital'
--                           when 5 then 'Parent-Placed'
--	end as StudentCategory,
--Schools_618.[school category] as SchoolCategory
--Case Schools_618.[category]	
--When 1 then 'Separate School'
--								when 2 then 'Residential Facility'
--								when 3 then 'Correctional Facilty'
--	end as SchoolCategory

--,con.[Name] contactName,con.Address,con.City,con.HomePhone,con.State,con.Zipcode,con.CellPhone,con.WorkPhone,con.AltPhone,con.Email,con.Relation

into #618_FinalReport
from #univ_ell fin

--act schools--
inner join
#schools actSch
on actSch.schoolcode = fin.schoolcode and actSch.[district code] = fin.LEACode
--race--
left outer join /*[OSSEDAARPRD01].[seds_data_exchange].dbo.Student_Race*/ #student_race r
on fin.studentcode = r.USI 

--not required--
--Left outer Join 
--(select [stars id],Category from [618_Students] group by [stars id],Category) Stud_618
--on Stud_618.[stars id] = fin.studentcode
--Left outer Join [618_Schools_2012] as Schools_618  
--On actsch.SchoolCode = Schools_618.[School Code] and actsch.[district code] = Schools_618.[lea code]

left outer join #pd pd
on pd.id = fin.iepPD_idea_fin 

left outer join #HServices_Total_Mins_new_86 services
on fin.studentcode = services.studentcode and fin.LEACode = services.[district code]
----contact---
--left outer join [view_contactinformation] con
--on con.studentid = fin.studentid and con.[district code] = fin.[district code]

----grade--
--left outer join EasyIEP_GradeLevels g
--on g.[district code] = fin.[district code] and g.id = fin.grade

---inside mins---
left outer join #HServices_Total_Mins_new_83 inside
on fin.studentcode = inside.studentcode and fin.LEACode = inside.[district code]
--lea name--
left outer join #DistrictCodeByLEA d
on d.[district code] = fin.LEACode
--aide required----
left outer join 
(select * from #easyiep_HStudentCustomData where name = 'AideRequired') DA
on fin.studentid = da.studentid and fin.LEACode = da.[district code] and fin.iid_idea_fin  = da.eventid
---dedicated aide hours--
left outer join #dedicateAideMins DA_mins
on fin.studentcode = DA_mins.studentcode and fin.LEACode = DA_mins.[District Code] 




----update % outside class if its -ve update it to 0--

update #618_FinalReport set [% Outside Class] = 0 where cast([% Outside Class] as int) < 0

----update % inside class if its -ve update it to 0--
update #618_FinalReport set [% inside Class] = 0 where cast([% inside Class] as int) < 0

---update dedicated aide hours to 0 where dedicated aide = 'no'
update #618_FinalReport set DA_mins = 0 , [Dedicated Aide Hours] = null where ISNULL([dedicated aide],'') = 'no'


select fin.* into #final_report from
(
select f.*,

ISNULL(f.[Dedicated Aide Hours],0) + isnull(f.[Total Hours],0) as [Total Hours + Dedicated Aide],
case 
When ISNULL(f.[Dedicated Aide Hours],0) + isnull(f.[Total Hours],0) between 0 and 8.00 then 'Level 1'
When ISNULL(f.[Dedicated Aide Hours],0) + isnull(f.[Total Hours],0) between 8.01 and 16 then 'Level 2'
When ISNULL(f.[Dedicated Aide Hours],0) + isnull(f.[Total Hours],0) between 16.01 and 24 then 'Level 3'
When ISNULL(f.[Dedicated Aide Hours],0) + isnull(f.[Total Hours],0) > 24 then 'Level 4'
end as [Special Education Level]


from #618_FinalReport f



) fin


-----------------------------------------------------------------------------------------------------------------------

-----------LRE----------------
--select * into #LRE from [OSSEDAARPRD01].[seds_data_exchange].dbo.EasyIEP_HStudentCustomData  where Name like '%LREFullTime%'

truncate table SPED_Current
insert into SPED_Current
select a.*,
c.childcount_environment as SEDS_Environment,
---- change this after QB app is live-----
null AS user_updated_environment, 
null AS User_Updated_Environmnet_Date,
c.childcount_environment as  child_count_environment,	
 'SEDS'   as child_count_environment_source,	
-----------------------------------


recv.[Special Ed Eligibility Status],
'' as Flag,ude.UDE,
GETDATE() AS SNAPSHOT_DATE
 

 from #final_report a
left outer join (select * from #easyiep_HStudentCustomData where name = 'LREFullTime') b
 on a.iid_idea_fin = b.EventID and a.studentid = b.StudentID and a.LEACode = b.[District Code]
--child count environmnet mapping--
left outer join [OSSESDEV03\SQLSERVERSDEV03].[seds_data_exchange].dbo.ChildCount_Environmnet_Mapping_2013 c
on b.Value = c.seds_environment 

left outer join (select distinct studentcode , leacode,[Special Ed Eligibility Status] from #univ_sped) recv
on a.StudentCode = recv.StudentCode and a.LEACode = recv.LEACode
----------------------- Final Data Set-----
left outer join 
(select distinct studentcode, [district code],'Yes' as UDE from  OSSEDAARPRD01.qlik.dbo.unified_errors where [Error type] in ('Special Education (SPED)','Special Education (SPED) Anomaly') and [Child Count (CC) Exclusion:] = 'yes'
) ude
on isnull(a.StudentCode,'') = isnull(ude.studentcode,'') and isnull(a.LEACode,'') = isnull(ude.[district code],'')


update Sped_current set leacode = '001' where leacode = '1'
 
update Sped_current set flag = 'Not Recv Services under IDEA' where ISNULL([special ed eligibility status],'') = ''

---- remove inactive LEA's----
delete  from sped_current where LEACode not in (SELECT distinct case when isnull(lea_id,'') = '1' then '001' else  lea_id end as district_code FROM ossedaarprd02.authoritative_stg.slims.LEAS_SCHOOLS_SITES_CURRENT_SCHOOLYEAR where valid_for_enrollment = '1' )


--select distinct cast(data_as_of as datetime) from feeds.dbo.SEDS_STTS_Typs_v_SY1617 order by cast(data_as_of as datetime) desc



UPDATE sped_current SET [Dedicated Aide] = 'YES' WHERE ISNULL([Dedicated Aide],'') = 'yes'
UPDATE sped_current SET [Dedicated Aide] = 'NO' WHERE ISNULL([Dedicated Aide],'') = 'no'

update sped_current SET [Dedicated Aide] = 'NO' where ISNULL([Dedicated Aide],'') = '' 




END


select b.* into #universe
from
(
select distinct(USI),Special_Education_Level from feeds.[dbo].[SEDS_STTS_TYPS_V_SY1415] where isnull(SpEcial_Education_Level,'')<>''
union
Select distinct(USI),Special_Education_Level from feeds.[dbo].[SEDS_STTS_TYPS_V_SY1516] where isnull(SpEcial_Education_Level,'')<>''
union
Select distinct(USI),Special_Education_Level from feeds.[dbo].[SEDS_STTS_Typs_v_SY1617] where isnull(SpEcial_Education_Level,'')<>''
UNION
select distinct(USi),Special_Education_Level from feeds.[dbo].[SEDS_STTS_Typs_v_SY1718] where isnull(SpEcial_Education_Level,'')<>''
)b


select distinct USi,Max(Special_Education_level) as Max_Sped_level into #Mx_Spedlevel from #universe group by USI


select Studentcode,
e.first_name as [First Name],
e.last_name as [Last Name],
e.dob as [Date of Birth],
s.IBeginDate_idea_fin as [Current IEP Start Date],
s.IEnddate_Idea_fin as [Current IEP End Date],
case when isnull(IId_Fordate,'')='' then convert(varchar(10),IDateCreated_IDEA_fin,101) else 'null' end as [Current IEP Amendment Date],
PrimaryDisablityName as [current Primary disability],
[Total Hours + Dedicated Aide] as [Current Hours of Specialized instruction],
[Special Education Level] as [current SWD Level],
m.Max_Sped_level as [Highest SWD Level]
from Sped_Current s left join enrollments e  on s.Studentcode = e.USI and s.leaCode = e.lea_code
left join #Mx_Spedlevel m on s.StudentCode= m.USI





-------



select b.* into #universe
from
(

select distinct(USi),Special_Education_Level from feeds.[dbo].[SEDS_STTS_Typs_v_SY1718] where isnull(SpEcial_Education_Level,'')<>''
union
select distinct(USI),Special_Education_Level from [OSSEDAARPRD01].seds_data_exchange.dbo.[SEDS_STTS_Typs_v] where isnull(SpEcial_Education_Level,'')<>''
)b


select distinct USi,Max(Special_Education_level) as Max_Sped_level into #Mx_Spedlevel from #universe group by USI

select * from #Mx_Spedlevel

select Distinct USI,
cast(enrollmentresponsibleleaid as int) as lea_code,
[504AccommodationSIS]
into #s1
 from [OSSEETLPROD01].[OSSE_Data_Exchange].[dbo].[RosterUncertifiedMaster] where isnull(USI,'')<>''

 select b.USI,Lea_Code,[504AccommodationSIS] into #504_plan
 from
 (
 select S.*,
 Rank() over (partition by usi,lea_code order by [504AccommodationSIS] desc) as r1
  from #s1 s
  )b where r1=1


  select USi,lea_code  from #504_plan group by usi,lea_code having count(*) >1

   update #504_plan  set [504AccommodationSIS]='YES' where [504AccommodationSIS]='Y'
   update #504_plan  set [504AccommodationSIS]='NO' where [504AccommodationSIS]='N'

   select * from #504_plan


select * from data_validation_swd s join
(
select Studentcode,leacode from data_validation_SWD group by studentcode,leacode having count(*)>1
)b on s.studentcode = b.Studentcode and s.leacode = b.leacode
order by s.studentcode


truncate table data_validation_SWD

insert into data_validation_SWD


select Distinct(Studentcode),
e.first_name as [First Name],
e.last_name as [Last Name],
e.dob as [Date of Birth],
s.IBeginDate_idea_fin as [Current IEP Start Date],
s.IEnddate_Idea_fin as [Current IEP End Date],
case when isnull(IId_Fordate,'')='' then convert(varchar(10),IDateCreated_IDEA_fin,101) else 'null' end as [Current IEP Amendment Date],
PrimaryDisablityName as [current Primary disability],
[Total Hours + Dedicated Aide] as [Current Hours of Specialized instruction],
[Special Education Level] as [current SWD Level]
,
m.Max_Sped_level as [Highest SWD Level],

--case when isnull(r.[504AccommodationSIS],'')='N' then 'No' 
--     when isnull(r.[504AccommodationSIS],'')='Y' then 'Yes' 
--	 Else '' End  as [504 Plan],
r.[504AccommodationSIS],
	 LEACode
	 --into data_validation_SWD
from Sped_Current s  join enrollments e  on s.Studentcode = e.USI and cast(s.leaCode as int) = e.lea_code
left join #Mx_Spedlevel m on s.StudentCode= m.USI
left join #504_plan r on r.USI = s.StudentCode and r.lea_code= cast(s.leacode as int)


select * from data_validation_SWD where isnull([Current SWd Level],'')<>'' and isnull([Highest SWD Level],'')=''

drop table data_validation_SWD

drop table #s1

select Distinct USI,
cast(enrollmentresponsibleleaid as int) as lea_code,
[504AccommodationSIS]
into #s1
 from [OSSEETLPROD01].[OSSE_Data_Exchange].[dbo].[RosterUncertifiedMaster] where isnull(USI,'')<>''

 select b.USI,Lea_Code,[504AccommodationSIS] into #504_plan
 from
 (
 select S.*,
 Rank() over (partition by usi,lea_code order by [504AccommodationSIS] desc) as r1
  from #s1 s
  )b where r1=1


  select USi,lea_code  from #504_plan group by usi,lea_code having count(*) >1

   update #504_plan  set [504AccommodationSIS]='YES' where [504AccommodationSIS]='Y'
   update #504_plan  set [504AccommodationSIS]='NO' where [504AccommodationSIS]='N'

   select * from #504_plan


select * from data_validation_swd s join
(
select Studentcode,leacode from data_validation_SWD group by studentcode,leacode having count(*)>1
)b on s.studentcode = b.Studentcode and s.leacode = b.leacode
order by s.studentcode


select * from data_validation_swd