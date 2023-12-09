-- Summary:

-- [% of Best Performer]
-- Price Ranking & Bucketing
-- Lead and Lag Due	
-- Above Avg Prices
--Jamming Total Lines by ListPrice
-- Pivoting lineTotal
-- Comparison between each month's total sum of top 10 orders against previous month's
-- Generating Date Series
-- Lookup Tables "Creating a Calendar Table"
-- Rolling Count
-- 30 and 60 Days Rolling/Moving Average
-- checking for number of null values in all columns
-- aggregated Summary for exportation & Visualization
-- Checking for NULLs
-- Creating Profit Bucketing based on Quartile
-- Removing Duplicates
-- Can you further breakdown this average value into 30 day periods (i.e. 0-30 days, 31-60 days etc)
-- How would you calculate the rate of growth for Foodie-Fi? based on total amount
-- Generate an order item for each record in the customers_orders table based on toppings




-- [% of Best Performer]

select
	BusinessEntityID,
	TerritoryID,
	SalesQuota,
	Bonus,
	CommissionPct,
	SalesYTD,
	SalesLastYear,
	[Total YTD Sales] = SUM(salesYTD) over(),
	[Max YTD Sales] = MAX(salesYTD) over(),
	[% of Best Performer] = (SalesYTD/MAX(salesYTD) over()) * 100
from AdventureWorks2019.Sales.SalesPerson


-- Price Ranking & Bucketing
select
	A.name as ProductName,
	A.ListPrice,
	B.name as ProductSubcategory,
	C.name as ProductCategory,
	[Price Rank] = ROW_NUMBER() over( order by a.ListPrice desc),
	[Category Price Rank] = ROW_NUMBER() over( partition by c.name order by a.ListPrice desc),
	[Top 5 Price In Category] =
		CASE 
			when 
				ROW_NUMBER() over( partition by c.name order by a.ListPrice desc) <= 5 then 'Yes'
			else 'No'
		end 

from
	[AdventureWorks2019].[Production].[Product] A
	join AdventureWorks2019.Production.ProductSubcategory B
	on A.ProductSubcategoryID = B.ProductSubcategoryID

	join AdventureWorks2019.Production.ProductCategory C
	on B.ProductCategoryID = C.ProductCategoryID


-- Lead and Lag Due	
select
	SalesOrderID,
	OrderDate,
	CustomerID,
	TotalDue,
	[NextTotalDue] = LEAD(totaldue, 1) over(partition by CustomerID order by SalesOrderID),
	[PrevtotalDue] = lag(totaldue,1) over(partition by CustomerID order by SalesOrderID)
from
	AdventureWorks2019.Sales.SalesOrderHeader

order by
	3,1


-- Above Avg Prices
select
	ProductID,
	Name,
	StandardCost,
	ListPrice,
	AvgListPrice = (select AVG(listprice) from AdventureWorks2019.Production.Product),
	AvgListPriceDiff = ListPrice - (select AVG(listprice) from AdventureWorks2019.Production.Product)
from 
	AdventureWorks2019.Production.Product
where
	ListPrice > (select AVG(listprice) from AdventureWorks2019.Production.Product)
Order by
	4


--Jamming Total Lines by ListPrice
select
	Name as SubcategoryName,
	Product = STUFF(
						(
						select
							concat(',',name)

						from
							AdventureWorks2019.Production.Product A

						where a.ProductSubcategoryID = b.ProductSubcategoryID
							AND ListPrice > 50
							FOR XML PATH('')
						),1,1,''
					)		
						
from
	AdventureWorks2019.Production.ProductSubcategory B


-- Pivoting lineTotal
select
	[Order Quantity] = OrderQty,
	Bikes,
	Accessories,
	Clothing,
	Components

from
	(
		select
			D.Name as ProductCategoryName,
			A.LineTotal,
			A.OrderQty

		from
			AdventureWorks2019.Sales.SalesOrderDetail A
			join AdventureWorks2019.Production.Product B
			on A.ProductID = B.ProductID

			join AdventureWorks2019.Production.ProductSubcategory C
			on B.ProductSubcategoryID = C.ProductSubcategoryID

			join AdventureWorks2019.Production.ProductCategory D
			on C.ProductCategoryID = D.ProductCategoryID
	) A

