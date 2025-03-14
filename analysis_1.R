
# analysis

library(readODS)
library(readxl)
library(tidyr)
library(lme4)
library(lmerTest)
library(ggplot2)

# ==== FUNCTIONS ====

# function to display file name and get user input on whether to read it
read_file_or_not <- function(file_name) {
  selected_input <- readline(prompt = paste("Read ",file_name,"? (Enter Y or N) ",sep=""))
  if(selected_input == 'Y'){
    return(TRUE)
  }
  else if(selected_input == 'N'){
    return(FALSE)
  }
  else {
    print('Please enter Y or N')
    break
  }
}

# function to report on quantity of longitudinal data
# df must have "sub_id" and "time" cols, where time is either "ses01" or "ses02"
report <- function(sublist_df) {
  uniq_subs <- length(unique(sublist_df$sub_id))
  long_subs <- sum(duplicated(sublist_df$sub_id))
  t1_subs <- sum(sublist_df$time[!duplicated(sublist_df$sub_id) & !duplicated(sublist_df$sub_id, fromLast = TRUE)]=="ses01")
  t2_subs <- sum(sublist_df$time[!duplicated(sublist_df$sub_id) & !duplicated(sublist_df$sub_id, fromLast = TRUE)]=="ses02")
  
  return(cat('Total number of unique subjects: ',uniq_subs,
      '\nTotal number of subjects with long data (T1 and T2): ',long_subs,
      '\nTotal number of subjects with T1 data only: ',t1_subs,
      '\nTotal number of subjects with T2 data only: ',t2_subs,
      '\nTotal T1 data points: ',long_subs + t1_subs,
      '\nTotal T2 data points: ', long_subs + t2_subs,
      sep=''))
}

# function to display column numbers and names and get user input for selection
select_columns_console <- function(df) {
  # Display column numbers and names to the user
  cat("Columns in the dataframe:\n")
  for (i in 1:ncol(df)) {
    cat(i, ": ", colnames(df)[i], "\n", sep = "")
  }
  
  # Ask the user to input the column numbers they want to select
  selected_input <- readline(prompt = "Enter the column numbers you want to select, separated by commas: ")
  
  # Convert the input into a numeric vector
  selected_indices <- as.numeric(strsplit(selected_input, ",")[[1]])
  
  # Get the selected column names based on the user input
  selected_columns <- colnames(df)[selected_indices]
  
  # Return the selected column names
  return(selected_columns)
}

# function to match subs and time points in a new df to a reference df
# dfs are in long format; ref_df is "sublist", and new_df is whatever is new
# colnames must be "sub_id" and "time" with 'T1' or 'T2'
match_sub_time <- function(ref_df,new_df) {
  # if ref_df doesn't have the id_T column already
  if(!('id_T' %in% colnames(ref_df))) {
    ref_df$time[ref_df$time=='ses01'] <- 'T1'
    ref_df$time[ref_df$time=='ses02'] <- 'T2'
    ref_df$id_T <- paste(ref_df$sub_id,ref_df$time,sep="_") }
  
  # keep only correct time-points
  new_df$id_T <- paste(new_df$sub_id,new_df$time,sep="_")
  new_df <- new_df[new_df$id_T %in% ref_df$id_T,]
  if(all(new_df$sub_id==ref_df$sub_id)){
    if(all(new_df$id_T==ref_df$id_T)){
      print('solid matching dfs') 
      print('success')
      return(list(ref_df = ref_df, new_df = new_df))}
    } else {stop('Error: dfs do not match !')}}

# ==== combining data; CREATE DF master_df.csv FOR ANALYSIS ==== 

# read in complete list of subs
setwd('/mnt/projects/VIA_longitudin/adam/tasks/analysis_1')
sublist <- read_ods('sub_list.ods')

# only keep keepers,
# exclude based on:
# original image include (i.e., was it run through FS at all? OR is it usable or CORTICAL?)
# my qc ratings -- based on external primarily (i.e., pre, postcentral misaligned)
# stat outliers -- based on internal primarily (base and long data)
# euler outliers
sublist <- sublist[sublist$image_incl==1,]
sublist <- sublist[sublist$qc_incl==1,]
sublist <- sublist[sublist$base_out_incl==1,]
# sublist <- sublist[sublist$long_out_incl==1,]  # add this when sub exclusion finalized
# sublist <- sublist[sublist$euler_incl ==1,]    # add this when sub exclusion finalized 
sublist <- as.data.frame(sublist[,c(1,2)])
rownames(sublist) <- NULL
report(sublist)
# compare these subs with data you read in, does it all match?

