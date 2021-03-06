# Uma Vaidyanathan - Technical Exercise: Part 1

# Packages needed for exercise
library(WDI)
library(ggplot2)
library(plotly)
library(dplyr)
library(Hmisc)
library(gridExtra)

# Now for some basic data access and cleaning

# Access World Bank API for data on life expectancy for males and females
male_life_expectancy = WDI(indicator='SP.DYN.LE00.MA.IN', start = 1960, extra = TRUE)
female_life_expectancy = WDI(indicator='SP.DYN.LE00.FE.IN', start = 1960, extra = TRUE)

# Check which variables have missing values
colnames(male_life_expectancy)[colSums(is.na(male_life_expectancy)) > 0]
colnames(female_life_expectancy)[colSums(is.na(female_life_expectancy)) > 0]
# Looks like it's just life expectancy that's missing values from variables needed for analysis.

# Create variable for gender for male and female datasets to help distinguish when merging
female_life_expectancy$gender <- "Female"
male_life_expectancy$gender <- "Male"

# Rename life expectancy variable into "life_expect" for merging
colnames(female_life_expectancy)[colnames(female_life_expectancy)=="SP.DYN.LE00.FE.IN"] <- "life_expect"
colnames(male_life_expectancy)[colnames(male_life_expectancy)=="SP.DYN.LE00.MA.IN"] <- "life_expect"

# Merge male and female data frames
life_expectancy_dat <- rbind(female_life_expectancy, male_life_expectancy)

# Pull out rows you need for life expectancy for whole world
life_world_dat <- life_expectancy_dat[life_expectancy_dat$country %in% c("World"), ]

# Plot the "World" region to get a quick and dirty check of what to expect
ggplot(life_world_dat, aes(year, life_expect, group =interaction(country, gender), color=country)) + geom_line(aes(linetype=gender)) + xlab('Year') + ylab('Life Expectancy') + labs(title = "Life Expectancy")

# Drop rows in dataset that are regions/aggregates or missing - i.e., keep only countries
# There are 211 countries in total, with others being regions.
life_expectancy_countries_dat <- life_expectancy_dat[(life_expectancy_dat$region!="Aggregates") & (!is.na(life_expectancy_dat$region)),]

life_expectancy_countries_dat <- life_expectancy_countries_dat[c("year", "country", "life_expect", "gender")]

# Examine missing value patterns
missing_counts <- aggregate(life_expect ~ country + gender, data=life_expectancy_countries_dat, function(x) {sum(is.na(x))}, na.action = NULL)
missing_counts <- missing_counts[missing_counts$life_expect != 0,]
# Some notes:
# Looks like it's the same set of countries for males and females that are missing, and the same numbers of males and females missing in every country
# Missing Countries are mostly smaller islands or small states, etc. As such, they likely will not affect world average too much. Most of them to my eye also do not appear to be conflict or disaster prone regions suggesting that this is not necessarily a large part of the reason for missing values. 
# Also note that missing values happen in all years for some countries meaning that some countries have no data whatsoever.
# Let's make sure all countries included in dataset have at least one third of values (arbitrary cutoff) across years so that we impute remaining values with some confidence.
# There are 52 data points for each country, so 1/3rd would be 52/3 ~= 17  years minimum for each country 
# Drop 19 countries since they have too few data points or none - 19/211 = lost 9% of data
# There are 192 countries remaining with at least 1/3rd of data points from 1960-2011.
countries_to_drop <- missing_counts$country[missing_counts$life_expect > 34]
life_expectancy_countries_dat <- life_expectancy_countries_dat[!(life_expectancy_countries_dat$country %in% countries_to_drop),]


# Next, I am going to impute missing values using a technique similar to linear regression called predictive mean matching (PMM). It calculates predicted values using regression. The extra step it then takes is to pick the 5 closest elements to the predicted value by Euclidean distance. These elements are called the donor pool and the final predicted value is chosen from random from this donor pool. PMM can impute values that are not normally distributed, unlike standard linear regression.
# The reasons I am using a regression-based method as opposed to substituting with mean, median, or mode are as follows:
# 1.) Life expectancy shows a clear rising trend from the 1960s to 2012. So, substituting in mean or median will systematically under- or over-estimate towards existing data points
# 2.) Life expectancy will likely also be affected by factors such as gender and country. These can be taken into account in a more explicit way in a regression to help in estimates of missing data

