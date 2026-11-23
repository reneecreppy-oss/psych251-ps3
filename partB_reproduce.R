# PS3 Part B reproduction (Experiment 1): Jara-Ettinger & Rubio-Fernandez (2021), Science Advances.
# Adapted from the authors' OSF scripts (osf.io/h8qfy, AnalysisFiles/).
# Changes from the authors' code: no setwd() (paths are relative to this repo),
# plotting/figure-saving code removed, and results are collected into named objects.
# The statistical steps (processing, exclusions, correlations, bootstrap seeds) are unchanged.

library(tidyverse)
library(boot)

osf <- "partB_osf/files"

# Shared helpers (verbatim from the authors' scripts) -------------------------
.GetR <- function(data, id) cor(data[id, ]$human, data[id, ]$Prediction)
.GetLower_CI <- function(data) {
  samples <- boot::boot(data, .GetR, 10000)
  boot::boot.ci(samples, type = "basic")$basic[4]
}
.GetTop_CI <- function(data) {
  samples <- boot::boot(data, .GetR, 10000)
  boot::boot.ci(samples, type = "basic")$basic[5]
}
.GetRDiff <- function(data, id) {
  temp <- data[id, ]
  cor(temp$ToM, temp$human) - cor(temp$Deductive, temp$human)
}

# Rotation fix used in Exp. 1 and 2 processing (authors' logic, written as a function).
# 0 = no rotation; 1/2/3 = rotated once/twice/three times clockwise.
rotate_back <- function(df, prefixes) {
  out <- df
  for (p in prefixes) {
    x <- df[[paste0(p, "_x")]]; y <- df[[paste0(p, "_y")]]; r <- df$StimRotation
    out[[paste0(p, "_x")]] <- case_when(r == 0 ~ x, r == 1 ~ y, r == 2 ~ 1 - x, r == 3 ~ 1 - y)
    out[[paste0(p, "_y")]] <- case_when(r == 0 ~ y, r == 1 ~ 1 - x, r == 2 ~ 1 - y, r == 3 ~ x)
  }
  out
}

# =============================================================================
# EXPERIMENT 1: processing (from Exp1_ProcessRawData.R)
# =============================================================================
m_tom <- read_csv(file.path(osf, "ModelPredictions/Exp1_ToM_model.csv"), col_types = cols()) %>%
  filter(Type %in% c("VW", "Referent", "ReferentA")) %>% mutate(model = "ToM")
m_ded <- read_csv(file.path(osf, "ModelPredictions/Exp1_Alternative_model.csv"), col_types = cols()) %>%
  filter(Type %in% c("VW", "Referent", "ReferentA")) %>% mutate(model = "Deductive")
JModel <- bind_rows(m_tom, m_ded)

# Model referent probabilities -> trackpad x/y positions
JRef <- JModel %>% filter(Type %in% c("Referent", "ReferentA")) %>%
  spread(Variable, Value) %>% mutate(x = TR + BR, y = BL + BR) %>% select(-(BL:TR))
JRef <- full_join(
  JRef %>% filter(Type == "ReferentA") %>% select(-Type) %>% rename(lref_x = x, lref_y = y),
  JRef %>% filter(Type == "Referent")  %>% select(-Type) %>% rename(rref_x = x, rref_y = y),
  by = c("Trial", "model"))

# Model belief (blind-spot) probabilities -> trackpad x/y positions.
# Each "TL_TR_BL"-style label lists the 3 visible cells, so the blind spot is the missing one.
CG <- JModel %>% filter(Type == "VW",
                        Variable %in% c("TL_TR_BL", "TL_TR_BR", "TL_BL_BR", "TR_BL_BR"))
CG$Variable <- factor(CG$Variable)
levels(CG$Variable) <- c("TR", "BR", "BL", "TL")   # authors' relabeling: hidden cell
CG <- CG %>% spread(Variable, Value) %>% mutate(cg_x = TR + BR, cg_y = BL + BR) %>%
  select(-(TR:TL), -Type)

Keys <- read_csv(file.path(osf, "ModelPredictions/Exp1_TrialKeys.csv"), col_types = cols())
names(Keys)[1] <- "Trial"   # strip the byte-order mark from the first column name
Exp1_Model <- full_join(JRef, CG, by = c("Trial", "model")) %>%
  full_join(Keys, by = "Trial") %>% select(-Trial, -TrialId) %>% rename(TrialId = CorrectTrialId)

raw1 <- read_csv(file.path(osf, "RawData/Exp1_RawData.csv"), col_types = cols())
n_raw1 <- n_distinct(raw1$UserId)

