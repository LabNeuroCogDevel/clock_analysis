# plots MLM coefficients by sensor across timepoints and frequencies
# first run meg_time_freq_load_analyze_medusa.R

library(tidyverse)
library(lme4)
library(ggpubr)
library(car)
library(viridis)

encode = T
rt_predict = F

# library(psych)
repo_directory <- "~/code/clock_analysis"
data_dir <- "~/OneDrive/collected_letters/papers/meg/plots/dual_source/"  
dual_plot_dir = "~/OneDrive/collected_letters/papers/meg/plots/dual_source/"  

clock_epoch_label = "Time relative to clock onset, seconds"
rt_epoch_label = "Time relative to outcome, seconds"

labels <- as_tibble(readxl::read_excel("~/code/clock_analysis/fmri/keuka_brain_behavior_analyses/dan/MNH Dan Labels.xlsx")) %>%
  select(c("roinum", "plot_label", "Stream", "Visuomotor_Gradient", "Stream_Gradient", "lobe")) %>% filter(!is.na(lobe))

names(labels) <- c("roinum","label_short", "stream", "visuomotor_grad", "stream_grad", "lobe")
labels$stream_grad <- as.numeric(labels$stream_grad)
labels <- labels %>% arrange(visuomotor_grad, stream_grad) %>% mutate(
  side  = case_when(
    grepl("L_", label_short) ~ "L",
    grepl("R_", label_short) ~ "R"),
  label_short = substr(label_short, 3, length(label_short)),
  label = paste(visuomotor_grad, stream_grad, label_short, side, sep = "_"),
  stream_side = paste0(stream, "_", side),
  visuomotor_side = paste0(visuomotor_grad, "_", side)) %>% 
  select(c(label, label_short, side, roinum, stream, visuomotor_grad, stream_grad, stream_side, visuomotor_side, lobe))
labels <- labels %>% mutate(node = paste(lobe, side, sep = "_")) 
short_labels <- labels %>% mutate(roinum = as.factor(roinum)) %>% select(roinum, node)
node_list <- unique(labels$node) %>% sort()
clock_epoch_label = "Time relative to clock onset, seconds"
rt_epoch_label = "Time relative to outcome, seconds"


