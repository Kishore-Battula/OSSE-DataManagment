USE [Data_Validation]
GO

/****** Object:  StoredProcedure [dbo].[Sp_refresh_enrollments]    Script Date: 2/16/2018 2:22:50 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO



CREATE PROCEDURE [dbo].[Sp_refresh_enrollments]
AS
BEGIN


  -- Pull Sy1718 Enrollment data.
  IF OBJECT_ID('tempdb..#EA_Audit_Sy1718') IS NOT NULL
    DROP TABLE #EA_Audit_Sy1718

  SELECT
    * INTO #EA_Audit_Sy1718
  FROM [OSSEDAARPRD02].[Authoritative].[ea].[Student_Records_SY1718]

  -- Pull Rosteruncertifiedmaster data.
  IF OBJECT_ID('Tempdb..#RosteruncertifiedMaster') IS NOT NULL
    DROP TABLE #RosteruncertifiedMaster

  SELECT
    * INTO #RosteruncertifiedMaster
  FROM osseetlprod01.osse_data_Exchange.dbo.RosterUncertifiedMaster
  WHERE enrollmentStatus IN ('Enrolled', 'Withdrawn')
  AND EnrollmentStage LIKE 'Stage 5'
  AND ISNULL(USI, '') <> ''

  UPDATE #Rosteruncertifiedmaster
  SET enrollmentresponsibleleaid = '1'
  WHERE enrollmentresponsibleleaid = '001'


  IF OBJECT_ID('tempdb..#Race_ethnicity') IS NOT NULL
    DROP TABLE #Race_ethnicity

  SELECT DISTINCT
    (RaceEthnicityCode),
    RaceEthnicityDesc INTO #Race_ethnicity
  FROM #RosteruncertifiedMaster


  IF OBJECT_ID('tempdb..#roster_active') IS NOT NULL
    DROP TABLE #roster_active

  SELECT DISTINCT
    USI,
    SourceLocalId,
    LastName AS last_name,
    FirstName AS first_name,
    DateofBirth AS dob,
    GenderCode AS gender,
    EnrollmentGradeLevelCode AS grade,
    RaceEthnicityCode AS race_eth,
    enrollmentresponsibleleaID AS lea_code,
    enrollmentresponsibleleaName AS lea_name,
    enrollmentAttendingschoolId AS school_code,
    enrollmentattendingSchoolname AS school_name,
    EnrollmentStage5Date AS entry_date,
    EnrollmentEntryCode AS entry_code,
    EnrollmentExitDate AS exit_Date,
    EnrollmentExitCode AS exit_code,
    enrollmentStage,
    enrollmentStatus,
	Custom1,
	LEPIndicator,
	NewToUS,
	NativeLanguageCode,
    'RosterUncertifiedMaster' AS category INTO #roster_active
  FROM #RosteruncertifiedMaster


  IF OBJECT_ID('tempdb..#audit_not') IS NOT NULL
    DROP TABLE #audit_not


  SELECT DISTINCT
    E.USI,
    E.LocalId AS SourceLocalId,
    E.LastName AS last_name,
    E.FirstName AS first_name,
    E.dateofbirth AS dob,
    E.Gender AS Gender,
    E.EnrollmentGradeLevelIndicator AS grade,
    E.RaceEthnicity,
    E.leaCode AS lea_code,
    e.leaname AS lea_name,
    schoolcode AS school_code,
    schoolname AS school_name,
    Enrollmentdate AS entry_date,
    enrollmentcode AS entry_code,
    exitdate AS exit_date,
    exitcode AS exit_code,
    'Stage 5' AS enrollmentStage,
    'Enrolled' AS enrollmentStatus,
	'null' as custom1,
	E.LEPIndicator,
	'' as NewToUS,
	'' as NativeLanguageCode,
    'AuditnotRoster' AS Category INTO #Audit_not
  FROM #EA_Audit_Sy1718 E
  LEFT JOIN #roster_active r
    ON E.USI = R.USI
    AND E.leaCode = R.lea_code
    AND E.SchoolCode = R.school_code
  WHERE ISNULL(R.USi, '') = ''
  AND ISNULL(r.LEA_Code, '') = ''
  AND ISNULL(r.school_code, '') = ''


  if object_id('tempdb..#roster_uncertified_master_10_01_2017') is not null
  drop table #roster_uncertified_master_10_01_2017

  select distinct usi,
  EnrollmentResponsibleLEAID,
  newtous,
  NativeLanguageCode
  into #roster_uncertified_master_10_01_2017 from 
  feeds.dbo.RosterUncertifiedMaster_Historic2  r 
  where cast(logdate as datetime)= cast('10/02/2017' as datetime)

 select USI,EnrollmentResponsibleleaid
 into #dupes
 from #roster_uncertified_master_10_01_2017 group by usi,EnrollmentResponsibleLEAID having count(*)>1

  select * from #dupes
  
  if object_id('tempdb..#duplicative_universe') is not null
  drop table #duplicative_Universe
  
  select r.* into #duplicative_universe
  from #dupes d join #roster_uncertified_master_10_01_2017 r on d.USI = r.usi and d.EnrollmentResponsibleLEAID=r.EnrollmentResponsibleLEAID
  
 select * into #required from #duplicative_universe  where isnull(newtoUS,'')='Y' OR isnull(NativeLanguageCode,'')<>''

 if object_id('tempdb..#required_unique') is not null
 drop table #required_unique

 select b.USI,ENrollmentresponsibleleaid,newtous,NativeLanguageCode into #required_unique from 
 (
 select r.*,
 rank() over (partition by usi,enrollmentresponsibleleaid order by newtous desc, nativeLanguagecode desc) as r1
  from #required r
  )b where r1=1

 select * from #

  UPDATE a
  SET a.RaceEthnicity = r.RaceEthnicityCode
  FROM #Audit_not a
  JOIN #Race_ethnicity r
    ON a.raceEthnicity = r.RaceEthnicityDesc


  TRUNCATE TABLE enrollments

  INSERT INTO enrollments
    SELECT
      USI,
	  SourceLocalId,
	  Last_name,
	  first_name,
	  dob,
	  gender,
	  grade,
	  race_eth,
	  lea_Code,
	  lea_Name,
	  school_Code,
	  school_name,
	  entry_Date,
	  entry_code,
	  exit_date,
	  exit_code,
	  enrollmentStage,
	  enrollmentStatus,
	  lepIndicator,
	  newToUS,
	  NativeLanguageCode,
	  case when isnull(custom1,'')<>'' then custom1 else Category end as category
    FROM #roster_active 
    UNION
    SELECT
      USI,
	  SourceLocalid,
	  last_Name,
	  First_name,
	  dob,
	  Gender,
	  Grade,
	  RaceEthnicity,
	  Lea_Code,
	  Lea_Name,
	  School_Code,
	  School_name,
	  entry_Date,
	  entry_code,
	  exit_Date,
	  exit_code,
	  enrollmentstage,
	  enrollmentstatus,
	  case when isnull(LEPIndicator,'')=1 then 'Y'
	       when isnull(lepindicator,'')='0' then 'N' else '' end as LEPIndicator,
	  newToUs,
	  NativeLanguageCode,
	  Category
    FROM #Audit_not

END
GO


