library(MASS)
library(tidyverse)

setwd("~/Documents/Projects/Common_ground/FinalOSF/Prior estimation studies/Priors for Experiment 3/")

data <- read_csv("Exp3_Prior.csv")

data$Id <- factor(data$Id)

summary <- data %>% dplyr::select(-Key) %>% separate(TestImage,into=c("Trash","Type"),sep="/") %>%
  dplyr::select(-Trash) %>% rename(ParticipantKey=Id) %>%
  separate(Type,into=c("Stimuli","Trash"),sep="\\.") %>%
  mutate(Condition=str_detect(Stimuli,"2")) %>%
  dplyr::select(-Trash)

summary$Condition <- factor(summary$Condition)

levels(summary$Condition) = c("Overspecification","Underspecification")

summary$Stimuli = gsub('[[:digit:]]+', '', summary$Stimuli)

summary$Type="Color"
summary[which(summary$Stimuli %in% c("DOG","CAR","SHOES","FLOWER")),]$Type="Category"
summary[which(summary$Stimuli %in% c("SUITCASE","BIRD","SOFA","RADIO")),]$Type="Size"

summary %>% ggplot(aes(x=Judgment,color=Condition))+geom_histogram(position="dodge")+facet_wrap(~Type)

summary %>% group_by(ParticipantKey,Condition,Type) %>%
  summarise(Judgment=mean(Judgment)) %>% ggplot(aes(x=Judgment,fill=Condition))+
  geom_histogram(position="dodge")+facet_wrap(~Type)

# UNDERSPECIFICATION: THIS IS A STATIC PARAMETER!
# Get probability of noise (failing to produce a color word when necessary)

summary %>% filter(Condition=="Underspecification") %>%
  dplyr::select(Judgment,Type) %>% table %>% prop.table

# OVERSPECIFICATION: THIS IS A PRIOR DISTRIBUTIOn

training <- summary %>% filter(Condition=="Overspecification") %>%
  group_by(ParticipantKey,Type) %>% summarise(Judgment=mean(Judgment))

# Make Beta computable
training[which(training$Judgment==0),]$Judgment=0.01
training[which(training$Judgment==1),]$Judgment=0.99
fitdistr(training$Judgment,"beta",list(shape1=1,shape2=1)) 

BetaFits <- lapply(c("Size","Color","Category"),function(x){return(fitdistr(filter(training,Type==x)$Judgment,"beta",list(shape1=1/2,shape2=1/2)))})
