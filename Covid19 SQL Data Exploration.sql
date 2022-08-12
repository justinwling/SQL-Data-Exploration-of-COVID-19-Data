

-- **Exploring COVID-19 data obtained from "Our World in Data" between 02-24-20 and 04-30-21**

-- Data was split into two excel files that were converted to CSV files before import into a Microsoft SQL Server
-- The two databases: dbo.CovidDeaths & dbo.CovidVaccinations

-- Replacing blank cells in the 'continent' column with a NULL value instead
-- Also replacing values of 0 in total_cases with a NULL value
UPDATE..CovidDeaths
SET continent = NULLIF(continent, ''), total_cases = NULLIF(total_cases, '0')


-- **Viewing some of the columns of data sorting by Location and date**
-- By excluding rows that have a null continent, the locations will all be names of countries and won't include groupings such as 'South America', 'Asia', & 'world'
select *
from COVID19_PortfolioProject..CovidDeaths
where continent is not null
order by 1,2


-- **Looking at Total Deaths vs Total Cases in the United States as as a percentage**
-- Shows the general chance of dying of COVID-19 if formally diagnosed within the U.S.
-- Does not take into consideration demographics of the individuals or the criteria to be considered a death from COVID-19

select Location, date, total_cases, total_deaths, (total_deaths/total_cases)*100 as DeathPercentage 
FROM COVID19_PortfolioProject..CovidDeaths
where location like 'United States'
order by 1,2

-- **Looking at Total Cases vs Population in the U.S.**
-- Shows the percentage of the population that has been diagnosed with COVID-19

select Location, date, total_cases, Population, (total_cases/population)*100 as '% of Population dx with Covid' 
FROM COVID19_PortfolioProject..CovidDeaths
where location like 'United States'
order by 1,2

-- **Looking at the countries that have had the highest percent of COVID-19 cases per capita**
-- Data had "0" in some population data, needed to use the NULLIF() expression avoid "divide by zero error"
-- cast() was used because the data type was float and was displaying in scientific notation, which can make the data harder to interpret at a quick glance
select Location, MAX(total_cases) as 'Max Total Cases', cast(Population as bigint) as Population, MAX((total_cases/nullif(population, 0)))*100 as 'Percent Cases vs Population'
FROM COVID19_PortfolioProject..CovidDeaths
where continent is not null
Group by Location, population
order by 4 desc


-- **Showing countries with the highest total death count**
select Location, MAX(total_deaths) as 'Highest Total Deaths'
FROM COVID19_PortfolioProject..CovidDeaths
where continent is not null
Group by Location
order by 'Highest Total Deaths' desc


-- **Showing highest death count by continent instead of country**
select location, MAX(total_deaths) as 'Highest Total Deaths'
FROM COVID19_PortfolioProject..CovidDeaths
-- This only includes the rows where the name of the continent is contained in the location column instead of the continent column
-- World and International is also excluded in the results in order to only show data on the continents 
--     Code have been written differently, such as location !='World' or location<>'World' if I was just removing one item
where continent is null AND location not in ('World', 'International')
Group by location
order by 'Highest Total Deaths' desc


-- Joining two tables together - 'Covid Deaths' and 'Covid Vaccinations'
-- Joining on location and date

-- Looking at Total Population vs Vaccinations per day
-- Partition by dea.location is used in order to add the 'new_vaccinations' by date to show the sum or total vaccinations
-- without letting the SUM() expression add vaccination numbers from different locations together 
-- (keeping the total vaccinations organized by location/country instead of worldwide)
Select dea.continent, dea.location, dea.date, dea.population, vac.new_vaccinations, 
-- The partition needed to be ordered by location and date in order to have the total vaccinations show per day rather than grand total
SUM(CONVERT(int, vac.new_vaccinations)) OVER (Partition by dea.Location Order by dea.location, dea.date) as Rolling_Total_Vaccinated
From COVID19_PortfolioProject..CovidDeaths dea
Join COVID19_PortfolioProject..CovidVaccinations vac
	On dea.location = vac.location
	and dea.date = vac.date
where dea.continent is not null
order by 2,3



-- Using a CTE (Common Table Expression) in order to use the 'Rolling_Total_Vaccinated' in another calculation 
-- to get the percent total vaccinated vs population

With PopvsVac (Continent, Location, Date, Population, new_vaccinations, Rolling_Total_Vaccinated)
as
(
Select dea.continent, dea.location, dea.date, dea.population, vac.new_vaccinations, 
SUM(CONVERT(int, vac.new_vaccinations)) OVER (Partition by dea.Location Order by dea.location, dea.date) as Rolling_Total_Vaccinated
From COVID19_PortfolioProject..CovidDeaths dea
Join COVID19_PortfolioProject..CovidVaccinations vac
	On dea.location = vac.location
	and dea.date = vac.date
where dea.continent is not null
)
-- NULLIF() used again due to 'divide by zero' error again
Select *, (Rolling_Total_Vaccinated/NULLIF(population,0))*100 as Percent_total_Vac_vs_Population
From PopvsVac



-- Temp Table
-- used for similar reason as the above CTE to get the percent total vaccinated vs population

DROP Table if exists #PercentPopulationVaccinated
Create Table #PercentPopulationVaccinated
(
Continent nvarchar(255),
location nvarchar(255),
date datetime,
population numeric,
new_vaccinations numeric,
Rolling_Total_Vaccinated numeric
)

Insert into #PercentPopulationVaccinated
Select dea.continent, dea.location, dea.date, cast(dea.population as bigint), cast(vac.new_vaccinations as int), 
-- The partition needed to be ordered by location and date in order to have the total vaccinations show per day rather than grand total
SUM(CONVERT(int, vac.new_vaccinations)) OVER (Partition by dea.Location Order by dea.location, dea.date) as Rolling_Total_Vaccinated
From COVID19_PortfolioProject..CovidDeaths dea
Join COVID19_PortfolioProject..CovidVaccinations vac
	On dea.location = vac.location
	and dea.date = vac.date
where dea.continent is not null

Select *, (Rolling_Total_Vaccinated/NULLIF(population,0))*100 as Percent_total_Vac_vs_Population
From #PercentPopulationVaccinated



--Creating Views to store data for later visualizations

Create View PercentPopulationVaccinated as
Select dea.continent as Continent, dea.location as Location, dea.date as Date, cast(dea.population as bigint) as Population, cast(vac.new_vaccinations as int) as New_Vaccinations, 
SUM(CONVERT(int, vac.new_vaccinations)) OVER (Partition by dea.Location Order by dea.location, dea.date) as Rolling_Total_Vaccinated
From COVID19_PortfolioProject..CovidDeaths dea
Join COVID19_PortfolioProject..CovidVaccinations vac
	On dea.location = vac.location
	and dea.date = vac.date
where dea.continent is not null



-- **Showing highest death count by continent instead of country**
Create View HighestDeathCounts as
select Location, MAX(total_deaths) as 'Highest Total Deaths'
FROM COVID19_PortfolioProject..CovidDeaths
where continent is not null
Group by Location