library(MASS)
library(tidyverse)

data <- read_csv("Exp1_Prior.csv")
data$Id <- factor(data$Id)
summary <- data %>% dplyr::select(-Key) %>% separate(TestImage,into=c("Trash","Type"),sep=18) %>%
  dplyr::select(-Trash) %>% rename(ParticipantKey=Id) %>%
  separate(Type,into=c("Condition","Trash"),sep=4) %>%
  separate(Trash, into=c("Number","Trash"),sep=2) %>%
  dplyr::select(-Trash) %>% filter(Condition!="")
summary$Condition <- factor(summary$Condition)

levels(summary$Condition) = c("Underspecification","Overspecification")

# Compute under-specification parameter -------------
# Four judgments per person, so here we calculate the base rate.
summary %>% filter(Condition=="Underspecification") %>% dplyr::select(Judgment) %>% table %>% prop.table
# 5.5%

# Compute over-specifiation beta distribution ------------
training <- summary %>% filter(Condition=="Overspecification") %>%
  group_by(ParticipantKey) %>% summarise(Judgment=mean(Judgment))
# Make Beta computable
training[which(training$Judgment==0),]$Judgment=0.01
training[which(training$Judgment==1),]$Judgment=0.99
fitdistr(training$Judgment,"beta",list(shape1=1,shape2=1))# 0.39, 0.32
