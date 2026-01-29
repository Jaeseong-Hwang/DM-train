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
#View(clients %>% select(Race,`Hispanic?` , race2))
#################################

clients$Zip[is.na(clients$Zip)] <- 99999
sum(is.na(clients$Zip))
clients$Zip <- sub("-.*", "", clients$Zip)


#view(clients$`Primary Phone Number`)



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


clients <- clients %>%
  mutate(ridst = if_else(`Current Status` == "Active", 1L, 2L))

#############Rid 가공
#1 6으로 시작작
nrow(clients %>% 
  filter(str_starts(str_trim(as.character(`RID NUMBER`)), "6") &
           str_length(str_trim(as.character(`RID NUMBER`))) < 15))

####그대로 6으로 시작하는 것 blank, length 15 이하하, ridn1

clients <- clients %>%
  mutate(
    # 길이 판단은 앞뒤 공백이 섞여 있어도 정확히 하도록 trim해서 검사
    ridn1 = if_else(
      str_starts(str_trim(as.character(`RID NUMBER`)), "6") &
        str_length(str_trim(as.character(`RID NUMBER`))) < 15,
      "",  # 6으로 시작 + 길이<15 → blank
      as.character(`RID NUMBER`)  # 나머지는 원래 값 그대로
    )
  )

#####6으로 시작하는 것 15이상 ridn2



clients <- clients %>%
  mutate(
    ridn1_chr  = as.character(ridn1),                      # 안전한 문자형 변환
    ridn1_trim = str_squish(ridn1_chr),                    # 길이 판단만 공백/여분 문자 정리
    # 마지막에 등장하는 '1'로 시작하는 숫자를 캡처 (그리디 매칭으로 마지막 '1...'을 잡음)
    last_one   = str_match(ridn1_trim, ".*\\b(1\\d+)\\b.*")[, 2],
    
    ridn2 = if_else(
      str_starts(ridn1_trim, "6") &                        # 6으로 시작하고
        str_length(ridn1_trim) >= 15 &                     # 길이가 15 이상이며
        !is.na(last_one),                                  # 뒤에 '1'로 시작하는 숫자가 존재하면
      last_one,                                            # 그 숫자를 ridn2로
      ridn1_chr                                            # 아니면 원래 ridn1 그대로
    )
  )

nrow(clients %>% filter(str_starts(ridn2, "6")))     #check


############################################################ridn3 12digit

test_ridn3 <- clients %>%
  filter(
    !str_detect(str_replace_na(ridn2, ""), "\\b\\d{12}\\b")
  ) %>% select(`RID NUMBER`, ridn2)


#write_xlsx(test_ridn3, "test_ridn3.xlsx")


clients <- clients %>%
  mutate(
    ridn2_chr = as.character(ridn2),                 # 안전한 문자형 변환
    has_12dig = grepl("\\d{12}", ridn2_chr),         # 12자리 숫자 포함 여부 (연속된 12자리)
    ridn3     = if_else(has_12dig, ridn2_chr, "")    # 포함하면 그대로, 아니면 blank
  ) %>% select(-ridn2_chr, -has_12dig)

test_clients <- clients %>% select(ridn3)


write_xlsx(test_clients, "test_clients.xlsx")



#########################################100177820699 //  1081245878  ridn4
clients %>%
  filter(
    grepl("\\b\\d{12}\\b\\s*[/\\\\]", as.character(ridn3)))
    

clients <- clients %>%
  mutate(
    ridn3_chr = as.character(ridn3),  # factor 안전 변환
    # 슬래시(/ 또는 \) 바로 앞의 정확히 12자리 숫자만 캡처 (없으면 NA)
    left12    = ifelse(
      grepl("\\b\\d{12}\\b\\s*[/\\\\]", ridn3_chr),
      sub(".*\\b(\\d{12})\\b\\s*[/\\\\].*", "\\1", ridn3_chr),
      NA_character_
    ),
    ridn4     = if_else(!is.na(left12), left12, ridn3_chr)  # 있으면 추출숫자, 없으면 원본
  ) %>%
  select(-ridn3_chr, -left12)  # 중간 컬럼 정리


test_clients <- clients %>% select(ridn4) %>% filter(ridn4 != "")


write_xlsx(test_clients, "test_clients.xlsx")



clients <- clients %>%
  mutate(
    ridn4 = str_to_lower(as.character(ridn4))
  )

