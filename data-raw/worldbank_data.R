# (C) Joachim Gassen 2020, gassen@wiwi.hu-berlin.de, see LICENSE file for details
#
# This code generates the Worldbank dataset.

# The package {wbstats} is currently not available from CRAN so it needs to
# be installed from Github
# remotes::install_github("nset-ornl/wbstats")

library(dplyr)
library(tidyr)
library(wbstats)
library(ExPanDaR)

refresh <- TRUE

pull_worldbank_data <- function() {
  new_cache <- wbcache()
  all_vars <- as.character(unique(new_cache$indicators$indicatorID))
  vars <- c("SP.POP.TOTL", "NY.GDP.MKTP.KD", "NY.GDP.PCAP.KD",
            "DT.DOD.DECT.GN.ZS", "DT.TDS.DPPG.GN.ZS", "NY.GDS.TOTL.ZS",
            "NE.EXP.GNFS.ZS", "NE.IMP.GNFS.ZS", "GB.XPD.RSDV.GD.ZS",
            "SE.XPD.TOTL.GD.ZS", "SH.XPD.CHEX.GD.ZS", "MS.MIL.XPND.GD.ZS",
            "EN.ATM.CO2E.PC", "SL.UEM.TOTL.ZS", "SI.POV.GINI",
            "SE.ADT.LITR.ZS", "SH.DYN.MORT", "SP.DYN.LE00.IN")

  data_wide <- wb(indicator = vars, mrv = 70,
                  return_wide = TRUE, cache = new_cache)

  new_cache$indicators[new_cache$indicators[,"indicatorID"] %in% vars, ] %>%
    rename(var_name = indicatorID) %>%
    mutate(var_def = paste(indicator, "\nNote:", indicatorDesc, "\nSource:", sourceOrg)) %>%
    select(var_name, var_def) -> wb_data_def

  new_cache$countries %>%
    select(iso3c, iso2c, country, capital, long, lat, regionID, region, incomeID, income) -> ctries

  left_join(data_wide, ctries, by = "iso3c") %>%
    filter(!is.na(capital)) %>%
    rename(year = date,
           iso2c = iso2c.y,
           country = country.y) %>%
    select(iso3c, iso2c, country, regionID, region, incomeID, income, everything()) %>%
    select(-iso2c.x, -country.x, -capital, -long, -lat) %>%
    filter(!is.na(NY.GDP.MKTP.KD)) -> wb_data

  wb_data_def<- left_join(data.frame(var_name = names(wb_data), stringsAsFactors = FALSE), wb_data_def)
  wb_data_def$var_def[1:8] <- c("Three letter ISO country code as used by World Bank",
                                "Two letter ISO country code as used by World Bank",
                                "Country name as used by World Bank",
                                "Region ID for World Bank regional country classification",
                                "World Bank regional country classification",
                                "Income ID for World Bank country income group classification",
                                "World Bank country income group classification",
                                "Calendar year of observation")
  wb_data_def$type = c("cs_id", "factor", "cs_id",
                       rep("factor", 4), "ts_id",
                       rep("numeric", ncol(wb_data) - 8))
  wb_data[,1:7] <- lapply(wb_data[,1:7], as.factor)
  wb_data$year <- as.ordered(as.numeric(wb_data$year))
  return(list(wb_data, wb_data_def))
}

if (refresh) {
  wb_list <- pull_worldbank_data()
  worldbank <- wb_list[[1]]
  worldbank_data_def <- wb_list[[2]]
  save(worldbank, file = "data/worldbank.RData", version = 2)
  save(worldbank_data_def, file = "data/worldbank_data_def.RData", version = 2)
} else {
  load("data/worldbank.RData")
  load("data/worldbank_data_def.RData")
}

if (refresh) {
  worldbank_var_def <- read.csv("data-raw/worldbank_var_def.csv", stringsAsFactors = FALSE)
  save(worldbank_var_def, file = "data/worldbank_var_def.RData", version = 2)
} else load("data/worldbank_var_def.RData")

load("data/ExPanD_config_worldbank.RData")
ExPanD(worldbank, df_def = worldbank_data_def, var_def = worldbank_var_def,
       config_list = ExPanD_config_worldbank)
