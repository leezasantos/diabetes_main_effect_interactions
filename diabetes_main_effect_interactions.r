# This dataset was used for a statistical study "Impact of HbA1c Measurement on Hospital Readmission Rates: Analysis of 70,000 Clinical Database Patient Records"
# by Beata Strack,1 Jonathan P. DeShazo,2 Chris Gennings,3 Juan L. Olmo,4 Sebastian Ventura,4 Krzysztof J. Cios,1,5 and John N. Clore6.

# This dataset include 101766 observations and 51 variables however, to complete our task, we will only be utilizing 5 variables consisting of 3 categorical(DV) and 2 continuous (IV).
# We have 5 tasks: 
# 1. Recode ‘category’ into High, Medium, and Low levels.
# 2. Recode ‘age’ age into Child, Adult, and Elderly levels. 
# 3. Determine if there is a main effect of RACE (utilizing levels of white or black only) or AGE (utilizing levels of child or adult only) on medication account and provide p-value for Race and Age.
# 4. Determine if there is an interaction effect of CATEGORY (utilizing levels of low, medium, and high levels) or RACE (utilizing all five levels with the original dataset) with medication count and provide p-value for Category, Race, and interaction. 
# 5. Provide the appropriate visualization that displays question 4 => category (with three levels), and race (with five levels) with medication count as the y-axis. 



library(DBI) # for database connection
library(dplyr) # for data maipulation 
library("ggpubr") # for visuzliation 
library(moments) # for assumption testing 
library(car) # for assumption test / CAR package for non-balanced designs
library(stringr) # for string manipulation 
library(psych) # for descriptives 
library(summarytools) # for advanced stats / descriptives 
library(CGPfunctions) # for plotting 2 factor anova nice and clean
library(pwr) # generic plot function
library(tidyverse) # design philosophy, grammar, and data structures
library(caret) # for model training and / or prediction

# Connect to MySQL database 
con <- DBI::dbConnect(odbc::odbc(),
                      Driver    = "MySQL", 
                      Server    = "34.204.170.21",
                      Database = "examples",
                      UID       = "dba",
                      PWD       = "ahi2020",
                      Port      = "3306")

# Retrieve dataset from 'diabetes_santos'
df <- dbReadTable(con, "diabetes_santos")

# Assessing dataset

# This dataset includes 51 variables, let's make it more manageable to 5: 3 categorical(DV) and 2 continuous (IV)
df_sub <- df %>% select ('num_medications', 'race', 'gender', 'age', 'medical_specialty')

# Renaming the following columns: 'num_medications', 'medical_specialty', and 'gender' 
df_sub <- df_sub %>% rename('medcount' = 'num_medications', 'category' = 'medical_specialty', 'sex' = 'gender')

# There are several '?' characters that may represent NULL/NA, let's replace '?' to signify NULL / NA 
df_sub <- replace(df_sub, df_sub == '?', NA)

# Should we remove NULL / NA values? 
sum(is.na(df_sub))
# Out of 101,766 observations, there are 52,222 null values making up about 51% of our dataset. 
# Removing null values may significantly affect our data so we will leave them for now. 

# Let's find out our data types
df_sub_types <- sapply(df_sub, class)            # sapply takes data frame as input and gives output in vector or matrix

race = as.data.frame(table(df_sub$race))         # as.data.frame is a method to coerce other objects to class data.frame
sex = as.data.frame(table(df_sub$sex))
age = as.data.frame(table(df_sub$age))
category = as.data.frame(table(df_sub$category))

# Let's make sure that our continuous variable 'medcount' really is continuous data by converting it to numeric
df_sub$medcount <- as.numeric(df_sub$medcount)




# Task 1. Recode ‘category’ into High, Medium, and Low levels.

# First, let's make a table that converts each of our unique strings from 'CATEGORY' into a numerical value. 
# This provides us the frequency of each of the medical specialty from least to greatest.  
# For example, the frequency of 'Dermatology' and 'Neurophysiology' in 'CATEGORY' are both 1, therefore, they will both appear as '1'
category_frequency <- as.integer(ave(df_sub$category, df_sub$category, FUN = length)) 
df_sub$category_coded <- category_frequency                #Moving the table 'category_frequency' into the dataframe