#View(clients %>% filter(ridn4 == "") %>% select(`Current Status`,ridn4, `RID NUMBER`))

##########

clients <- clients %>%
  mutate(
    rids1 = if_else(trimws(as.character(ridn4)) == "", 2L, 1L))
    


clients <- clients %>%
  mutate(
    ridn4_chr = as.character(ridn4),
    ridn4_low = str_to_lower(ridn4_chr),
    
    # 지정 패턴 포함 여부 (대소문자 무시, NA 안전)
    flag_pat = !is.na(ridn4_low) & (
      str_detect(ridn4_low, "not\\s*active") |  # 'not active'
        str_detect(ridn4_low, "nya")           |  # 'nya'
        str_detect(ridn4_low, "ne\\s")         |  # 'ne ' (뒤에 공백)
        str_detect(ridn4_low, "not\\s*elig\\s")|  # 'not elig ' (뒤에 공백)
        str_detect(ridn4_low, "na\\s")            # 'na ' (뒤에 공백)
    ),
    
    # ✅ rids2: 패턴 포함이면 2, 아니면 rids1 그대로
    rids2 = if_else(flag_pat, 2L, rids1),
    
    # 12-digit 숫자 추출 (첫 번째 매치만)
    ridn4_12 = str_extract(ridn4_chr, "\\d{12}"),
    
    # ✅ ridn5: 패턴 포함이면 12-digit 저장, 아니면 ridn4 원래 값 유지
    ridn5 = if_else(flag_pat & !is.na(ridn4_12), ridn4_12, ridn4_chr)
  )
  



test_clients <- clients %>% select(ridn4, ridn5, `Current Status`, rids1, rids2)


write_xlsx(test_clients, "test_clients.xlsx")


###########
clients$ridn5[220] <- "121654279399"

which(clients$ridn5 == "106504190599, active rid is 121349206499")
clients$ridn5[3312] <- "121349206499"

##################

clients <- clients %>%
mutate(
  ridn5_chr = as.character(ridn5),                          # 안전한 문자형 변환
  ridn5_low = str_to_lower(str_replace_na(ridn5_chr, "")),  # 소문자 + NA 안전
  ridn5_12  = str_extract(ridn5_chr, "\\d{12}"),            # 첫 번째 12자리 숫자 추출
  ridn6     = if_else(
    str_detect(ridn5_low, "active") & !is.na(ridn5_12),     # active 포함 + 12digit 존재
    ridn5_12,                                               # → 12digit 저장
    ridn5_chr                                               # → 나머지는 ridn5 그대로
  )
) %>% select(-ridn5_12, -ridn5_chr, ridn5_chr)
  

test_clients <- clients %>% select(`RID NUMBER`, ridn6, `Current Status`, rids1, rids2)


write_xlsx(test_clients, "test_clients.xlsx")


which(clients$ridn6 == "07-06-2024  not eligible - presumptive rid - 600010210956") 
clients$ridn6[3457] <- ""
clients$rids2[3457] <- 2

which(clients$ridn6 == "121882352299 ne")

clients$ridn6[380] <- 121882352299
clients$rids2[380] <- 2

####################################################

# 원본을 문자형으로 안전 변환 (factor 등 방지)
ridn6_chr <- as.character(clients$ridn6)

# " not eligible" 또는 "-na" 포함 여부 (대소문자 무시, NA는 FALSE로 처리)
flag <- !is.na(ridn6_chr) & str_detect(ridn6_chr, regex("not eligible|-na", ignore_case = TRUE))

# 해당 행의 12자리 숫자만 추출 (여러 개 있으면 첫 매치만)
digits12 <- ifelse(flag, str_extract(ridn6_chr, "\\b\\d{12}\\b"), NA_character_)

# ridn7: 조건 충족 시 12자리 숫자, 그렇지 않으면 원래 ridn6 유지
clients$ridn7 <- ifelse(flag, digits12, ridn6_chr)

# rids3: 조건 충족 시 2, 그 외에는 rids2 값을 그대로
clients$rids3 <- ifelse(flag, 2L, clients$rids2)

test_clients <- clients %>% select(ridn7, `Current Status`, ridn6, rids3) %>% filter(ridn7 != "")


write_xlsx(test_clients, "test_clients1.xlsx")



which(clients$ridn6 == "120108194899    older child yoshou you - rid - 120108179999") 
clients$ridn7[1973] <- 120108194899


