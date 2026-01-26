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



file_path <- "T:/APRICOT TO CASEWORTHY/1 CLIENTS/Clients - FINAL.xlsx"
#file_path <- "Clients - FINAL.xlsx"
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
    #area_ok   = !is.na(area_n)   & area_n != 0 & area_n != 666 & !(area_n >= 900 & area_n <= 999),
    area_ok   = !is.na(area_n)   & area_n != 0 & area_n != 666,
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
      "Russian"            = 5L,
      "RUSSIAN"            = 5L,
      "Spanish"            = 2L,
      .default = NA_integer_
    ),
    
    # NA를 99로 지정 (빈 문자열도 99로 처리하려면 조건에 lang_trim == "" 포함)
    language = if_else(is.na(language), 99L, language)
  )


###############


# 패키지 로드
library(dplyr)
library(stringr)
# (replace_na를 쓰려면 tidyr도 필요합니다)
library(tidyr)

# 매핑 테이블 (키는 모두 소문자)
race_map <- c(
  "caucasian"               = 0,
  "mixed race"              = -1,
  "asian/pacific islander"  = 2,
  "hispanic"                = 0,
  "african american"        = 3,
  "native american/alaskan" = 1,
  # NA는 별도 처리(아래 mutate에서 99 부여)
  "biracial"                = -1,
  "multiracial"             = -1,
  "arab"                    = -1,
  "yemen"                   = -1,
  "will not say"            = 99,
  "african"                 = 3,
  "multiracial/other"       = -1,
  "black/white"             = -1,
  "egyptian"                = -1,
  "ukrainian"               = -1,
  "middle eastern"          = -1
)

# race1 생성
clients <- clients %>%
  mutate(
    # 전처리: 모두 소문자, 앞뒤/중복 공백 제거
    race_clean = str_squish(str_to_lower(Race)),
    # 매핑 적용 (벡터 인덱싱)
    race1 = unname(race_map[race_clean]),
    # 원본이 NA면 99
    race1 = ifelse(is.na(Race), 99L, race1)
    # 매핑에 없는 값 기본 처리:
    # 필요 시 다음 줄을 활성화하여 매핑 안 된 값도 -1로 통일
    # race1 = replace_na(race1, -1L)
  )

# 확인용
table(clients$Race, useNA = "ifany")
table(clients$race1, useNA = "ifany")

# 매핑되지 않은 값(NA로 남은 값) 점검
clients %>%
  filter(is.na(race1) & !is.na(Race)) %>%
  count(Race, sort = TRUE)



###########


library(dplyr)
library(stringr)

# 안전 전처리: Hispanic?를 소문자 + 공백 정리
clients <- clients %>%
  mutate(
    hisp_clean = case_when(
      is.na(`Hispanic?`) ~ NA_character_,
      TRUE ~ str_squish(str_to_lower(`Hispanic?`))
    ),
    # race_clean이 없으면 만들어 둠 (있으면 그대로 사용)
    race_clean = if (!"race_clean" %in% names(.)) {
      str_squish(str_to_lower(Race))
    } else {
      race_clean
    }
  ) %>%
  mutate(
    # 기본값: race1을 그대로 복사
    race2 = race1,
    # Caucasian / Hispanic만 덮어쓰기
    race2 = ifelse(
      race_clean %in% c("caucasian", "hispanic"),
      case_when(
        is.na(`Hispanic?`)      ~ 5L,       # NA → 5
        hisp_clean == "yes"     ~ 5L,       # YES → 5
        hisp_clean == "no"      ~ -1L,      # NO → -1
        TRUE                    ~ -1L       # (기타 값이 있으면 -1로 처리)
      ),
      race2                     # 다른 인종은 race1 유지
    )
  )



# 변경 대상만 확인
clients %>%
  filter(race_clean %in% c("caucasian", "hispanic")) %>%
  count(`Hispanic?`, race2, sort = TRUE)

# 전체 분포 확인
table(clients$race2, useNA = "ifany")
View(clients %>% select(Race,`Hispanic?` , race2))
#################################

clients$Zip[is.na(clients$Zip)] <- 99999
sum(is.na(clients$Zip))
clients$Zip <- sub("-.*", "", clients$Zip)


view(clients$`Primary Phone Number`)