# BASIC DEMOGRAPHICS
# get demo variables to control for
# only include subs in sublist
setwd('/mnt/projects/VIA_longitudin/adam/tasks/analysis_1/')
demos <- as.data.frame(read_xlsx('VIA11-15_longitudinal_demograph_clinic_wide.xlsx'))
demos <- demos[demos$famlbnr %in% sublist$sub_id,]
# demos is in wide, must convert to long
# first get only important vars
# and clean them:
# ADD CONTROL VARIABLES HERE:   ... what else to control for? Psychotic-like experiences? Weight? Height?? Handedness? 
imp_cols <- c('via11_mri_age','via15_mri_age',
              'via11_mri_site','via15_mri_site',
              'sex_string','sex_code','sib_pair',
              'fhr_group_string','fhr_group_code')
# cleaning variables (i.e., string "NA" should be actual NA; numbers should be numeric):
for(imp_col in imp_cols){
  demos[[imp_col]] <- ifelse(demos[[imp_col]]=="NA",NA,demos[[imp_col]])
  if(imp_col == 'via11_mri_age' | imp_col == 'via15_mri_age' |
     imp_col == 'sib_pair'){
    demos[[imp_col]] <- as.numeric(demos[[imp_col]]) 
  }}
# get new df
demos <- demos[,c("famlbnr",imp_cols)]
# pivot from wide to long
# IMPORTANT:
# !!!!!
# CHANGE IF ADDING ADDITIONAL CONTROL VARIABLES
# !!!!!
colnames(demos)
# very important naming convention for each column
colnames(demos) <- c('sub_id','age_T1','age_T2',
                     'site_T1','site_T2','sex_str',
                     'sex','sib_pair','FHR_str','FHR')
demos_long <- as.data.frame(pivot_longer(demos, 
                    cols = c(age_T1, age_T2, site_T1, site_T2), 
                    names_to = c(".value", "time"),
                    names_sep = "_"))
# adjust and double check dfs are matching
df_list <- match_sub_time(sublist,demos_long)
sublist <- df_list$ref_df
demos_long <- df_list$new_df

# BRAIN DATA
# set directory for data
setwd('/mnt/projects/VIA_longitudin/adam/tasks/analysis_1/')
brain_long <- sublist[,c("sub_id","time")]
# loop through brain data files and select columns to add to your df, e.g.,
# lh_WhiteSurfArea_area
# rh_WhiteSurfArea_area
# lh_MeanThickness_thickness
# rh_MeanThickness_thickness
# BrainSegVolNotVent
# eTIV
# long-ish loop, double checks to make sure IDs and TIME matches across dfs
for(f in list.files(pattern='_long_')) {
  
  if(read_file_or_not(f)) {
    temp_brain_dat <- read.csv(f)
    temp_brain_dat <- temp_brain_dat[temp_brain_dat$famlbnr %in% sublist$sub_id,]
    temp_brain_dat <- temp_brain_dat[order(temp_brain_dat$famlbnr),]
    
    if(all(temp_brain_dat$famlbnr==sublist$sub_id)) {
      print('brain data sub ids match sublist ids')
      
      temp_brain_dat$session_id[temp_brain_dat$session_id=='ses01'] <- 'T1'
      temp_brain_dat$session_id[temp_brain_dat$session_id=='ses02'] <- 'T2'
      if(all(temp_brain_dat$session_id==sublist$time)) {
          print('brain data TIME matches sublist time, proceeding...')
        
          selected_cols <- select_columns_console(temp_brain_dat)
          print(selected_cols)
          
          for(m in selected_cols) {
            brain_long <- cbind(brain_long,temp_brain_dat[,m])
            colnames(brain_long)[ncol(brain_long)] <- colnames(temp_brain_dat[m])
          } 
    
          print(paste('Added cols: ',selected_cols,sep=''))
      } else { 
        print('brain data TIME does not match sublsit TIME, there is an issue') 
        } 
    } else {
      print('brain data IDs do not match sublist ids, there is an issue')
      print(paste('issue for ',f,sep=''))
    }
  }
}
# average the lh and rh measures to get the global
cols <- colnames(brain_long)
lh_cols <- grep("^lh_", cols, value = TRUE)
rh_cols <- grep("^rh_", cols, value = TRUE)
# loop: determine lh, rh pairs, then for each pair average them
for (lh in lh_cols) {
  base_name <- sub("^lh_", "", lh)
  rh_match <- grep(paste0("^rh_", base_name), rh_cols, value = TRUE)
  if (length(rh_match) > 0) {
    print(paste('averaging ',lh,' and ',rh_match,sep=''))
    brain_long[[paste(base_name,'_global',sep='')]] <- (brain_long[,lh] + brain_long[,rh_match])/2 }}