PIVOT(
sum(lineTotal)
for ProductCategoryName IN([Bikes],[Accessories],[Clothing],[Components])
) B

order by 1


-- Comparison between each month's total sum of top 10 orders against previous month's
With Sales as
(
	select
		OrderDate,
		TotalDue,
		OrderMonth = DATEFROMPARTS(year(OrderDate),month(OrderDate),1),
		OrderRank = ROW_NUMBER() over(partition by DATEFROMPARTS(year(OrderDate),month(OrderDate),1) order by TotalDue desc)

	from
		AdventureWorks2019.Sales.SalesOrderHeader
),
Top10 as
(
	select
		OrderMonth,
		Top10Total = SUM(TotalDue)

	from
		Sales

	where
		OrderRank <= 10

	Group by
		OrderMonth
)

select
	A.OrderMonth,
	A.Top10Total,
	B.Top10Total as PrevTop10Total
		
from 
	Top10 A
	Left join Top10 B
	on A.OrderMonth = DATEADD(MONTH,1,B.OrderMonth)

order by
	1

-- Generating Date Series

With DateSeries As
(
	select 
		CAST('01-01-2022' as date) As MyDate

	Union all

	select
		DATEADD(DAY,1,MyDate)

	from
		DateSeries

	where
		MyDate < CAST('12-31-2022' as date)
)
select
	MyDate

from 
	DateSeries

OPTION(MAXRECURSION 365)


-- Lookup Tables "Creating a Calendar Table"
Create Table AdventureWorks2019.dbo.Calendar
(
DateValue Date,
DayOfWeekNumber int,
DayOfWeekName Varchar(32),
DayOfMonthNumber int,
MonthNumber int,
YearNumber int,
WeekendFlag tinyint,
HolidayFlag tinyint
)

With Dates As
(
select
	Cast('01-01-2011' as Date) as MyDate
Union All
select
	DATEADD(DAY,1,MyDate)
from
	Dates
Where
	MyDate < Cast('12-31-2030' as Date)
)

Insert Into AdventureWorks2019.dbo.Calendar
(
DateValue
)

Select
	MyDate
from
	Dates
Option (Maxrecursion 10000)


Update AdventureWorks2019.dbo.Calendar
SET 
DayOfWeekNumber = DATEPART(WEEKDAY,DateValue),
DayOfWeekName = FORMAT(DateValue,'dddd'),
DayOfMonthNumber = DAY(DateValue),
MonthNumber = MONTH(DateValue),
YearNumber = YEAR(DateValue)


Update AdventureWorks2019.dbo.Calendar
SET
WeekendFlag =
	Case
		when DayOfWeekName IN ('Saturday', 'Sunday') then 1
		else 0
	End


Update AdventureWorks2019.dbo.Calendar
SET
HolidayFlag =
	Case
		when DayOfMonthNumber = 1 and MonthNumber = 1 then 1
		else 0
	End

select * from AdventureWorks2019.dbo.Calendar


select 
	A.*
from
	AdventureWorks2019.Sales.SalesOrderHeader A
	join AdventureWorks2019.dbo.Calendar B
	on A.OrderDate = B.DateValue
where
	B.WeekendFlag = 1


-- Rolling Count

select dea.continent, dea.location, dea.date, dea.population, vac.new_vaccinations,
SUM(convert(bigint,vac.new_vaccinations)) over (partition by dea.location order by dea.location, dea.date) as RollingPeopleVaccinated
from Covid_Project..CovidDeaths$ dea
join Covid_Project..CovidVaccinations$ vac
   on dea.location = vac.location
   and dea.date = vac.date
where dea.continent is not null
order by 2,3


-- 30 and 60 Days Rolling/Moving Average

