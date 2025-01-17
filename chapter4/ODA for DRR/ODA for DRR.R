required.packages <- c("data.table", "readxl")
lapply(required.packages, require, character.only = T)

setwd("G:/My Drive/Work/GitHub/gha_report_2021/")

load_crs <- function(dataname="crs", path="project_data"){
  require("data.table")
  files.bz <- list.files(path, pattern=paste0(dataname, "_part.+[.]bz"))
  files.csv <- list.files(path, pattern=paste0(dataname, "_part.+[.]csv"))
  if(length(files.bz) > 0 & length(files.csv) > 0){
    files <- files.csv
    read.crs <- function(x){return(fread(x))}
  } else {
    if(length(files.bz) > 0){
      files <- files.bz
      read.crs <- function(x){return(read.csv(x))}
    } else {
      files <- files.csv
      read.crs <- function(x){return(fread(x))}
    }
  }
  crs <- list()
  for(i in 1:length(files)){
    print(paste0("Loading part ", i, " of ", length(files)))
    filepath <- paste0(path, "/", files[i])
    crs[[i]] <- read.crs(filepath)
  }
  crs <- rbindlist(crs)
  return(crs)
}

crs <- load_crs(path = "datasets/CRS/")

keep <- c(
  "CrsID",
  "Year",
  "FlowName",
  "DonorName",
  "RecipientName",
  "USD_Disbursement_Defl",
  "PurposeName",
  "ProjectTitle",
  "ShortDescription",
  "LongDescription",
  "DRR"
)

crs <- crs[, ..keep]
crs <- crs[
  FlowName == "ODA Loans" 
  |
    FlowName == "ODA Grants"
  | 
    FlowName == "Equity Investment"
  | 
    FlowName == "Private Development Finance"
  ]

crs <- crs[Year >= 2018]

major.keywords <- c(
  "anti-seismic adaption",
  "cbdrm",
  "climate protection",
  "climate resilience",
  "climate vulnerability",
  "coastal protection",
  "cyclone preparedness",
  "disaster management",
  "disaster reduction",
  "disaster resilience",
  "disaster risk mitigation",
  "disaster risk reduction",
  "disaster vulnerability reduction",
  "disaster risk management",
  "drm",
  "drr",
  "early warning",
  "earthquake-resistant",
  "earthquake resistant",
  "earthquake resistance",
  "embankment",
  "flood control",
  "flood mitigation plan",
  "flood prevention",
  "flood protection",
  "flood risk management",
  "fpi",
  "gfdrr",
  "hyogo framework of action",
  "lutte contre les inondations",
  "r�duction des risques de catastrophes",
  "resilience to disasters",
  "resilience to natural",
  "resilience to shock",
  "shock resilience",
  "storm warning",
  "vulnerability and capacity assessment",
  "disaster risk assessment",
  "multi-hazard risk mapping",
  "resilient infrastructure",
  "disaster insurance",
  "disaster risk insurance",
  "disaster risk analysis",
  "flood risk",
  "resilience to earthquakes",
  "seismically safe standards",
  "disaster preparedness plan",
  "disaster preparedness policy",
  "disaster preparedness",
  "disaster resistant construction",
  "disaster resilient building",
  "vulnerability to natural hazards",
  "disaster-resilient",
  "forest fire prevention",
  "hazard monitoring",
  "katastrophenvorsorge",
  "vorhersagebasiert",
  "fr�hwarnsystem",
  "klimaanpassung",
  "katastrophenrisik",
  "katastrophenvorbeugung",
  "evakuierungsplan",
  "r�duction des risques de catastrophe",
  "changement climatique",
  "r�silience climatique",
  "pr�paration aux catastrophes",
  "pr�vention des catastrophes",
  "r�sistante aux catastrophes",
  "cadre de sendai",
  "r�silience aux risques naturels",
  "vuln�rabilit� aux risques naturels",
  "construction r�sistantes aux catastrophes",
  "alerte pr�coce",
  "preparaci�n y prevenci�n desastre",
  "prevenci�n y preparaci�n en caso de desastre",
  "cambio clim�tico",
  "resiliencia a amenazas naturales",
  "reducci�n del riesgo de desastres",
  "resiliencia a los desastres",
  "vulnerabilidad frente a los desastres",
  "marco de sendai",
  "variabilidad clim�tica",
  "risk financing",
  "sendai framework"
)