# These numbers signify how many times a medical specialty from the column 'CATEGORY' is input. For example, the frequency of 'Dermatology' and 'Neurophysiology' in 'CATEGORY' are both 1, therefore, they will be under the  
lowfreq = c(1:500)         # This implies that all numbers from 1 TO 500 will equal to low frequency 
medfreq = c(501:5000)
highfreq = c(5001:15000)

df_sub$category_coded <- ifelse(df_sub$category_coded %in% lowfreq, "lowfreq", 
                                ifelse(df_sub$category_coded %in% highfreq, "highfreq", "medfreq"))





# Task 2. Recode ‘age’ age into Child, Adult, and Elderly levels.

# Age is already represented in ranges of 10 and goes up to 100. But they are represented with parenthesis and brackets, so let's remove them.
df_sub$age <- str_replace(df_sub$age, "\\[", "")                       # "\\" Use special character as NORMAL character not function
df_sub$age <- str_replace(df_sub$age, "\\)", "")

# Let's categorize the age of our dataframe from ranges to:
# Child 0-10 
# Teen 10-20
# Adult 20-30, 30-40
# Middle Adult 40-60
# Senior 60-70 70-80 80-90 90-100

child = c("0-10")
teen = c("10-20")
adult = c("20-30", "30-40")
middle_adult = c("40-50", "50-60")
senior = c("60-70", "70-80", "80-90", "90-100")

df_sub$age_coded <- ifelse(df_sub$age %in% child, "Child", 
                           ifelse(df_sub$age %in% teen, "Teen", 
                                  ifelse(df_sub$age %in% adult, "Adult",
                                         ifelse(df_sub$age %in% senior, "Senior", "Middle_Adult"))))





# Task 3. Determine if there is a main effect of RACE (utilizing levels of White or Black only) or AGE (utilizing levels of child or adult only). 
# on medication account and provide p-value for Race and Age.

# A main effect is the effect of a single independent variable on a dependent variable [RACE or AGE] – ignoring all other independent variables.

# This dataset has 5 races: Caucasian [White], African American [Black], Asian, Hispanic, and Other. We only need Black and White. 
white = c("Caucasian")
black = c("AfricanAmerican")
df_sub$race_coded = ifelse(df_sub$race %in% white, "white", "black")


# Calculate MAIN EFFECT for of RACE (utilizing levels of white or black only) or AGE (utilizing levels of child or adult only) on medication account
# If p < .05 for the main effect of race and age, then there is a significant effect. 
res.aov <- aov(medcount ~ race_coded * age_coded, data = df_sub)
summary(res.aov)
# Results:
#   Df                      Sum  Sq Mean    Sq     F value     Pr(>F)    
#  race_coded                1   21011    21011    323.505   <2e-16 ***
#  age_coded                 4   92110    23028    354.552   <2e-16 ***
#  race_coded:age_coded      4     333      83     1.282      0.274    
#  Residuals               101756 6608870   65                   
---
  #  Signif. codes:  0 ‘***’ 0.001 ‘**’ 0.01 ‘*’ 0.05 ‘.’ 0.1 ‘ ’ 1
  
  
  # The p-value for race_coded and age_coded is are < 0.05 suggesting there is a SIGNIFICANT main effect of RACE (utilizing levels of white or black only) 
  # or AGE (utilizing levels of child or adult only) on med count. 
  # The main effect of race on medcount was significant (F = 323.505, p = <2e-16), similarly, the main effect of age on medcount was significant (F = 354.552, p = <2e-16). 
  
  
  # Visual representation of medcount by AGE [CHILD AND ADULT ONLY] and RACE [BLACK AND WHITE ONLY]. Additional code was used to arrange the x-axis for easier representation. 
  df_sub$age_coded <- factor(df_sub$age_coded,levels = c("Child", "Adult"))       # Arrange
Plot2WayANOVA(medcount ~ age_coded * race_coded, df_sub, plottype = "line", 
              errorbar.display = "CI",
              xlab = "age_group",
              ylab = "med_count",
              title = "Med count by race and age with 95% confidence interval") 
