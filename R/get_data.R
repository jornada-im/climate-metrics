library(EDIutils)
library(readr)

# Get revisions and load latest data entity
from_edi <- function(pkgid, rrev, scope='knb-lter-jrn', skip=0){
    revs <- list_data_package_revisions(scope, pkgid)
    revnum <- revs[length(revs) + rrev]
    report <- read_data_package(paste(scope, pkgid, revnum, sep='.'))
    data_ents <- report[grepl('/data/', report)]
    if(length(data_ents) < 2){
        df <- read_csv(data_ents, skip=skip)
        return(df)
        }
    else{
        print('More than one data entity!\n')
        print(data_ents)
        }
    }