select dea.continent, dea.location, dea.date, dea.population, vac.new_vaccinations,
AVG(convert(bigint, vac.new_vaccinations)) over( partition by dea.location order by dea.location, dea.date ROWS BETWEEN 29 PRECEDING AND CURRENT ROW) AS _30DaysRollAvg,
AVG(convert(bigint, vac.new_vaccinations)) over( partition by dea.location order by dea.location, dea.date ROWS BETWEEN 59 PRECEDING AND CURRENT ROW) AS _60DaysRollAvg
from Covid_Project..CovidDeaths$ dea
join Covid_Project..CovidVaccinations$ vac
   on dea.location = vac.location
   and dea.date = vac.date
where dea.continent is not null
order by 2,3


-- checking for number of null values in all columns

select
	count(*) - COUNT(ride_id) ride_id,
	count(*) - COUNT(rideable_type_id) rideable_type_id,
	count(*) - COUNT(rideable_type) rideable_type,
	count(*) - COUNT(start_date) start_date,
	count(*) - COUNT(start_time) start_time,
	count(*) - COUNT(end_date) end_date,
	count(*) - COUNT(end_time) end_time,
	count(*) - COUNT(start_station_id) start_station_id, -- 833064 NULL
	count(*) - COUNT(start_station_name) start_station_name, -- 833064 NULL
	count(*) - COUNT(end_station_id) end_station_id, -- 892742 NULL
	count(*) - COUNT(end_station_name) end_station_name, -- 892742 NULL
	count(*) - COUNT(user_category) user_category
from joined_tables -- all null values were from station_id and station_name


-- aggregated Summary for exportation & Visualization

select
	user_category,
	a.rideable_type,
	DATEFROMPARTS(2022, month_number, day__of_month_number) as date,
	DATEPART(QUARTER, a.start_date) as quarter,
	DATENAME(MONTH, a.start_date) as month,
	day__of_month_number,
	day_of_week_number,
	day_of_week_name,
	DATEPART(hour,(CAST(a.start_time as time))) as hour,
	SUM(min_diff) as total_lengths,
	avg(min_diff) AS average_ride_length,
	count(a.ride_id) as ride_id_count,
	COUNT(case when min_diff <= 10 then 'short ride' end) as short_rides,
	count(case when min_diff > 10 and min_diff <= 15 then 'average ride' end) as average_rides,
	COUNT(case when min_diff > 15 then 'long ride' end) as long_rides


from 
	joined_tables a
	left join ride_data b
	on a.ride_id = b.ride_id

group by
	a.user_category,
	a.rideable_type,
	a.month_number,
	DATEPART(QUARTER, a.start_date),
	DATENAME(MONTH, a.start_date),
	day__of_month_number,
	day_of_week_number,
	day_of_week_name,
	DATEPART(hour,(CAST(a.start_time as time)))


order by 
	a.month_number,
	DATEPART(QUARTER, a.start_date),
	DATENAME(MONTH, a.start_date),
	day__of_month_number,
	day_of_week_number,
	DATEPART(hour,(CAST(a.start_time as time))),
	a.user_category,
	a.rideable_type


----------- Checking for NULLs -----------

select
	SUM(CASE when customer_id is NULL then 1 else 0 END) as customer_id,
	SUM(CASE when first_name is NULL then 1 else 0 END) as first_name,
	SUM(CASE when [gender] is NULL then 1 else 0 END) as [gender],
	SUM(CASE when [past_3_years_bike_related_purchases] is NULL then 1 else 0 END) as [past_3_years_bike_related_purchases],
	SUM(CASE when [DOB] is NULL then 1 else 0 END) as [DOB], -- 87 NULLs
	SUM(CASE when [job_title] is NULL then 1 else 0 END) as [job_title], -- 506 NULLs
	SUM(CASE when [job_industry_category] is NULL then 1 else 0 END) as [job_industry_category],
	SUM(CASE when [wealth_segment] is NULL then 1 else 0 END) as [wealth_segment],
	SUM(CASE when [deceased_indicator] is NULL then 1 else 0 END) as [deceased_indicator],
	SUM(CASE when [owns_car] is NULL then 1 else 0 END) as [owns_car],
	SUM(CASE when tenure is NULL then 1 else 0 END) as tenure -- 87 NULLs

