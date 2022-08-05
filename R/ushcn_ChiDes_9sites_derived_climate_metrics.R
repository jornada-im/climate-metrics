############################################################################
#                EDI Fellowship : Jornada Basin LTER Project               #
#                             by: Bri Hernandez                            #
#                                                                          #
#   Derive SPEI and scpdsi metrics from the USHCN data of the Chihuahuan   #
#   Desert. Drought indices will be compared. Focus on the JER, SOCORRO,   #   
#   EL PASO, LOS LUNAS, GAGE, STATE UNIV, ELEPHANT BUTTE DAM, TULAROSA,    #
#   OROGRANDE                                                              #
#                                                                          #
#                                                                          #
############################################################################

library('tidyverse')
library(dplyr)
library(ggplot2)
library(SPEI)
library(tidyr)
library(gtools)

# Get spei tools, if not already installed use:
# devtools::install_github("gremau/rclimtools")
# Then load
# library('rclimtools')

# Get the dataset
fname <- './ChihuahuanDesert_USHCN_dataset.csv'   # data set has all 9 sites    
raw <- read_csv(fname, na=c('', 'NaN', 'NA'))

head(raw)
tail(raw)


stn <- unique(raw$stationid)
stn

for (i in 1:length(stn)) {
  # Subset the main dataset and calculate PET
  stndf <- subset(raw, stationid==stn[i] & date > '1910-12-31') # For cross-raw, limit to 1999 forward
  tavg <- subset(stndf, variable=='tavg')
  prcp <- subset(stndf, variable=='prcp')
  pet <- SPEI::thornthwaite(tavg$value, unique(tavg$latitude))
  # Prepare datetime index
  tavg$month <- lubridate::month(tavg$date)
  dateidx <- zoo::as.yearmon(paste(tavg$month, '/', tavg$year, sep=''), "%m/%Y")
  # Precip and PET timeseries
  prcp_xts <- xts::xts(prcp$value, order.by=dateidx)
  pet_xts <- xts::xts(as.numeric(pet), order.by=dateidx)
  # Climatic water differential
  cwdiff <- get_cwdiff(prcp_xts, pet_xts)
  
  # Now get 1year SPEI and extract values
  spei_12mo <- get_spei(cwdiff, int_per=12)  
  spei_xts <- xts::xts(as.vector(spei_12mo$fitted),  order.by=zoo::index(cwdiff))
  colnames(spei_xts) <- c('spei12mo')
  
  # Create a new dataframe (from tavg) and add SPEI values
  spei_raw <- tavg
  spei_raw$variable <- 'spei12mo'
  spei_raw$value <- as.vector(spei_xts$spei12mo)
  spei_raw['spei_date'] <- zoo::index(spei_xts)
  
  
  # Concatenate spei_raw dataframes into 1
  if (i==1) {
    spei_out <- spei_raw
  } else {
    spei_out <- rbind(spei_out, spei_raw)
  }
}

spei_out <-arrange(spei_out, station_name) %>% 
  rename(spei_12mo = value)
spei_out

### Prep to calculate scPDSI ###

# Pull prcp and tavg from original csv [raw] to calculate sc-PDSI by using the
# Pivot_wider function from dyplr library 

raw.wid <- pivot_wider (raw, names_from=variable, values_from = value)
raw.wid

raw.df <- (subset(raw.wid, date > '1910-12-31')) %>% 
  arrange(station_name)
raw.df

# Combine spei_out data frame with raw data frame 
combine.df <-spei_out %>% 
  left_join(y=raw.df, by=c("stationid", "date", "station_name", "latitude"))
combine.df

# Get PET using the spei::thornthwaite method
# Split the data frame by station_name to run PET for different latitudes 

dat.pet <- split(combine.df, combine.df$station_name)
dat.pet

# Use lapply() to run PET for the different stations 

pet.app <- lapply(dat.pet, function(x) thornthwaite(x$tavg, x$latitude[1]))

pet.app$`TULAROSA`  # Check the TULAROSA site and compare to PET from spei for loop 

# Make into a single data frame 
pet.sp <- as.data.frame(pet.app)
pet.sp

# Rename the columns to station_names
pet.tho <- pet.sp %>% 
  rename("EL PASO AP"="PET_tho", 
         "ELEPHANT BUTTE DAM"="PET_tho.1",
         "GAGE"="PET_tho.2",
         "JORNADA EXP RANGE"="PET_tho.3",
         "LOS LUNAS 3 SWW"="PET_tho.4",
         "OROGRANDE"="PET_tho.5",
         "SOCORRO"="PET_tho.6",
         "STATE UNIV"="PET_tho.7",
         "TULAROSA"="PET_tho.8")

# Make into long format 
pet.long <- pet.tho %>% 
  pivot_longer(cols=c("EL PASO AP":"TULAROSA"), 
               names_to="station_name", 
               values_to="pet_tho")

pet.long

# Reorder rows using arrange() 
pet.df <- arrange(pet.long, station_name)
pet.df

# Add PET to original data frame with tavg and prcp by using station_name
dat.fin <- bind_cols(combine.df, pet.df)

dat.fin

#### Calculating scPDSI ####

# Package needed to calculate sc-PDSI 
# Package obtained from CRAN archive: 
# https://cran.r-project.org/src/contrib/Archive/scPDSI/
# scPDSI package information:
# https://cran.microsoft.com/snapshot/2020-04-20/web/packages/scPDSI/index.html

library(scPDSI)

pdsi <- pdsi(dat.fin$prcp, dat.fin$pet_tho, start = 1911, sc = TRUE )
summary(pdsi)

# Make dataframe of x values 
sc_pdsi <- data.frame(pdsi$X)
sc_pdsi

# Combine scPDSI data frame to dat.fin data frame 
combine.df2 <- cbind(dat.fin, sc_pdsi) %>% 
  rename(sc_pdsi=pdsi.X, 
         station_name=station_name...8)

# Final data frame with date, stationid, station_name, latitude, prcp, pet_tho, spei_12mo, sc_pdsi
colnames(combine.df2)
final.df <- combine.df2[,c(2,1,8,9,15,17,7,18)]

write_csv(final.df, '../chihuahuandesert_derived_climate_metrics_1911_2021.csv')



#plot SPEI and PDSI 
library(ggpubr)

ggplot(final.df, aes(x=date))+
  geom_line( aes(y = spei_12mo), color = "blue") +
  geom_line( aes( y = sc_pdsi), color = "red") 

#plot psei and pdsi separately 

spei.plot <-ggplot(final.df, aes(x=date))+
  geom_line( aes(y= spei_12mo), color = "blue", xlab="")+
  theme_classic()
spei.plot

pdsi.plot <- ggplot(final.df, aes(x=date))+
  geom_line( aes(y= sc_pdsi), color = "red")+
  theme_classic()
pdsi.plot

ggarrange(spei.plot, pdsi.plot, 
          labels=c("a.","b."),
          ncol=1, nrow=2, 
          common.legend = TRUE, font.label = list(size = 10))