# 1) 끝에 ".숫자"가 붙은 경우 제거 (예: "574.612.7242.670" → "574.612.7242")
clients$`Primary Phone Number` <- sub("\\.[0-9]+$", "", clients$`Primary Phone Number`)



# 2) 끝의 점(.)만 남아 있으면 제거 (예: "574.612.7242." → "574.612.7242")
clients$`Primary Phone Number` <- sub("\\.$", "", clients$`Primary Phone Number`)


# 3) 점을 하이픈으로 변경 (예: "574.612.7242" → "574-612-7242")
clients$`Primary Phone Number` <- gsub("\\.", "-", clients$`Primary Phone Number`)


# 4) 값이 점만으로 이루어진 경우("...", ".", ".." 등) → 111-111-1111
clients$`Primary Phone Number`[grepl("^\\.*$", clients$`Primary Phone Number`)] <- "111-111-1111"

# 5) 연속 하이픈("--")이 포함되어 있으면 → 111-111-1111
clients$`Primary Phone Number`[grepl("--", clients$`Primary Phone Number`)] <- "111-111-1111"







clients$`Social Security Number`[
  grepl("--", clients$`Social Security Number`)
] <- "000-00-0000"


clients %>% filter(ssn_option == 99)



clients$blank <- NA
clients$blank1 <- NA
clients$blank2 <- NA
clients$blank3 <- NA
clients$blank4 <- NA
clients$one <- 1

clients_selected <- clients %>% 
  select(Last, First,gender,'Social Security Number',
                                      ssn_option,dob,dobqo,prounouns,race2,
                                      ethnicity,citizen,language,veteran,
                                      address,Line2,Zip,rural,country,blank,
                                      okphone,oktext,okemail,
                                      'Primary Phone Number',one,blank1,blank2,
         blank3,blank4 ,Email,
                                      scid,sharing)

clients_selected$SSN_raw1 <- clients$`Social Security Number`



clients_selected <- clients_selected %>%
  mutate('Social Security Number' = as.character('Social Security Number')) %>%
  mutate('Social Security Number' = if_else(ssn_option == 99, "", SSN_raw1))




view(clients_selected %>% filter(ssn_option==99))




write_xlsx(clients_selected, "clients_selected.xlsx")






#################

# 10개 랜덤 행 선택
set.seed(123)  # 재현 가능성을 위해 시드 설정 (원하면 제거 가능)
sample_rows <- clients_selected[sample(nrow(clients_selected), 10), ]

# 확인
sample_rows
write_xlsx(sample_rows, "sample_rows.xlsx")

########################fix



clients_selected %>%
  filter(Last == "Rodriguez de la Rosa") %>%
  pull(address, Zip)




clients_selected <- clients_selected %>%
  mutate(Zip = if_else(Last == "Rodriguez de la Rosa", "46526", Zip))



clients_selected %>%
  filter(Last == "Gonzalez Zuniga") %>%
  pull(address, Zip)

clients_selected <- clients_selected %>%
  mutate(Zip = if_else(Last == "Gonzalez Zuniga", "46550", Zip))


clients_selected %>%
  filter(Last == "Cass") %>%
  pull(address, Zip)

clients_selected <- clients_selected %>%
  mutate(Zip = if_else(Last == "Cass", "46507", Zip))


clients_selected %>%
  filter(Last == "Maax") %>%
  pull(address, Zip)

clients_selected <- clients_selected %>%
  mutate(Zip = if_else(Last == "Maax", "46507", Zip))


clients_selected %>%
  filter(Last == "Peel") %>%
  pull(address, Zip)

clients_selected <- clients_selected %>%
  mutate(Zip = if_else(Last == "Peel", "46550", Zip))

clients_selected %>%
  filter(Last == "Rios-Delacruz") %>%
  pull(address, Zip)

clients_selected <- clients_selected %>%
  mutate(Zip = if_else(Last == "Rios-Delacruz", "46746", Zip))

clients_selected %>%
  filter(Last == "Daniels" & First == "Samiah") %>%
  pull(address, Zip)

clients_selected <- clients_selected %>%
  mutate(Zip = if_else(Last == "Daniels" & First == "Samiah", "46526", Zip))


write_xlsx(clients_selected, "clients_selected.xlsx")
