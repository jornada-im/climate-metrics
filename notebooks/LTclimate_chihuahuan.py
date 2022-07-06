#!/usr/bin/env python
# coding: utf-8

# ## Chihuahuan desert USHCN station data
# 
# JORNADA EXPERIMENTAL RANGE: USH00294426
# 
# 

# In[1]:


# Importing part of our climate tools module
# If you don't have it see here: https://github.com/gremau/climtools
import climtools.get_ushcn as ushcn

# Import standard python modules for data and file handling
import pandas as pd
import numpy as np
import os

# Path to our USHCN data store we downloaded
# Later versions of the data have had issues...
ushcn_path = '/home/greg/data/rawdata/NCDC/ushcn_v2.5/ushcn.v2.5.5.20220609'


# In[2]:


# Get the inventory file for USHCN stations
inventory = ushcn.get_stationsfile(os.path.dirname(ushcn_path))
inventory.head()


# In[3]:


# Choose a search term ('JORNADA', 'EL PASO', etc) and get the matching
# station id, name and latitude from the inventory
search = inventory[inventory['name'].str.contains('EL PASO')]
print(search)
studystn = search.id.values.tolist()[0]
studystnnames = search.name.values.tolist()[0]
studystnlat = search.lat.values.tolist()[0]


# In[4]:


# See functions, this will fetch precip and avg T, subset to site
# drop flags, and convert to correct units
tavg = ushcn.get_monthly_var('tavg', stationids=studystn, dpath=ushcn_path)
prcp = ushcn.get_monthly_var('prcp', stationids=studystn, dpath=ushcn_path)
# Then subset to years before 2022
tavg = tavg.loc[tavg.year < 2022,:]
prcp = prcp.loc[prcp.year < 2022,:]


# In[5]:


# Here we are adding a station_name and latitude column and populating
tavg['station_name'] = ''
tavg['latitude'] = np.nan
prcp['station_name'] = ''
prcp['latitude'] = np.nan
for i in range(0, 1):
    print(str(i) + ' ' + studystn + ' ' + studystnnames + ' ' + str(studystnlat))
    tavg.loc[tavg.stationid==studystn, 'station_name'] = studystnnames
    tavg.loc[tavg.stationid==studystn, 'latitude'] = studystnlat
    prcp.loc[prcp.stationid==studystn, 'station_name'] = studystnnames
    prcp.loc[prcp.stationid==studystn, 'latitude'] = studystnlat

# Put together the T and PRCP dataframes into one
out = pd.concat([tavg, prcp])


# In[6]:


# Write data out to a file
out.to_csv('../data/ELPASO_USHCN_monthlyclimate.csv', index=False)
out.tail()