setwd(data_dir)
# plots ----
if (encode) {  
  message("Plotting encoding results")
  # epoch_label = "Time relative to outcome, seconds"
  epoch_label = "Time relative to clock onset, seconds"
  alignment = "clock"
  # get clock-aligned data
  file_pattern <- "tf_ddf_source_clock"
  files <-  gsub("//", "/", list.files(data_dir, pattern = file_pattern, full.names = F))
  l <- lapply(files, readRDS)
  names(l) <- node_list[parse_number(files)]
  cddf <- data.table::rbindlist(l, idcol = "node") %>% filter(Time > -1.5)
  # sanity check
  # table(cddf$node, cddf$.filename)
  cddf <- cddf %>% mutate(t  = as.numeric(Time), alignment = "clock",
                          term = case_when(
                            term=="rt_lag_sc" ~ "RT_t",
                            term=="rt_csv_sc" ~ "RT_tPLUS1",
                            term=="reward_lagReward" ~ "reward_t",
                            term=="rt_vmax" ~ "RT_Vmax_t",
                            term=="scale(rt_vmax_change)" ~ "RT_Vmax_change_t",
                            term=="v_entropy_wi_change_lag" ~ "V_entropy_change_t",
                            TRUE ~ term
                          )
  )
  # get RT-aligned
  file_pattern <- "tf_ddf_source_RT"
  files <-  gsub("//", "/", list.files(data_dir, pattern = file_pattern, full.names = F))
  l <- lapply(files, readRDS)
  names(l) <- node_list[parse_number(files)]
  rddf <- data.table::rbindlist(l, idcol = "node") %>% filter(Time > -1.5)
  rddf <- rddf %>% mutate(t  = Time - 5, 
                          alignment = "rt",
                          # get shared variables
                          term = case_when(
                            term=="rt_csv_sc" ~ "RT_t",
                            term=="outcomeReward" ~ "reward_t",
                            term=="scale(rt_vmax_lag)" ~ "RT_Vmax_t",
                            term=="scale(rt_vmax_change)" ~ "RT_Vmax_change_t",
                            term=="v_entropy_wi_change" ~ "V_entropy_change_t",
                            TRUE ~ term
                          )
  )
  
  ddf <- rbind(cddf, rddf)
  terms <- unique(ddf$term[ddf$effect=="fixed"])
  # ddf$sensor <- readr::parse_number(ddf$.filename, trim_ws = F)
  # ddf$sensor <- stringr::str_pad(ddf$sensor, 4, "0",side = "left")
  ddf <- ddf %>% mutate(p_value = as.factor(case_when(`p.value` > .05 ~ '1',
                                                      `p.value` < .05 & `p.value` > .01 ~ '2',
                                                      `p.value` < .01 & `p.value` > .001 ~ '3',
                                                      `p.value` <.001 ~ '4'))                        # sensor = as.character(sensor)
  )
  ddf$p_value <- factor(ddf$p_value, labels = c("NS", "p < .05", "p < .01", "p < .001"))
  
  # FDR labeling ----
  ddf <- ddf  %>% mutate(
    # p_fdr = padj_fdr_term,
    p_level_fdr = as.factor(case_when(
      # p_fdr > .1 ~ '0',
      # p_fdr < .1 & p_fdr > .05 ~ '1',
      padj_BY_term > .05 ~ '1',
      padj_BY_term < .05 & padj_BY_term > .01 ~ '2',
      padj_BY_term < .01 & padj_BY_term > .001 ~ '3',
      padj_BY_term <.001 ~ '4'))) %>% filter(Time < 3)
  ddf$p_level_fdr <- factor(ddf$p_level_fdr, levels = c('1', '2', '3', '4'), labels = c("NS","p < .05", "p < .01", "p < .001"))
  ddf$`p, FDR-corrected` = ddf$p_level_fdr
  
  levels(ddf$Freq) <- substr(unique(ddf$Freq), 3,6)
  ddf$freq <- fct_rev(ddf$Freq)
  # drop magnetometers (if any)
  # ddf <- ddf %>% filter(!grepl("1$", sensor))
  # add sensor labels
  setwd(data_dir)
  for (fe in terms) {
    edf <- ddf %>% filter(term == paste(fe))
    termstr <- str_replace_all(fe, "[^[:alnum:]]", "_")
    message(termstr)
    fname = paste("meg_tf_source_uncorrected_", termstr, ".pdf", sep = "")
    pdf(fname, width = 10, height = 7.5)
    print(ggplot(edf, aes(t, freq)) + geom_tile(aes(fill = estimate, alpha = p_value), size = .01) +
            geom_vline(xintercept = 0, lty = "dashed", color = "black", size = 2) +
            geom_vline(xintercept = -5, lty = "dashed", color = "white", size = 2) +
            geom_vline(xintercept = -5.3, lty = "dashed", color = "white", size = 1) +
            geom_vline(xintercept = -2.5, lty = "dotted", color = "grey", size = 1) +
            scale_fill_viridis(option = "plasma") +  xlab(rt_epoch_label) + ylab("Frequency") +
            facet_wrap( ~ node, ncol = 2) + 
            geom_text(data = edf, x = -5.5, y = 5,aes(label = "Response(t)"), size = 2.5, color = "white", angle = 90) +
            geom_text(data = edf, x = -4.5, y = 5,aes(label = "Outcome(t)"), size = 2.5, color = "white", angle = 90) +
            geom_text(data = edf, x = 0.5, y = 6 ,aes(label = "Clock onset (t+1)"), size = 2.5, color = "black", angle = 90) +
            labs(alpha = expression(italic(p)[uncorrected])) + ggtitle(paste(termstr)) + theme_dark())
    dev.off()
    
    fname = paste("meg_tf_source_FDR_", termstr, ".pdf", sep = "")
    pdf(fname, width = 10, height = 7.5)
    print(ggplot(edf, aes(t, freq)) + geom_tile(aes(fill = estimate, alpha = p_level_fdr), size = .01) +
            geom_vline(xintercept = 0, lty = "dashed", color = "black", size = 2) +
            geom_vline(xintercept = -5, lty = "dashed", color = "white", size = 2) +
            geom_vline(xintercept = -5.3, lty = "dashed", color = "white", size = 1) +
            geom_vline(xintercept = -2.5, lty = "dotted", color = "grey", size = 1) +
            scale_fill_viridis(option = "plasma") +  xlab(rt_epoch_label) + ylab("Frequency") +
            facet_wrap( ~ node, ncol = 2) + 
            geom_text(data = edf, x = -5.5, y = 5,aes(label = "Response(t)"), size = 2.5, color = "white", angle = 90) +
            geom_text(data = edf, x = -4.5, y = 5,aes(label = "Outcome(t)"), size = 2.5, color = "white", angle = 90) +
            geom_text(data = edf, x = 0.5, y = 6 ,aes(label = "Clock onset (t+1)"), size = 2.5, color = "black", angle = 90) +
            labs(alpha = expression(italic(p)[FDR])) + ggtitle(paste(termstr)) + theme_dark())    # 
    dev.off()
  }
} 
# system("for i in *scaled*.pdf; do sips -s format png $i --out $i.png; done")

