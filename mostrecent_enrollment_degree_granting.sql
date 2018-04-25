 
 use Data_Validation

 if object_id('tempdb..#data_initial_universe') is not null
 drop table #data_initial_universe


 select distinct r.usi,
 r.enrollmentresponsibleleaid,
 r.enrollmentresponsibleleaname,
 r.enrollmentattendingschoolId,
 --r.enrollmentattendingschoolname,
 --r.EnrollmentGradeLevelCode,
 r.enrollmentstage5Date,
 r.EnrollmentExitDate,
 r.enrollmentExitCode
 into #data_initial_universe
 from [dbo].[cohort_data_aggregation] s join feeds.[dbo].[RosterUncertifiedMaster_Historic2] r on s.usi = r.USi
 where cast(logdate as date) > cast('08/01/2017' as date)
 and isnull(r.enrollmentstatus,'') in ('enrolled','withdrawn')
 and EnrollmentStage like 'Stage 5'

 select * from #data_initial_universe

 update #data_initial_universe set EnrollmentResponsibleLEAID='1' where EnrollmentResponsibleLEAID='001'


 if object_id('tempdb..#mostrecentenrollment') is not null
 drop table #mostrecentenrollment

 select distinct  b.* into #mostrecentenrollment
 from
 (
 select distinct usi,
 enrollmentresponsibleleaid as most_recent_leacode,
 enrollmentresponsibleleaname as most_recent_leaname,
 EnrollmentAttendingSchoolID as most_recent_schoolcode,
 --EnrollmentAttendingSchoolName as most_recent_schoolname,
 --enrollmentgradelevelcode as most_recent_enrollmentGrade,
 enrollmentstage5Date as most_recent_enrollmentstage5Date,
 EnrollmentExitDate as most_recent_exitdate,
 enrollmentexitcode as most_recent_exitcode,
 rank() over (partition by USi order by cast(enrollmentstage5Date as date) desc,cast(enrollmentexitdate as date) desc) as mostrecent_enrollment
 from #data_initial_universe u
 )b where mostrecent_enrollment=1

 select * from #mostrecentenrollment where usi in 
 (
 select usi from #mostrecentenrollment group by usi having count(*)>1
 ) order by usi

 -- now find most recent degree granting schools ----

 if object_id('tempdb..#degreegranting_universe_initial') is not null
 drop table #degreegranting_universe_initial

 select distinct d.usi,
 d.EnrollmentResponsibleLEAID,
 d.enrollmentattendingschoolid,
 d.enrollmentstage5date,
 d.enrollmentExitDate,
 d.enrollmentexitcode
 into #degreegranting_universe_initial
 from #data_initial_universe d join degree_granting_schools de on d.EnrollmentAttendingSchoolID = de.[school_id(state)]
 and d.EnrollmentResponsibleLEAID = de.[lea_id (state)]


 select distinct b.* into #most_recent_degreegranting_universe
 from
 (
 select distinct usi,
 enrollmentresponsibleleaid as most_recent_dgranting_leacode,
 EnrollmentAttendingSchoolID as most_recent_dgranting_schoolid,
 enrollmentstage5date as most_recent_dgranting_enrollmentstage5_date,
 enrollmentExitDate as most_recent_dgranting_enrollmentExitdate,
 enrollmentexitcode as most_recent_dgranting_exitcode,
 rank() over (partition by USi order by cast(enrollmentstage5Date as date) desc,cast(enrollmentexitdate as date) desc) as mostrecent_enrollment
 from #degreegranting_universe_initial
 )b where mostrecent_enrollment='1'


 select * from #most_recent_degreegranting_universe where usi in 
 (
 select usi from #most_recent_degreegranting_universe group by usi having count(*)>1
 ) order by USI