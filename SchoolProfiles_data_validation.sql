use ESchool_Data_Aggregation

if object_id('tempdb..#t1') is not null
drop table #t1

select pa.District,
pa.Building,
case when pa.SCREEN_NUMBER='8003' then 'Parent engagement' else 'School environment' End as feed_type,
pa.Screen_Number,
pa.FIELD_NUMBER,
cm.Field_label,
pa.Field_value
into #t1
from
(
select * from [OSS-SQL-01].[OSSeSchool_live].[dbo].[REG_USER_BUILDING]
where screen_number in ('8003','8004')) pa left join 
(
select * from [OSS-SQL-01].[OSSeSchool_live].[dbo].[SMS_USER_fields] where screen_number in ('8003','8004')
) cm
on pa.Field_number = cm.Field_number    
and pa.district = cm.District
and pa.SCREEN_NUMBER = cm.screen_number


if object_id('tempdb..#parent_profile') is not null
drop table #parent_profile

select * into #parent_profile from
(select District,
Building,
FIELD_LABEL,
Field_value
from #t1 where screen_number='8003' ) as sourcetable
PIVOT ( MIN([Field_value])
for FIELD_LABEL in (
[Communication Policy Link],
[Extra Curriculum Activities?],
[Facebook Link],
[FOR CHARTER SCHOOLS ONLY],
[FOR DCPS SCHOOLS ONLY],
[Parent Communication Policy?],
[Parent Org - POC?],
[Parent Org Link],
[Parent Organization?],
[Parent Representative POC?],
[POC Email Address],
[POC First Name],
--[POC Last Name ],
[POC Last Name],
[POC Phone Number xxx-xxx-xxxx],
[School Advisory Team Link],
[School Advisory Team POC?],
[School Advisory Team?],
[School Program Information],
[School Social Media Presence?],
[Twitter Link]
)
)As PivotOutput


if object_id('tempdb..#schoolprofile') is not null
drop table #schoolprofile

select * into #schoolprofile 
from
(select District,
Building,
FIELD_LABEL,
Field_value
from #t1 where screen_number='8004' ) as sourcetable
PIVOT ( MIN([Field_value])
for FIELD_LABEL in (
[AC hours],
[BC hours],
[Extra-curricular activities],
[Is AC Free?],
[Is AC on Sliding Scale?],
[Is AC Paid?],
[Is AC Voucher?],
[Is After Care (AC) available?],
[Is BC Free?],
[Is BC on Sliding Scale?],
[Is BC Paid?],
[Is BC Voucher?],
[Is Before Care (BC) available?],
[List feeder schools],
[List school programs],
[Operating Hours for School],
[Point of Pride #1],
[Point of Pride #2],
[Point of Pride #3],
[School's closest bus line],
[School's closest metro line]
)
)As PivotOutput

if object_id('tempdb..#msdc_maskdata') is not null
drop table #msdc_maskdata

select * into #msdc_maskdata from [OSSEDAARPRD02].[Authoritative_STG].[dbo].[SY18_19_Profile_Data]

select * from #msdc_maskdata

update m set [osse school code]='9000' from  #msdc_maskdata m  where [osse school code]='141'


drop table data_validation_school_profiles

select  distinct
m.[osse school code] as school_code
,p.DISTRICT as [lea_code]
 ,[School Social media presence?] as [School Social Media Presence]
,[Twitter Link]
,[Facebook Link]
,[Parent Organization?] as [Parent Organization]
,[Parent Org Link]
,[Parent Org - POC?] as [Parent Org - POC]
,[POC First Name] 
,[POC Last Name]
,[POC Email Address]
,[POC Phone Number xxx-xxx-xxxx]
,[Parent communication Policy?] as [Parent communication policy]
,[communication policy Link]
,case when isnull([For charter schools only],'') in ('Y','YES','1') then [Parent Representative POC?] else '' end as [Parent Representative POC]
,case when isnull([For charter schools only],'') in ('Y','YES','1') then [POC First Name] else '' end as [POC First Name charters]
,case when isnull([For charter schools only],'') in ('Y','YES','1') then [POC Last Name] else '' end as [POC Last Name charters]
,case when isnull([For charter schools only],'') in ('Y','YES','1') then [POC Email Address] else '' end as [POC Email Address charters]
,case when isnull([For charter schools only],'') in ('Y','YES','1') then [POC Phone Number xxx-xxx-xxxx] else '' end as [POC Phone Number xxx-xxx-xxxx charters]
,case when isnull([For DCPS Schools Only],'') in    ('Y','YES','1') then [School Advisory Team?] else '' end as [School Advisory Team DCPS]
,case when isnull([FOR DCPS SCHOOLS ONLY],'') in    ('Y','YES','1') then [School Advisory team Link] else '' end as [School Advisory team link DCPS]
,case when isnull([For DCPS Schools only],'') in    ('Y','YES','1') then [School Advisory Team POC?] else '' end as [School Advisory Team POC DCPS]
,case when isnull([For DCPS Schools Only],'') in    ('Y','YES','1') then [POC First Name] else '' end as [POC First Name DCPS]
,case when isnull([For DCPS Schools only],'') in    ('Y','YES','1') then [POC Last Name] else '' end as [POC Last Name DCPS]
,case when isnull([For DCPS Schools only],'') in    ('Y','YES','1') then [POC Email Address] else '' end as [POC Email Address DCPS]
,case when isnull([For DCPS Schools only],'') in    ('Y','YES','1') then [POC Phone Number xxx-xxx-xxxx] else '' end as [POC Phone Number xxx-xxx-xxxx DCPS]
,m.[School Hours] as [Operating Hours for school]
,m.[Point of pride #1] as [Point of pride #1]
,m.[point of pride #2] as [point of pride #2]
,m.[point of pride #3] as [point of pride #3]
,'   ' as [List feeder schools]
,case when isnull(m.[after care available],'')='X' then 'Y' else 'N' end as [is Before Care(BC)/ After Care(AC) available]
,[Before and After care hours] as [Before/After Hours]
,[care is Free] as [Is BC/AC Paid]
,case when isnull([care is on a sliding scale or voucher],'') like '%sliding%' then 'Y' else 'N' END as [is BC/AC on Sliding Scale]
,case when isnull([care is on a sliding scale or voucher],'') like '%voucher%' then 'Y' else 'N' End as [is BC/AC Voucher]
,'  ' as [is BC/AC Free]
--, case when isnull([After care available],'')='X' then 'Y' else 'N' end as [is After Care (AC) Available]
--,[Before and After care hours] as [AC hours]
--,[care is Free] as [is AC Paid?]
--,case when isnull([care is on a sliding scale or voucher],'') like '%sliding%' then 'Y' else 'N' END as [is AC on Sliding Scale]
--,case when isnull([care is on a sliding scale or voucher],'') like '%voucher%' then 'Y' else 'N' End as [is AC Voucher]
--,' ' as [is AC Free]
,[Metro bus Service] as [Schools closest bus line]
,[Metro Rail Service] as [Schools closest metro line]
,[Grades Served] as [List school Programs]
,[Additional Enrichments] as [Extra-curricular Activities]
into data_validation_school_profiles
from #parent_profile p right join #msdc_maskdata m on m.[osse school code] = p.Building

-- This Script needs to be run against the Edm Server's Data validation DB.






select distinct school_code,
lea_code,
case when isnull([School social Media Presence],'') in ('Y','YES','1') then 'Y' Else 'N' End as [School social media presence],
case when isnull([School Social Media Presence],'') in ('Y','YES','1') then cast([Twitter Link] as varchar(500)) ELSE '' End as [Twitter Link],
case when isnull([School Social Media Presence],'') in ('Y','YES','1') then cast([Facebook Link] as varchar(500)) Else ' ' End as [Facebook Link],
case when isnull([Parent Organization],'') in ('Y','YES','1') then 'Y' Else 'N' end as [Parent Organization],
case when isnull([Parent Organization],'') in ('Y','YES','1') then [Parent Org Link] Else '' end as [Parent Org Link],
case when isnull([Parent ORG - POC],'') in ('Y','YES','1') then [Parent Org - POC] Else 'N' end as [Parent Org - POC],
case when isnull([Parent ORG - Poc],'') in ('Y','YES','1') then [POC First Name] + ''+[POC Last Name] End as [POC First Name],
case when isnull([Parent ORG - POC],'') in ('Y','YES','1') then [POC First Name] +''+[POC Last Name] end as [POC Last Name],
case when isnull([Parent Org - POC],'') in ('Y','YES','1') then [POC Email Address] else '' end as [POC Email Address],
case when isnull([Parent Org - POC],'') in ('Y','YES','1') then [POC Phone Number xxx-xxx-xxxx] else '' end as [POC Phone Number xxx-xxx-xxxx],
case when isnull([Parent communication policy],'') in ('Y','YES','1') then [Parent communication Policy] else 'N' end as [Parent communication policy],
case when isnull([Parent communication policy],'') in ('Y','YES','1') then [Communication policy Link] else '' end as [community policy link],
case when isnull([Parent Representative POC],'') in ('Y','YES','1') then [Parent Representative POC] else '' end as [Parent Representative POC],
case when isnull([Parent Representative POC],'') in ('Y','YES','1') then [POC First Name Charters]+''+[POC Last Name charters] else '' end as [POC Frist Name charters],
case when isnull([Parent Representative POC],'') in ('Y','YES','1') then [POC First Name Charters]+''+[POC Last Name charters] else '' end as [POC Last Name charters],
case when isnull([Parent Representative POC],'') in ('Y','YES','1') then [POC Phone Number xxx-xxx-xxxx charters] else '' end as [POC phone number xxx-xxx-xxxx charters],
case when isnull([School advisory team DCPS],'') in ('Y','YES','1') then [school advisory team DCPS] else '' end as [School Advisory Team],
case when isnull([School advisory team link DCPS],'') in ('Y','YES','1') then [School Advisory team Link DCPs] else '' end as [School Advisory team link],
case when isnull([school advisory team poc DCPS],'') in ('Y','YES','1') then [School Advisory team POC DCPS] else 'N' end as [School Advisory team POC],
case when isnull([school advisory team poc DCPS],'') in ('Y','YES','1') then [POC First Name DCPS]+''+[POC Last Name DCPS] end as [POC First Name DCPS],
case when isnull([school advisory team poc DCPS],'') in ('Y','YES','1') then [POC First Name DCPS]+''+[POC Last Name DCPS] end as [POC Last Name DCPS],
case when isnull([school advisory team poc DCPS],'') in ('Y','YES','1') then [POC Email Address DCPS] else '' end as [POC Email Address DCPS],
case when isnull([school advisory team poc DCPS],'') in ('Y','YES','1') then [POC Phone Number xxx-xxx-xxxx DCPS] else ' ' end as [POC Phone Number xxx-xxx-xxxx DCPS],
[Operating Hours for School],
[Point of pride #1],
[Point of pride #2],
[Point of Pride #3],
[List feeder schools],
[is before care(BC)/ After care(AC) available],
case when isnull([is before care(BC)/ After care(AC) available],'') in ('Y','YES','1') then [Before/After Hours] else '' end as [Before/After hours],
case when isnull([is before care(BC)/ After care(AC) available],'') in ('Y','YES','1') then [is BC/AC Paid] else '' end as [is BC/AC Paid],
case when isnull([is before care(BC)/ After care(AC) available],'') in ('Y','YES','1') then [is BC/Ac on sliding scale] else '' end as [is BC/Ac on sliding scale],
case when isnull([is before care(BC)/ After care(AC) available],'') in ('Y','YES','1') then [is BC/Ac Voucher] else '' end as [is BC/AC Voucher],
case when isnull([is before care(BC)/ After care(AC) available],'') in ('Y','YES','1') then[is BC/AC Free] else '' end as [is BC/AC Free],
[Schools closest bus line],
[schools closest metro line],
[list school programs],
[Extra-curricular activities]
into  school_Environment_Qlik_data
from [OSSEDAARPRD04].eschool_data_aggregation.dbo.data_validation_school_profiles