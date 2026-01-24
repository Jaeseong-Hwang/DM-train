# rm(list = ls())

# data load, excel file
library(readxl)
library(tidyverse)
library(lubridate)
library(ggplot2)
library(janitor)
library(skimr)
library(writexl)
library(openxlsx)



# file_path <- "T:/APRICOT TO CASEWORTHY/1 CLIENTS/Clients - FINAL.xlsx"
file_path <- "Clients - FINAL.xlsx"
clients <- read_excel(file_path, col_names = TRUE, sheet = 1)

clients <- clients %>% 
  mutate(dob = format(as.Date(`Date of Birth`, format = "%m/%d/%Y"), 
                      "%m-%d-%Y"))


clients <- clients %>% 
  mutate(
    ethnicity = case_when(
      `Hispanic?` == "NO" ~ 1,
      `Hispanic?` == "YES" ~ 2,
      is.na(`Hispanic?`) ~ 99
      
    ), sharing = 1
  )

clients<- clients %>% 
  mutate(gender = 2, dobqo = 1, prounouns = 1, veteran = 99, rural= 3,
         country = 300, okphone = 1, oktext = 1, okemail = 1, 
         scid = 99, sharing = 1)



#########################################################
clients %>%
  summarise(
    Line1_missing = sum(is.na(Line1) | Line1 == ""),
    City_missing  = sum(is.na(City) | City == ""),
    State_missing = sum(is.na(State) | State == "")
  )


missing_rows <- clients %>%
  filter(is.na(Line1) | Line1 == "" |
           is.na(City)  | City == ""  |
           is.na(State) | State == "")

missing_rows


# # 파일명에 날짜 스탬프 포함 (선택)
# outfile <- paste0("missing_rows_", format(Sys.Date(), "%Y%m%d"), ".xlsx")

# 내보내기
write_xlsx(missing_rows, "missing_rows.xlsx")

missing_rows_cols <- missing_rows %>% select(Last, First, 'Date of Birth', 
                                             Line1, City, State)
write_xlsx(missing_rows_cols, "missing_rows_cols.xlsx")

################################################################



clients <- clients %>%
  unite(address, Line1, City, State,
        sep = ", ", na.rm = TRUE, remove = FALSE)

##########################################################################

clients <- clients %>%
  mutate(
    SSN_raw = `Social Security Number`,
    # 앞뒤 공백 제거 및 중간의 여러 공백/하이픈 정규화
    SSN_clean = SSN_raw %>%
      str_trim() %>%
      str_replace_all("[[:space:]]+", "") %>%  # 모든 공백 제거
      str_replace_all("[^0-9-]", "")     )
    

clients <- clients %>%
  mutate(
    # 기본 형식: 숫자3-숫자2-숫자4
    format_ok = str_detect(SSN_clean, "^[0-9]{3}-[0-9]{2}-[0-9]{4}$"),
    
    # 블록별 추출
    area   = ifelse(format_ok, str_sub(SSN_clean, 1, 3), NA),
    group  = ifelse(format_ok, str_sub(SSN_clean, 5, 6), NA),
    serial = ifelse(format_ok, str_sub(SSN_clean, 8, 11), NA),
    
    # 숫자로 변환
    area_n   = suppressWarnings(as.integer(area)),
    group_n  = suppressWarnings(as.integer(group)),
    serial_n = suppressWarnings(as.integer(serial)),
    
    # 금지 규칙
    area_ok   = !is.na(area_n)   & area_n != 0 & area_n != 666 & !(area_n >= 900 & area_n <= 999),
    group_ok  = !is.na(group_n)  & group_n != 0,
    serial_ok = !is.na(serial_n) & serial_n != 0,
    
    # 자주 쓰는 더미/가짜 값 차단
    is_common_dummy = SSN_clean %in% c("000-00-0000", "111-11-1111", "123-45-6789"),
    
    # 최종 유효성
    ssn_valid = format_ok & area_ok & group_ok & serial_ok & !is_common_dummy,
    
    # 무효 사유 텍스트(디버깅/리뷰용)
    ssn_invalid_reason = case_when(
      is.na(SSN_clean) | SSN_clean == "" ~ "blank",
      !format_ok                        ~ "format",
      is_common_dummy                   ~ "common_dummy",
      !area_ok                          ~ "area_block",
      !group_ok                         ~ "group_block",
      !serial_ok                        ~ "serial_block",
      TRUE                              ~ NA_character_
    )
  )


clients <- clients %>%
  mutate(ssn_option = if_else(ssn_valid, 1L, 99L))




invalid_ssn_rows <- clients %>%
  filter(!ssn_valid)

invalid_ssn <- invalid_ssn_rows %>%
  select(Last, First, 'Date of Birth', 'Social Security Number', ssn_invalid_reason, ssn_option)

write_xlsx(invalid_ssn, "invalid_ssn.xlsx")           


valid_ssn_rows <- clients %>%
  filter(ssn_valid)

valid_ssn <- valid_ssn_rows %>%
  select(Last, First, 'Date of Birth', 'Social Security Number', ssn_option)

write_xlsx(valid_ssn, "valid_ssn.xlsx")   

clients<- clients %>% 
  mutate(citizen = 106)

colnames(clients)

#####################

library(dplyr)
library(stringr)

clients <- clients %>%
  mutate(
    # 앞뒤 공백 제거 및 중복 공백 정리
    lang_trim = str_squish(str_trim(`Primary Language spoken`)),
    
    # 매핑 규칙 적용 (정확 매칭)
    language = dplyr::recode(
      lang_trim,
      "Arabic"             = 6L,
      "Creole"             = 34L,
      "English"            = 1L,
      "English / Spanish"  = 30L,
      "Gujarati"           = 27L,
      "haitian creole"             = 36L,   # 소문자 버전은 별도 코드
      "Other"              = -1L,
      "Russian"            = 143L,
      "RUSSIAN"            = 143L,
      "Spanish"            = 2L,
      .default = NA_integer_
    ),
    
    # NA를 99로 지정 (빈 문자열도 99로 처리하려면 조건에 lang_trim == "" 포함)
    language = if_else(is.na(language), 99L, language)
  )