which(clients$ridn6 == "121508178599    son dustin - rid - rid 121508179399") 
clients$ridn7[3007] <- 121508178599

which(clients$ridn6 == "102613886599  elig under 121063852299") 
clients$ridn7[2350] <- 121063852299


which(clients$ridn6 == "121459475499 and 120964388999") 
clients$ridn7[3015] <- 121459475499



test_clients <- clients %>% select(ridn7, `Current Status`, ridn6, rids3) %>% filter(ridn7 != "")


write_xlsx(test_clients, "test_clients.xlsx")


which(clients$ridn7 == "denied - will need reapp 121833291299") 
clients$ridn7[154] <- "121833291299"
clients$rids3[154] <- 2


which(clients$ridn7 == "07-29-2024 denied -104398511699") 
clients$ridn7[3598] <- "104398511699"
clients$rids3[3598] <- 2



which(clients$ridn7 == "denied 121842633499") 
clients$ridn7[3656] <- "121842633499"
clients$rids3[3656] <- 2


test_clients <- clients %>% select(ridn7, `Current Status`, ridn6, rids3) %>% filter(ridn7 != "")


write_xlsx(test_clients, "test_clients.xlsx")

##################




clients <- clients %>%
  mutate(
    ridn7_chr = as.character(ridn7),
    long_flag = !is.na(ridn7_chr) & nchar(ridn7_chr) > 18,
    digits12 = str_extract(ridn7_chr, "\\b\\d{12}\\b"),
    ridn8 = if_else(long_flag, digits12, ridn7_chr, missing = ridn7_chr)
  ) %>%
  select(-ridn7_chr, -long_flag, -digits12)



test_clients <- clients %>% select(ridn8, rids3) %>% filter(ridn8 != "")


write_xlsx(test_clients, "test_clients.xlsx")




clients <- clients %>%
  mutate(
    ridn8_chr = as.character(ridn8),
    ridn7_chr = as.character(ridn7),
    flag_long12 = !is.na(ridn8_chr) & nchar(ridn8_chr) > 12,
    ridn9 = if_else(flag_long12, "", ridn7_chr),
    rids4 = if_else(flag_long12, 2L, rids3)
  ) %>% select(-ridn8_chr,-ridn7_chr,-flag_long12)
  