# Based on this graph, it seems that the White sample has a slightly larger medcount. 
# However, this may be due to a slightly larger sample size from White respondents. 
df_sub %>%
  distinct() %>%
  count(race_coded)
# Results: 
# race_coded      n
#      black    7994
#      white    8146

# Box plot visualization of 
df_sub$age_coded <- factor(df_sub$age_coded,levels = c("Child", "Adult"))     # We only want Child and Adult
boxplot(medcount ~ race_coded * age_coded, data = df_sub,
        col=c("blue","green","blue","green"),
        xlab = "Age Group",
        ylab = "Medication Count", 
        main="Boxplot of Race (Black and White) and Age (Child and Adult) Medication Count")







# Task 4. Determine if there is an interaction effect of CATEGORY (utilizing levels of low, medium, and high levels) or RACE 
# (utilizing all five levels with the original dataset) with medication count and provide p-value for Category, Race, and interaction.

# An interaction effect occurs if there is an interaction between the independent variables that affect the dependent variable.
# If the p-value of the interaction effect is not significant (p > .05) , then our conclusion would be that category or race differences in med count
# did not depend on category or race level (that is, the same medcount difference would be seen for all 3 categories and all 5 races).


# Calculating interaction effect between category_coded, race, and medcount
model2 <- lm(medcount ~ race * category_coded, data = df_sub)
# Summarize the model
summary(model2)

# Results: 
# Estimate                                    Std.      Error    t value  Pr(>|t|)    
# (Intercept)                              14.70128    0.30425   48.320   < 2e-16 ***
#   raceAsian                              -2.37985    1.55457   -1.531   0.125802    
# raceCaucasian                             0.83945    0.34323   2.446    0.014459 *  
#   raceHispanic                          0.26236    1.12949   0.232    0.816322    
# raceOther                                 0.43975    0.96274   0.457    0.647840    
# category_codedmedfreq                     1.20962    0.31388   3.854    0.000116 ***
#   category_codedhighfreq               -0.05239    0.31805  -0.165    0.869166    
# raceAsian:category_codedmedfreq           0.91966    1.62842   0.565    0.572242    
# raceCaucasian:category_codedmedfreq       0.12664    0.35370   0.358    0.720306    
# raceHispanic:category_codedmedfreq        1.37803    1.15821  -1.190    0.234133    
# raceOther:category_codedmedfreq          -0.28085    1.00555  -0.279    0.780018    
# raceAsian:category_codedhighfreq          0.10482    1.61959   0.065    0.948397    
# raceCaucasian:category_codedhighfreq     -0.28267    0.35919  -0.787    0.431306    
# raceHispanic:category_codedhighfreq      -1.87093    1.16499  -1.606    0.108286    
# raceOther:category_codedhighfreq         -1.12716    1.02199  -1.103    0.270067    
---
  #   Signif. codes:  0 ‘***’ 0.001 ‘**’ 0.01 ‘*’ 0.05 ‘.’ 0.1 ‘ ’ 1
  
  # Residual standard error: 8.067 on 99478 degrees of freedom
  # (2273 observations deleted due to missingness)
  # Multiple R-squared:  0.01312,	Adjusted R-squared:  0.01298 
  # F-statistic: 94.48 on 14 and 99478 DF,  p-value: < 2.2e-16
  
  # Make predictions
  predictions <- model2 %>% predict(df_sub)
# Model performance
# (a) Prediction error, RMSE
RMSE(predictions, df_sub$medcount)
# Results: NA

R2(predictions, df_sub$medcount)

# Our results suggest that all the coefficients are statistically significant, suggesting that there is an interaction relationship 
# between the all 5 races and med count and all 3 categories and med count. 






# Task 5.
df_sub$category_coded <- factor(df_sub$category_coded,levels = c("lowfreq", "medfreq", "highfreq"))       # Arrange
Plot2WayANOVA(medcount ~ category_coded * race, df_sub, plottype = "line", 
              errorbar.display = "CI",
              xlab = "category_group",
              ylab = "med_count",
              title = "Med count by race and category with 95% confidence interval")

# The less parallel the lines are, the more likely there is to be a significant
# interaction. From the graph above, we see that the lines are definitely not parallel, so we would expect an interaction.