# adjust and double check dfs are matching
# the new df MUST have a "sub_id" col and a "time" col with "T1" and "T2"
df_list <- match_sub_time(sublist,brain_long)
sublist <- df_list$ref_df
brain_long <- df_list$new_df

# EULER NUMBER
setwd('/mnt/projects/VIA_longitudin/adam/tasks/analysis_1/')
fs_qa_long <- read.csv('VIA11-15_fs741_long_qa_measures_restructured.csv')
fs_qa_long <- fs_qa_long[fs_qa_long$famlbnr %in% sublist$sub_id,]
fs_qa_long <- fs_qa_long[order(fs_qa_long$famlbnr),]
fs_qa_long$sub_id <- fs_qa_long$famlbnr
fs_qa_long$time <- fs_qa_long$session_id
fs_qa_long$time[fs_qa_long$time=='ses01'] <- 'T1'
fs_qa_long$time[fs_qa_long$time=='ses02'] <- 'T2'
df_list <- match_sub_time(sublist,fs_qa_long)
sublist <- df_list$ref_df
fs_qa_long <- df_list$new_df

# CREATE MASTER DF FROM THE DFS YOU HAVE CREATED UP TO THIS POINT

master_df <- sublist[,c("sub_id","time")]

df_long_list <- list(demos_long,brain_long,fs_qa_long)

# select cols from the dfs you've created
# sub_id and time are ALREADY in the master_df
for(dat_fr in df_long_list){
  match_sub_time(master_df,dat_fr)
  selected_cols <- select_columns_console(dat_fr)
  print(selected_cols)
  
  master_df <- cbind(master_df,dat_fr[,c(selected_cols)])
  if(length(selected_cols) == 1) {
    colnames(master_df)[ncol(master_df)] <- selected_cols }
}

# write the master df to your directory:
setwd('/mnt/projects/VIA_longitudin/adam/tasks/analysis_1/')
write.csv(master_df,file='master_df.csv',row.names=FALSE)

# ==== visualizations ====

# read in data
setwd('/mnt/projects/VIA_longitudin/adam/tasks/analysis_1/')
master_df <- read.csv('master_df_TEST.csv')

ggplot(master_df, aes(x = time, y = MeanThickness_thickness_global, fill = FHR)) +
  geom_violin(trim = FALSE) +   
  scale_fill_brewer(palette = "Set3") +  
  labs(x = "Time", y = "Value", fill = "Group") +   
  theme_minimal()

# ==== analysis 1 ====

# read in data
setwd('/mnt/projects/VIA_longitudin/adam/tasks/analysis_1/')
master_df <- read.csv('master_df_TEST.csv')

# exclude sibling pairs??? ***

# !!!! Create false variable for testing statistical model !!!!

master_df$FHR_SHUFFLE <- sample(master_df$FHR)
table(master_df$FHR_SHUFFLE, master_df$FHR)

# analysis
# clean a little
master_df$sex_str[master_df$sex_str=="male"] <- 'M'
master_df$sex_str[master_df$sex_str=="female"] <- 'F'
# make sure variables are correct classes
master_df$sex <- as.factor(master_df$sex)
master_df$FHR <- as.factor(master_df$FHR)
master_df$FHR_SHUFFLE <- as.factor(master_df$FHR_SHUFFLE) # the false variable !
# change the reference to PBC (if desired)
master_df$FHR <- relevel(master_df$FHR, ref = "3")
master_df$FHR_SHUFFLE <- relevel(master_df$FHR_SHUFFLE, ref = "3") # the false variable !

# linear mixed effects model with random intercept
model <- lmer(BrainSegVolNotVent ~ time*FHR_SHUFFLE + age + sex_str + site +
                mean_eulnum_cross + (1 | sub_id), data = master_df)
summary(model)



# ==== end





