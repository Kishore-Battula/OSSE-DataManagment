
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


select * from

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

select * from

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