# Authors drop 3 surplus participants (latest 3 in list condition 2) to get 60
extras <- raw1 %>% group_by(UserId, ListCondition) %>% summarise(key = min(Key), .groups = "drop") %>%
  filter(ListCondition == 2) %>% slice_max(key, n = 3)
d1 <- raw1 %>% filter(!UserId %in% extras$UserId)

# Normalize trackpad pixels to 0-1 (min/max across all judgments)
d1 <- d1 %>% gather(judgment, value, lref_x:cg_y) %>%
  mutate(value = value - min(value), value = value / max(value)) %>% spread(judgment, value)
# Undo left/right counterbalancing
swap <- d1$LeftCounterbalance == 0
d1[swap, c("lref_x", "lref_y", "rref_x", "rref_y")] <- d1[swap, c("rref_x", "rref_y", "lref_x", "lref_y")]
d1 <- d1 %>% select(-LeftCounterbalance) %>% rotate_back(c("cg", "lref", "rref"))
# Fix trial-label typos using the key file
d1 <- d1 %>% left_join(Keys %>% select(TrialId, CorrectTrialId), by = "TrialId") %>%
  select(-TrialId) %>% rename(TrialId = CorrectTrialId)
n_analyzed1 <- n_distinct(d1$UserId)

# Check against the authors' posted processed files
proc1 <- read_csv(file.path(osf, "ProcessedData/Exp1_Participants.csv"), col_types = cols())
check1 <- d1 %>% select(UserId, TrialId, lref_x:rref_y) %>%
  pivot_longer(-c(UserId, TrialId)) %>%
  inner_join(proc1 %>% select(UserId, TrialId, lref_x:rref_y) %>% pivot_longer(-c(UserId, TrialId)),
             by = c("UserId", "TrialId", "name"))
exp1_processing_max_diff <- max(abs(check1$value.x - check1$value.y))
exp1_processing_rows_matched <- nrow(check1)

# =============================================================================
# EXPERIMENT 1: analysis (from Exp1_AnalyzeResults.R)
# =============================================================================
datasum <- d1 %>% group_by(TrialId) %>%
  summarise(across(c(cg_x, cg_y, lref_x, lref_y, rref_x, rref_y), mean))
AllData1 <- Exp1_Model %>% gather(variable, value, lref_x:cg_y) %>% spread(model, value) %>%
  full_join(datasum %>% gather(variable, human, cg_x:rref_y), by = c("TrialId", "variable")) %>%
  mutate(Type = if_else(variable %in% c("cg_x", "cg_y"), "belief", "referent"))

Melted1 <- AllData1 %>% rename(`ToM model` = ToM) %>% gather(Model, Prediction, `ToM model`, Deductive)

# Targets 1-3a: trial-level correlations with bootstrapped 95% CIs (authors' seed)
set.seed(23754)
exp1_corrs <- Melted1 %>% group_by(Type, Model) %>%
  do(data.frame(r = cor(.$Prediction, .$human), Lower = .GetLower_CI(.), Top = .GetTop_CI(.))) %>%
  ungroup() %>% arrange(Model)

# Target 3b: ToM minus deductive correlation for beliefs, with bootstrapped CI (authors' seed)
exp1_delta <- AllData1 %>% group_by(Type) %>%
  summarise(Delta = cor(human, ToM) - cor(human, Deductive))
set.seed(7582)
bs_delta <- boot::boot(filter(AllData1, Type == "belief"), .GetRDiff, R = 10000)
exp1_delta_ci <- boot::boot.ci(bs_delta, type = "basic")$basic[4:5]

# Target 4 (KEY EFFECT): subject-level correlations, paired t-test
IndData <- Exp1_Model %>% gather(variable, value, lref_x:cg_y) %>% spread(model, value) %>%
  full_join(d1 %>% select(UserId, TrialId, cg_x:rref_y) %>% gather(variable, human, cg_x:rref_y),
            by = c("TrialId", "variable")) %>%
  mutate(Type = if_else(variable %in% c("cg_x", "cg_y"), "belief", "referent"))
AllInd <- IndData %>% group_by(UserId, Type) %>%
  summarise(ToM = cor(human, ToM), Deductive = cor(human, Deductive), .groups = "drop")
exp1_subject_means <- AllInd %>% group_by(Type) %>%
  summarise(n = n(), mean_ToM = mean(ToM), mean_Deductive = mean(Deductive))
bel <- filter(AllInd, Type == "belief")
exp1_key_t <- t.test(bel$ToM, bel$Deductive, paired = TRUE)
exp1_key_dz <- mean(bel$ToM - bel$Deductive) / sd(bel$ToM - bel$Deductive)   # Cohen's d_z
ref <- filter(AllInd, Type == "referent")
exp1_ref_t <- t.test(ref$ToM, ref$Deductive, paired = TRUE)