#minor.keywords <- c(
  #"keyword"

 #)

disqualifying.keywords <- c(
"serendipity"
)

disqualifying.sectors <- c(
  #"Disaster Risk Reduction"
  
)

crs$relevance <- "None"
crs[grepl(paste(major.keywords, collapse = "|"), tolower(crs$LongDescription))]$relevance <- "Minor"
crs[grepl(paste(major.keywords, collapse = "|"), tolower(paste(crs$ShortDescription, crs$ProjectTitle)))]$relevance <- "Major"

crs$check <- "No"
crs[relevance == "Minor"]$check <- "potential false positive"
crs[relevance != "None"][PurposeName %in% disqualifying.sectors]$check <- "potential false negative"
crs[relevance != "None"][grepl(paste(disqualifying.keywords, collapse = "|"), tolower(paste(crs[relevance != "None"]$ProjectTitle, crs[relevance != "None"]$ShortDescription, crs[relevance != "None"]$LongDescription)))]$check <- "potential false negative"

crs[relevance != "None"][grepl(paste(disqualifying.keywords, collapse = "|"), tolower(paste(crs[relevance != "None"]$ProjectTitle, crs[relevance != "None"]$ShortDescription, crs[relevance != "None"]$LongDescription)))]$relevance <- "None"
crs[relevance != "None"][PurposeName %in% disqualifying.sectors]$relevance <- "None"

crs$DRR <- as.character(crs$DRR)
crs[is.na(DRR)]$DRR <- "0"
crs[DRR != "1" & DRR != "2"]$DRR <- "No DRR component"
crs[DRR == "1"]$DRR <- "Minor DRR component"
crs[DRR == "2"]$DRR <- "Major DRR component"

crs[, Primary_DRR := ifelse(relevance == "Major" | DRR == "Major DRR component" | PurposeName == "Disaster Risk Reduction", "Primary", NA_character_)]

inform <- data.table(read_excel("datasets/INFORM/INFORM2021_TREND_2011_2020_v051_ALL.xlsx"))
inform <- inform[IndicatorName == "Natural Hazard" & INFORMYear == 2021]

countrynames <- fread("datasets/Countrynames/isos.csv", encoding = "UTF-8")
crs <- merge(countrynames[,c("iso3", "countryname_oecd")], crs, by.x = "countryname_oecd", by.y = "RecipientName", all.y = T)
crs <- merge(crs, inform[,c("Iso3", "IndicatorScore")], by.x = "iso3", by.y = "Iso3", all.x = T)
crs[, hazard_class := ifelse(IndicatorScore >= 6.9, "Very High", ifelse(IndicatorScore >= 4.7, "High", ifelse(IndicatorScore >= 2.8, "Medium", "Low")))]

crs_total <- crs[, .(drr_oda = sum(USD_Disbursement_Defl[Primary_DRR == "Primary"], na.rm = T), total_oda = sum(USD_Disbursement_Defl, na.rm = T)), by = .(Year, iso3, hazard_class, IndicatorScore)]

crs_drr <- crs[!is.na(USD_Disbursement_Defl) & ((relevance != "None" & check == "No") | DRR != "No DRR component" | PurposeName == "Disaster Risk Reduction")]
crs_drr[, drr_score := ifelse(relevance == "Major" | DRR == "Major DRR component" | PurposeName == "Disaster Risk Reduction", "Major", "Minor")]

fwrite(crs_total, "chapter4/ODA for DRR/crs_total.csv")
fwrite(crs_drr, "chapter4/ODA for DRR/crs_ddr.csv")