# 
# 
# 
# 
# 
# ##########
# 
# 
# 
# 
# 
# test_clients <- clients %>% select(`RID NUMBER`, ridn6, rids2)
# 
# 
# write_xlsx(test_clients, "test_clients.xlsx")
# 
# 
# 
# 
# 
# ##################################################################################################################
# 
# ##############"not found" 또는 "none found" ridn3
# 
# nrow(
#   clients %>%
#     filter(
#       str_detect(str_to_lower(ridn2), "not\\s*found") |
#         str_detect(str_to_lower(ridn2), "none\\s*found")
#     ))
# 
# 
# 
# clients <- clients %>%
#   mutate(
#     ridn2_chr = tolower(as.character(ridn2)),           # 소문자로 변환
#     ridn3 = if_else(
#       !is.na(ridn2_chr) &
#         (grepl("not\\s*found", ridn2_chr) | 
#            grepl("none\\s*found", ridn2_chr)),
#       "",
#       ridn2_chr
#     )
#   )
# 
# #check
# nrow(
#   clients %>%
#     filter(
#       str_detect(str_to_lower(ridn3), "not\\s*found") |
#         str_detect(str_to_lower(ridn3), "none\\s*found")
#     )) 
# 
# ##100177820699 //  1081245878 관리
# 
# 
# 
# clients %>%
#   filter(str_detect(ridn3, "\\b\\d{12}\\b\\s*[/\\\\]"))
# 
# 
# 
# clients <- clients %>%
#   mutate(
#     ridn3_chr = as.character(ridn3),  # factor 안전 변환
#     # 슬래시(/ 또는 \) 바로 앞의 정확히 12자리 숫자만 추출 (없으면 NA)
#     left12    = str_extract(ridn3_chr, "\\b\\d{12}\\b(?=\\s*[/\\\\])"),
#     # 12자리 숫자가 있으면 그 값으로, 없으면 ridn3 원본 유지
#     ridn4     = if_else(!is.na(left12), left12, ridn3_chr)
#   ) %>%
#   select(-ridn3_chr, -left12)
# 
# clients %>%
#   filter(str_detect(ridn4, "\\b\\d{12}\\b\\s*[/\\\\]"))
# 
# 
# 
# #########1. length 12보다 작은것,  2. 12디짓 넘버 포함하지 않은 것, 3. nya포함한것 
# 
# 
# nrow(
#   clients %>%
#     filter(
#       # 1) 길이 < 12 (앞뒤 공백 제거 후 길이 기준)
#       nchar(trimws(as.character(ridn4))) < 12 |
#         # 2) 12자리 숫자를 포함하지 않음
#         !grepl("\\b\\d{12}\\b", as.character(ridn4)) |
#         # 3) 'nya' 포함 (대소문자 무시)
#         grepl("nya", tolower(as.character(ridn4)))
#     ))
# 
# 
# 
# 
# clients <- clients %>%
#   mutate(
#     ridn5 = if_else(
#       nchar(trimws(as.character(ridn4))) < 12 |                          # 1) 길이 < 12
#         !grepl("\\b\\d{12}\\b", as.character(ridn4)) |                     # 2) 12자리 숫자 미포함
#         grepl("nya", tolower(as.character(ridn4))),                        # 3) 'nya' 포함 (대소문자 무시)
#       "",
#       as.character(ridn4)
#     )
#   )
# 
# 
# 
# 
# 
# 
# nrow(
#   clients %>%
#     filter(
#       # 1) 길이 < 12 (앞뒤 공백 제거 후 길이 기준)
#       nchar(trimws(as.character(ridn5))) < 12 |
#         # 2) 12자리 숫자를 포함하지 않음
#         !grepl("\\b\\d{12}\\b", as.character(ridn5)) |
#         # 3) 'nya' 포함 (대소문자 무시)
#         grepl("nya", tolower(as.character(ridn5)))
#     ))
# 
# 
# ########################### "-na", "na ", "ne ", "not active", "not eligible" 포함 row 추출
# 
# 
# clients %>%
#   filter(
#     str_detect(str_to_lower(ridn5), "-na") |
#       str_detect(str_to_lower(ridn5), "na\\s") |
#       str_detect(str_to_lower(ridn5), "ne\\s") |
#       str_detect(str_to_lower(ridn5), "not active") |
#       str_detect(str_to_lower(ridn5), "not elig") |
#       str_detect(str_to_lower(ridn5), "not eligible")
#   )
# 
# 
# clients <- clients %>%
#   mutate(
#     ridn5_chr = as.character(ridn5),              # factor 안전 변환
#     ridn5_low = str_to_lower(ridn5_chr),          # 소문자화
#     flag_bad  = !is.na(ridn5_low) &               # NA 보호
#       str_detect(
#         ridn5_low,
#         "-na|na\\s|ne\\s|not\\s+active|not\\s+eligible|not\\s+elig"
#       ),
#     ridn6     = if_else(flag_bad, "", ridn5_chr)  # 조건이면 blank, 아니면 원래 값
#   ) %>%
#   select(-ridn5_chr, -ridn5_low, -flag_bad)  
# 
# 
# 
# 
# 
# 
# 
# 
# 
# 
# 
# 
# 
# 





########################################################################################

clients_selected <- clients %>% 
  select(Last, First,gender,'Social Security Number',
                                      ssn_option,dob,dobqo,prounouns,race2,
                                      ethnicity,citizen,language,veteran,
                                      address,Line2,Zip,rural,country,blank,
                                      okphone,oktext,okemail,
                                      'Primary Phone Number',one,blank1,blank2,
         blank3,blank4 ,Email,
                                      scid,ridn9, rids4, sharing)

clients_selected$SSN_raw1 <- clients$`Social Security Number`



clients_selected <- clients_selected %>%
  mutate('Social Security Number' = as.character('Social Security Number')) %>%
  mutate('Social Security Number' = if_else(ssn_option == 99, "", SSN_raw1))




#view(clients_selected %>% filter(ssn_option==99))




#write_xlsx(clients_selected, "clients_selected.xlsx")






#################

# 10개 랜덤 행 선택
set.seed(123)  # 재현 가능성을 위해 시드 설정 (원하면 제거 가능)
sample_rows <- clients_selected[sample(nrow(clients_selected), 10), ]

# 확인
sample_rows
#write_xlsx(sample_rows, "sample_rows.xlsx")

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