# Disadvantages are that:
# 1.) I am assuming that a straight line will generally work when trying to model life expectancy from all other factors, which may or may not be true. Some countries for example may have huge spikes or dips from events such as wars, or policy changes. It doesn't look that shouldn't affect too many countries that have missing data here, but there's no way of knowing this for certain. Ideally, PMM should also help in handling some of this.
# 2.) Ultimately, we never really know why data is missing. It could just be that it wasn't recorded that year. Or it could be that there were specific reasons it wasn't available that year - e.g., natural disaster, war - which may not be captured entirely with the variables I have specified in the model.

# Impute regression based values for remaining countries with missing data
imputed_life_expects <- aregImpute(~ life_expect + year + gender + country, data = life_expectancy_countries_dat, n.impute = 5, type = "regression")

# Get the imputed values
imputed_values <-impute.transcan(imputed_life_expects, data=life_expectancy_countries_dat, imputation=1, list.out=TRUE, pr=FALSE, check=FALSE)

# Convert the list to a data frame
imputed_data <- as.data.frame(do.call(cbind, imputed_values))

# Add values to existing data frame
imputed_data <- imputed_data[, colnames(life_expectancy_countries_dat), drop = FALSE]

# Data frame is all factors. Convert numeric variables to numbers.
imputed_data$year <- as.numeric(as.character(imputed_data$year))
imputed_data$life_expect <- as.numeric(as.character(imputed_data$life_expect))
imputed_data$gender <- as.character(imputed_data$gender)
imputed_data$country <- as.character(imputed_data$country)

# Calculate average life expectancy for each year by males and females using imputed data
imputed_data_averages <- imputed_data %>% group_by(year, gender) %>% summarise(life_expect = mean(life_expect))

##############################

# Pull out rows you need for life expectancy by income analysis
life_income_dat <- life_expectancy_dat[life_expectancy_dat$country %in% c("Lower middle income" ,"Low income" , "High income", "Upper middle income"), ]

# Would ideally do a repeated measures ANOVA here to see if there is a statistical difference in life expectancy depending on income level of country and age. However, instructions suggest making sure output is suited for a non-technical audience.
##############################


## Analysis of Life Expectancy at Birth

## The data presented here were obtained using the World Bank API. Yearly data on life expectancy at birth (in years) for males and females from all countries from 1960 - 2011 were downloaded. Only countries that had data for at least a third or more of this time span were utilized in analyses (192 out of 211 listed in the WDI). In brief, the graphs below show that life expectancy at birth has been increasing in a linear manner from 1960 till 2011. This pattern is the same for both females and males (graph on left, with solid and dotted lines respectively). It is also the same across all countries in various income levels ranging from low to high (graph on right), suggesting a strong consistency to results. Another striking finding is that women have a higher life expectancy at birth than men regardless of the year they were born in from 1960 - 2011, and regardless of the country's income level as well. While increased income level of country is also related to increased life expectancy, the gender effect of being female on greater life expectancy holds strong regardless of income level of country.


# Code for creating plots below
# Order levels of income for formatting legend properly
life_income_dat$country <- factor(life_income_dat$country, levels = c("High income", "Upper middle income", "Lower middle income", "Low income"))

# Rename column names for formatting legend properly
colnames(life_income_dat)[colnames(life_income_dat)=="gender"] <- "Gender"
colnames(life_income_dat)[colnames(life_income_dat)=="country"] <- "Country"

# Create subplots
all_countries_plot <- ggplot(imputed_data_averages, aes(year, life_expect, group=gender)) + geom_line(aes(linetype=gender)) + xlab('Year') + ylab('Life Expectancy at Birth') + labs(title = "Across All Countries") + ylim(35,85) + theme(title = element_text(size=8), plot.title = element_text(hjust = 0.5), axis.title = element_text(size=12)) 

life_income_plot <- ggplot(life_income_dat, aes(year, life_expect, group =interaction(Country,Gender), color=Country)) + geom_line(aes(linetype=Gender)) + xlab('Year') + ylab(NULL) + labs(title = "By Income Level of Country") + ylim(35,85) + theme(legend.position="bottom", title = element_text(size=8), plot.title = element_text(hjust = 0.5), axis.title = element_text(size=12)) + guides(colour = guide_legend(ncol = 2, nrow = 2), title.position="top", title.hjust = 0.5)

# Create combined legend for plot
g_legend<-function(a.gplot){
tmp <- ggplot_gtable(ggplot_build(a.gplot))
leg <- which(sapply(tmp$grobs, function(x) x$name) == "guide-box")
legend <- tmp$grobs[[leg]]
return(legend)}

mylegend<-g_legend(life_income_plot)

# Combined plot
combined_life_plots <- grid.arrange(arrangeGrob(all_countries_plot + theme(legend.position="none"), life_income_plot + theme(legend.position="none"), nrow=1, top = "Life Expectancy at Birth"), mylegend, heights=c(6, 1))
