library(MASS)
library(tidyverse)

data <- read_csv("Exp2_Prior.csv", col_types = cols())
data$Id <- factor(data$Id)
length(unique(data$Id)) # 50 participants

summarydata <- data %>% dplyr::select(-Key) %>% separate(TestImage, into=c("Trash","Type"),sep=11) %>%
  dplyr::select(-Trash) %>% rename(ParticipantKey=Id) %>%
  separate(Type,into=c("Shape","Trash"),sep=-5) %>% dplyr::select(-Trash) %>%
  separate(Shape,into=c("Image","TempSplit"),sep="[0-9]")
summarydata$Condition = "Overspecification"
summarydata[which(summarydata$TempSplit==""),]$Condition = "Underspecification"
summarydata <- dplyr::select(summarydata,-TempSplit)

# Underspecification parameter --------------
Underspec <- summarydata %>% filter(Condition=="Underspecification") %>% dplyr::select(Judgment) %>% table %>% prop.table


# Overspecification (prior distribution) -------------

Overspec <- summarydata %>% filter(Condition=="Overspecification") %>%
group_by(ParticipantKey) %>%
summarise(Judgment=mean(Judgment))
# Make beta computable
Overspec[which(Overspec$Judgment==0),]$Judgment=0.01
Overspec[which(Overspec$Judgment==1),]$Judgment=0.99
BetaFit <- fitdistr(Overspec$Judgment,"beta",list(shape1=1/2,shape2=1/2))

BetaFit # 0.32, 1.12