if(rt_predict) {
  # plots ----
  epoch_label = "Time relative to clock onset, seconds"
  # get clock-aligned data
  file_pattern <- "rdf_combined_clock"
  files <-  gsub("//", "/", list.files(data_dir, pattern = file_pattern, full.names = F))
  l <- lapply(files, readRDS)
  names(l) <- node_list[parse_number(files)]
  crdf <- data.table::rbindlist(l, idcol = "node") %>% filter(grepl('Pow', term))
  crdf <- crdf %>% mutate(t  = as.numeric(Time), alignment = "clock",
                          term = case_when(
                            term=="scale(Pow)" ~ "Power",
                            term== "scale(Pow):rt_lag_sc" ~ "RT_t * Power",
                            term=="scale(Pow):scale(rt_vmax)" ~ "RT_Vmax_t * Power",
                            TRUE ~ term
                          )
  )
  # get RT-aligned
  file_pattern <- "rdf_combined_RT"
  files <-  gsub("//", "/", list.files(data_dir, pattern = file_pattern, full.names = F))
  l <- lapply(files, readRDS)
  names(l) <- node_list[parse_number(files)]
  rrdf <- data.table::rbindlist(l, idcol = "node") %>% filter(grepl('Pow', term))
  rrdf <- rrdf %>% mutate(t  = as.numeric(Time) - 5, alignment = "clock",
                          term = case_when(
                            term=="scale(Pow)" ~ "Power",
                            term=="scale(Pow):rt_csv_sc"  ~ "RT_t * Power",
                            term== "scale(Pow):rt_lag_sc" ~ "RT_tMINUS1 * Power",
                            term=="scale(Pow):scale(rt_vmax)" ~ "RT_Vmax_t * Power",
                            TRUE ~ term
                          )
  )
  
  rdf <- rbind(crdf, rrdf)
  terms <- unique(rdf$term[rdf$effect=="fixed" & grepl(rdf$term, "Power")])
  # rdf$sensor <- readr::parse_number(rdf$.filename, trim_ws = F)
  # rdf$sensor <- stringr::str_pad(rdf$sensor, 4, "0",side = "left")
  rdf <- rdf %>% mutate(p_value = as.factor(case_when(`p.value` > .05 ~ '1',
                                                      `p.value` < .05 & `p.value` > .01 ~ '2',
                                                      `p.value` < .01 & `p.value` > .001 ~ '3',
                                                      `p.value` <.001 ~ '4'))                        # sensor = as.character(sensor)
  )
  rdf$p_value <- factor(rdf$p_value, labels = c("NS", "p < .05", "p < .01", "p < .001"))
  
  # FDR labeling ----
  rdf <- rdf  %>% mutate(
    # p_fdr = padj_fdr_term,
    p_level_fdr = as.factor(case_when(
      # p_fdr > .1 ~ '0',
      # p_fdr < .1 & p_fdr > .05 ~ '1',
      padj_BY_term > .05 ~ '1',
      padj_BY_term < .05 & padj_BY_term > .01 ~ '2',
      padj_BY_term < .01 & padj_BY_term > .001 ~ '3',
      padj_BY_term <.001 ~ '4'))
  ) %>% ungroup() #%>% mutate(side = substr(as.character(label), nchar(as.character(label)), nchar(as.character(label))),
  # region = substr(as.character(label), 1, nchar(as.character(label))-2))
  rdf$p_level_fdr <- factor(rdf$p_level_fdr, levels = c('1', '2', '3', '4'), labels = c("NS","p < .05", "p < .01", "p < .001"))
  rdf$`p, FDR-corrected` = rdf$p_level_fdr
  
  levels(rdf$Freq) <- substr(unique(rdf$Freq), 3,6)
  rdf$freq <- fct_rev(rdf$Freq)
  # drop magnetometers (if any)
  # rdf <- rdf %>% filter(!grepl("1$", sensor))
  # add sensor labels
  setwd(data_dir)
  
  
  for (fe in terms) {
    edf <- rdf %>% filter(term == paste(fe)) 
    termstr <- str_replace_all(fe, "[^[:alnum:]]", "_")
    message(termstr)
    fname = paste("meg_tf_RT_predict_uncorrected_", termstr, ".pdf", sep = "")      
    pdf(fname, width = 10, height = 7.5)
    print(ggplot(edf %>% filter(estimate < 0), aes(t, freq)) + geom_tile(aes(fill = estimate, alpha = p_value), size = .01) + 
            scale_fill_distiller(palette = "OrRd", direction = 1, name = "Exploration", limits = c(-.1, 0)) + scale_x_continuous(breaks = pretty(edf$t, n = 20)) + labs(fill = "Exploration") +
            labs(alpha = expression(italic(p)[uncorrected])) + ggtitle(paste(termstr)) +
            new_scale_fill() +
            geom_tile(data = edf %>% filter(estimate > 0), aes(t, freq, fill = estimate, alpha = p_value), size = .01) + theme_dark() +
            geom_vline(xintercept = 0, lty = "dashed", color = "black", size = 2) + theme_bw() + 
            scale_fill_distiller(palette = "GnBu", direction = -1, name = "Exploitation", limits = c(0, .15))+ scale_color_grey() + xlab(epoch_label) + ylab("Frequency") + 
      geom_vline(xintercept = 0, lty = "dashed", color = "black", size = 2) +
      geom_vline(xintercept = -5, lty = "dashed", color = "black", size = 2) +
      geom_vline(xintercept = -5.3, lty = "dashed", color = "black", size = 1) +
      geom_vline(xintercept = -2.5, lty = "dotted", color = "grey", size = 1) +
      facet_wrap( ~ node, ncol = 2) + 
      geom_text(data = edf, x = -5.5, y = 5,aes(label = "Response(t)"), size = 2.5, color = "black", angle = 90) +
      geom_text(data = edf, x = -4.5, y = 5,aes(label = "Outcome(t)"), size = 2.5, color = "black", angle = 90) +
      geom_text(data = edf, x = 0.5, y = 6 ,aes(label = "Clock onset (t+1)"), size = 2.5, color = "black", angle = 90) +
        labs(alpha = expression(italic(p)[uncorrected])) + ggtitle(paste(termstr))) + scale_y_discrete(limits = rev(levels(rdf$p_level_fdr))) 
      
    dev.off()
    fname = paste("meg_tf_RT_predict_FDR_", termstr, ".pdf", sep = "")      
    pdf(fname, width = 10, height = 7.5)
    print(ggplot(edf %>% filter(estimate < 0), aes(t, freq)) + geom_tile(aes(fill = estimate, alpha = p_level_fdr), size = .01) + 
            scale_fill_distiller(palette = "OrRd", direction = 1, name = "Exploration", limits = c(-.1, 0)) + scale_x_continuous(breaks = pretty(edf$t, n = 20)) + labs(fill = "Exploration") +
            labs(alpha = expression(italic(p)[uncorrected])) + ggtitle(paste(termstr)) +
            new_scale_fill() +
            geom_tile(data = edf %>% filter(estimate > 0), aes(t, freq, fill = estimate, alpha = p_value), size = .01) + theme_dark() +
            geom_vline(xintercept = 0, lty = "dashed", color = "black", size = 2) + theme_bw() + 
            scale_fill_distiller(palette = "GnBu", direction = -1, name = "Exploitation", limits = c(0, .15))+ scale_color_grey() + xlab(epoch_label) + ylab("Frequency") + 
      geom_vline(xintercept = 0, lty = "dashed", color = "black", size = 2) +
      geom_vline(xintercept = -5, lty = "dashed", color = "black", size = 2) +
      geom_vline(xintercept = -5.3, lty = "dashed", color = "black", size = 1) +
      geom_vline(xintercept = -2.5, lty = "dotted", color = "grey", size = 1) +
      facet_wrap( ~ node, ncol = 2) + 
      geom_text(data = edf, x = -5.5, y = 5,aes(label = "Response(t)"), size = 2.5, color = "black", angle = 90) +
      geom_text(data = edf, x = -4.5, y = 5,aes(label = "Outcome(t)"), size = 2.5, color = "black", angle = 90) +
      geom_text(data = edf, x = 0.5, y = 6 ,aes(label = "Clock onset (t+1)"), size = 2.5, color = "black", angle = 90) +
        labs(alpha = expression(italic(p)[FDR-corrected])) + ggtitle(paste(termstr))) + labs(fill = "Exploitation") 
      
    dev.off()
  }
  
  # convert to PNG for Word
  # system("for i in *meg_tf*.pdf; do sips -s format png $i --out $i.png; done")
  
}

