library(readr)
library(ggplot2)
library(dplyr)
library(tidyr)

###
### Loading and preprocessing the data
###

# Show any code that is needed to
# 1. Load the data (i.e. `read.csv()`)
# 2. Process/transform the data (if necessary) into a format suitable for your analysis

activity <- read_csv("activity.zip")


###
### What is mean total number of steps taken per day?
###

# For this part of the assignment, you can ignore the missing values in the dataset.
# 1. Make a histogram of the total number of steps taken each day
ggplot(activity, aes(x = date, y = steps )) + geom_bar(stat = "sum")

# interest only
ggplot(activity, aes(x = date, y = steps, fill=factor(floor(interval/600)) )) + geom_bar(stat = "sum")
activity_split_by_date <- split(activity, factor(activity$date))
unlist( lapply(activity_split_by_date, function(x) { sum(x$steps) } ) ) %>% as.data.frame


# 2. Calculate and report the **mean** and **median** total number of steps taken per day
activity_by_day <- activity %>% filter(!is.na(steps)) %>% group_by(date) %>% summarise(step_mean = mean(steps), step_median = median(steps))
# OR better?
activity_by_day <- activity %>% group_by(date) %>% summarise(step_mean = mean(steps, na.rm = TRUE), step_median = median(steps, na.rm = TRUE))

# interest only
ggplot(activity_by_day, aes(x = date, y = step_mean) ) + geom_line()



###
### What is the average daily activity pattern?
###

# 1. Make a time series plot (i.e. `type = "l"`) of the
#      5-minute interval (x-axis)
#      and the average number of steps taken, averaged across all days (y-axis)

activity_by_interval <- activity %>% group_by(interval) %>% summarise(step_mean = mean(steps, na.rm = TRUE))

ggplot(activity_by_interval, aes(x = interval, y = step_mean) ) + geom_line()


# 2. Which 5-minute interval, on average across all the days in the dataset, contains the maximum number of steps?

# interest only
activity_by_interval %>% arrange(desc(step_mean))

activity_by_interval[which.max(activity_by_interval$step_mean),]
# A tibble: 1 × 3
  # interval step_mean step_median
     # <int>     <dbl>       <int>
# 1      835  206.1698          19


activity_by_interval[which.max(activity_by_interval$step_mean),]$interval
# [1] 835



###
### Imputing missing values
###

# Note that there are a number of days/intervals where there are missing values (coded as `NA`). The presence of missing days may introduce
#      bias into some calculations or summaries of the data.

# 1. Calculate and report the total number of missing values in the dataset (i.e. the total number of rows with `NA`s)

colSums(is.na(activity))
#    steps     date interval
#     2304        0        0

# There are 2304 missing values for the steps variable.


# 2. Devise a strategy for filling in all of the missing values in the dataset.
#    The strategy does not need to be sophisticated.
#    For example, you could use the mean/median for that day, or the mean for that 5-minute interval, etc.

# Which rows have missing step values?
activity_na  <- activity %>% filter(is.na(steps))

# Are these for whole days or for part days?
dates_na     <- unique(activity_na$date)

table(dates_na)
# 2012-10-01 2012-10-08 2012-11-01 2012-11-04 2012-11-09 2012-11-10 2012-11-14 2012-11-30
#        288        288        288        288        288        288        288        288

# So, missing values are for 8 complete days

# What weekdays are these?
unique(dates_na) %>% weekdays()
# [1] "Monday"    "Monday"    "Thursday"  "Sunday"    "Friday"    "Saturday"  "Wednesday" "Friday"


# So, perhaps use average of equivalent day intervals - so data missing for Monday is assigned the average of all the other Mondays
# Add a weekday to activity data set
activity$weekday <- weekdays(activity$date)

# Note that the days which have missng data are excluded in the mean() calculation
activity_weekday_mean <-
        activity %>% group_by(weekday, interval) %>% summarise(step_mean = mean(steps, na.rm = TRUE)) %>% select(weekday, interval, step_mean) %>%
                     spread(weekday, step_mean)

fill_missing_values <- function(date_missing) {

    # Create a temporary data frame for the date that is missing step data and
    # populate it by extracting the mean step values for the missing day
    fill_df  <- cbind( date_missing, activity_weekday_mean[c( weekdays(date_missing), "interval" )] )

    # Assign proper column names to the data frame and select those columns in the correct order
    names(fill_df) <- c("date", "steps", "interval")
    fill_df %>% select(steps, date, interval)
}



# create new tibble with filled in values for NA days, rbind this with original data set (with stripped out NA days)

# New tibble with filled in values
activity_na_dates  <- as.tbl( lapply(dates_na, fill_missing_values) %>% do.call(rbind, .) )

# Strip out NA days from original data set and drop weekday variable
activity_na_rm     <- activity %>% filter(!is.na(steps)) %>% select(-weekday)

# rbind the data sets together
rbind(activity_na_rm, activity_na_dates)



# 3. Create a new dataset that is equal to the original dataset but with the missing data filled in.

# This is the rbind of the data sets above, call arrange() to sort by date and interval as per the original data set
activity_filled <- rbind(activity_na_rm, activity_na_dates) %>% arrange(date, interval)


# 4. Make a histogram of the total number of steps taken each day and
#    Calculate and report the **mean** and **median** total number of steps taken per day.
#    Do these values differ from the estimates from the first part of the assignment?
#    What is the impact of imputing missing data on the estimates of the total daily number of steps?


ggplot(activity_filled, aes(x = date, y = steps )) + geom_bar(stat = "sum")

activity_filled_by_day <- activity_filled %>% group_by(date) %>% summarise(step_mean = mean(steps, na.rm = TRUE), step_median = median(steps, na.rm = TRUE))

###
### Are there differences in activity patterns between weekdays and weekends?
###

# For this part the `weekdays()` function may be of some help here. Use the dataset with the filled-in missing values for this part.

# 1. Create a new factor variable in the dataset with two levels -- "weekday" and "weekend" indicating whether a given date is a weekday or weekend day.
#
#
week_day_type <- function(date) {
    ifelse(weekdays(date) %in% c("Saturday", "Sunday"), "weekend", "weekday")
}

# set levels so that weekend plot is above weekday plot in part 2 below
activity_filled$week_day_type <- factor( week_day_type(activity_filled$date), levels = c("weekend", "weekday") )

# 2. Make a panel plot containing a time series plot (i.e. `type = "l"`) of
#      the 5-minute interval (x-axis)
#      and the average number of steps taken, averaged across all weekday days or weekend days (y-axis).
#    The plot should look something like the following, which was created using **simulated data**:


activity_filled_by_interval <- activity_filled %>% group_by(week_day_type, interval) %>% summarise(step_mean = mean(steps, na.rm = TRUE))

ggplot(activity_filled_by_interval, aes(x = interval, y = step_mean), color = "blue" ) +
        geom_line(color="blue") +
        facet_grid(week_day_type ~ .)