from CustomerDemographic


-- Creating Profit Bucketing based on Quartile

ALTER TABLE transactions
ADD quartile INT, sale_category varchar


With quartiles as
(
select
	transaction_id,
	NTILE(4) over(order by profit) as quartile
from Transactions
Where profit is not NULL
)
Update Transactions
SET quartile = q.quartile
from quartiles q
where Transactions.transaction_id = q.transaction_id


ALTER Table transactions
Alter column sale_category varchar(max) -- increased the length


Update Transactions
SET
sale_category =
	CASE -- bucketing into 4
		WHEN quartile = 1 then 'Bronze'
		WHEN quartile = 2 then 'Silver'
		WHEN quartile = 3 then 'Gold'
		WHEN quartile = 4 then 'Platinium'
		ELSE CAST(quartile as varchar)
	END


-- Removing Duplicates

With RowNumCTE as(
select *,
	ROW_NUMBER() over (
	partition by parcelID,
				 propertyaddress,
				 SalePrice,
				 SaleDate,
				 LegalReference
				 order by 
					uniqueID
					) row_num
from NashvilleHousing..NashvilleHousing
)
Delete
from RowNumCTE
where row_num > 1


-- Can you further breakdown this average value into 30 day periods (i.e. 0-30 days, 31-60 days etc)

WITH trial_plan AS (
    SELECT customer_id, 
	   start_date AS trial_date
    FROM subscriptions
    WHERE plan_id = 0
),
annual_plan AS (
    SELECT customer_id,
	   start_date as annual_date
    FROM subscriptions
    WHERE plan_id = 3
)
select
	CONCAT(FLOOR(DATEDIFF(day, trial_date, annual_date) / 30) * 30, '-', FLOOR(DATEDIFF(day, trial_date, annual_date) / 30) * 30 + 30, 'days') as period, -- this one is complicated and new to me
	COUNT(*) as total_customers,
	AVG(datediff(day, trial_date, annual_date)) as avg_days_to_upgrade

from trial_plan t
join annual_plan a
on t.customer_id = a.customer_id

group by FLOOR(DATEDIFF(day, trial_date, annual_date) / 30)


-- How would you calculate the rate of growth for Foodie-Fi? based on total amount

With quarter_cte as
(
select
	s.customer_id,
	s.plan_id,
	p.price,
	s.start_date,
	DATEPART(year, s.start_date) as year,
	DATEPART(quarter, s.start_date) as quarter
from subscriptions s
left join plans p
on s.plan_id = p.plan_id
)
select
	year,
	quarter,
	SUM(price) as total_amount,
	lag(sum(price),1) over(order by year, quarter) as prev_total_amount,
	growth_rate = ROUND((SUM(price) - lag(sum(price),1) over(order by year, quarter)) / lag(sum(price),1) over(order by year, quarter)*100,2)

from quarter_cte
group by year, quarter
order by 1,2


-- Generate an order item for each record in the customers_orders table based on toppings

with extras_cte as 
(
select
	distinct order_id,
	'Extra ' + STRING_AGG(t.topping_name, ', ') as extra_toppings
from extras e 
left join pizza_toppings t
on e.topping_id = t.topping_id
group by order_id
),
exclusions_cte as
(
select
	order_id,
	'Exclude ' + STRING_AGG(t.topping_name, ', ') as excluded_toppings
from exclusions e
left join pizza_toppings t
on e.topping_id = t.topping_id
group by order_id
),
union_cte as 
(
select * from extras_cte
UNION
select * from exclusions_cte
) 
select
	c.order_id,
	CONCAT_WS(' - ', p.pizza_name, u.extra_toppings) as pizza_and_toppings
	--p.pizza_name + ' - ' + u.extra_toppings as pizza_and_toppings

from customer_orders c
left join union_cte u
on c.order_id = u.order_id

left join pizza_names p
on c.pizza_id = p.pizza_id

group by c.order_id, p.pizza_name, u.extra_toppings
order by 1
