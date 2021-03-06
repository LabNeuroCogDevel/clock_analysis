# brain-to-behavior analyses with anterior (low entropy) and posterior (PE) hippocampal cluster betas
# first run beta_cluster_import_pca_clean.R if not run once already

library(dplyr)
library(tidyverse)
library(psych)
library(corrplot)
library(lme4)
library(ggpubr)
library(lmerTest)
library(stargazer)
library(car)
library(sjstats)
library(sjPlot)
library(emmeans)
library(cowplot)
# install_github("UNCDEPENdLab/dependlab")
library(dependlab)
source('~/code/Rhelpers/screen.lmerTest.R')
source('~/code/Rhelpers/vif.lme.R')
# library(stringi)

# clock_folder <- "~/Data_Analysis/clock_analysis" #michael
clock_folder <- "~/code/clock_analysis" #alex

# source('~/code/Rhelpers/')
setwd(file.path(clock_folder, 'fmri/keuka_brain_behavior_analyses/'))

### load data
# load('trial_df_and_vhdkfpe_clusters.Rdata')
# cleaner version with only H, PE and uncertainty trial vars
unsmoothed = F
if (unsmoothed) {
  load('trial_df_and_vh_pe_clusters_u_unsmoothed.Rdata')
} else { load('trial_df_and_vh_pe_clusters_u.Rdata') }

############# Main analysis using Schaeffer-based betas

# # compare MEG and fMRI
# df$session <- "fMRI"
# mdf$session <- "MEG"
# bdf <- bind_rows(df, mdf)
# ggplot(bdf, aes(run_trial, rt_csv, color = rewFunc, lty = session)) + geom_smooth()
# ggplot(bdf, aes(run_trial, ev, color = rewFunc, lty = session)) + geom_smooth()


###############################################
# RT swing distribution by condition and betas
###############################################
# filter out missed trials
fdf <- df %>% filter(rt_csv < 4000)
fmdf <- mdf %>% filter(rt_csv < 4000)
# actually, fMRI and MEG look so similar that we can replicate everything later, 
# after we sort thigns out in fMRI

# density: RT swings, non-directional
p1 <- ggplot(fdf %>% filter(rt_swing > 500), aes(rt_swing, color = dan_h_resp)) + geom_density() + facet_grid(~rewFunc)
p2 <- ggplot(fdf %>% filter(rt_swing > 500), aes(rt_swing, color = pe_ips_resp)) + geom_density() + facet_grid(~rewFunc)
ggarrange(p1, p2, ncol = 1, nrow = 2)

# density: RT change, directional
p1 <- ggplot(fdf, aes(rt_change, color = dan_h_resp, lty = last_outcome)) + geom_density() #+ facet_grid(~last_outcome)
p2 <- ggplot(fdf, aes(rt_change, color = pe_ips_resp, lty = last_outcome)) + geom_density() #+ facet_grid(~last_outcome)
ggarrange(p1, p2, ncol = 1, nrow = 2)

p1 <- ggplot(fdf, aes(rt_change, color = dan_h_resp)) + geom_density() + facet_wrap(~last_outcome, scales="free_y", )
p2 <- ggplot(fdf, aes(rt_change, color = pe_ips_resp)) + geom_density() + facet_wrap(~last_outcome, scales="free_y")
ggarrange(p1, p2, ncol = 1, nrow = 2)

# RT timecourses
p1 <- ggplot(fdf, aes(run_trial, rt_csv, color = dan_h_resp)) + geom_smooth() + facet_grid(~rewFunc)
p2 <- ggplot(fdf, aes(run_trial, rt_csv, color = pe_ips_resp)) + geom_smooth() + facet_grid(~rewFunc)
ggarrange(p1, p2, ncol = 1, nrow = 2)

# RT swing timecourses
p1 <- ggplot(fdf, aes(run_trial, rt_swing, color = dan_h_resp)) + geom_smooth(method = "loess") + facet_grid(~rewFunc)
p2 <- ggplot(fdf, aes(run_trial, rt_swing, color = pe_ips_resp)) + geom_smooth(method = "loess") + facet_grid(~rewFunc)
ggarrange(p1, p2, ncol = 1, nrow = 2)

# add interaction
ggplot(fdf, aes(run_trial, rt_swing, color = pe_ips_resp, lty = dan_h_resp)) + geom_smooth(method = "loess") + facet_grid(~rewFunc)

# RT swing timecourses
p1 <- ggplot(fdf %>% filter(!is.na(last_outcome)), aes(trial_neg_inv_sc, rt_swing_lr, color = dan_h_resp)) + geom_smooth() + facet_grid(~last_outcome)
p2 <- ggplot(fdf %>% filter(!is.na(last_outcome)), aes(trial_neg_inv_sc, rt_swing_lr, color = pe_ips_resp)) + geom_smooth() + facet_grid(~last_outcome)
pdf("inspect_last_plot.pdf", height = 6, width = 8)
ggarrange(p1, p2, ncol = 1, nrow = 2)
dev.off()

# lmer w/o the shoulders
m0 <- lmer(rt_csv ~ rt_lag_sc * pe_ips + (1|ID/run), fdf)
summary(m0)

mb_pe_ips_dan <-  lmer(rt_csv_sc ~ (trial_neg_inv_sc + rt_lag_sc + rewFunc + general_entropy +
                                      pe_ips)^2 + 
                         (1|id/run), df %>% filter(rt_csv<4000 ))
screen.lmerTest(mb_pe_ips_dan, .05)
Anova(mb_pe_ips_dan)

mb_pe_cort_hipp <-  lmer(rt_csv_sc ~ (trial_neg_inv_sc + rt_lag_sc + rt_vmax_lag_sc + pe_f1_cort_hipp)^2 + 
                         (1|id/run), df %>% filter(rt_csv<4000 ))
screen.lmerTest(mb_pe_cort_hipp, .05)


m1 <- lmer(rt_csv ~ rt_lag_sc * pe_ips + (1|ID), df %>% filter(rt_swing < 1500))
summary(m1)

acf(df$rt_swing[df$dan_h_resp=='high_h_dan'], na.action = na.pass, lag.max = 10)
acf(df$rt_swing[df$dan_h_resp=='low_h_dan'], na.action = na.pass, lag.max = 10)

