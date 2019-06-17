
getEnvData <- function( startDate = '2016-12-18', gage = '01169900'){
  
  ################################################
  # get environmental data
  library(waterData)

  # gage from // south river, conway
  
  flowData <- importDVs(gage, code = "00060", stat = "00003", sdate = startDate)
  flowData <- dplyr:::rename(flowData, flow = val )
  
  flowData$date <- as.character(flowData$dates)
  return(flowData)

}

getImages <- function(flowData, propTestImages = 0.1, the_photoset_id = "72157681488505313"){

  #########################################################3
  # get images from the 'sawmill' album on flickr
  
  library(httr)
  library(jsonlite)

  # get data from images in the album
  # can grab 500 per page
  xx1 <- flickr_photosets_getphotos(the_photoset_id, page_number = 1)
  numImages <- max(xx1$total)
  
  if(numImages > 500) {
    numPagesExtraNeedsed <- round((numImages - 500) / 500) 
    for(i in 2:(2 + numPagesExtraNeedsed)) {
      xxTMP <- flickr_photosets_getphotos(the_photoset_id, page_number = i)
      row.names(xxTMP) <- as.numeric(row.names(xxTMP)) + 500 * (i - 1)
      xx1 <- rbind(xx1,xxTMP)
    }
  }
   
  # combine flow and image data
  xx1$dates <- as.Date(xx1$datetaken) #substr(xx$datetaken, 1, 10)
  #xx <- dplyr::left_join( xx1, flowData )#, by = c("date" = "dates") ) giving an error that I don't know how to fix
  xx <- merge( xx1, flowData, by.x = "dates", by.y = "dates" )
  
  xx$testImageTF <- runif(nrow(xx)) < propTestImages
  
  # download the files from the album
  
    for( i in 1:nrow(xx) ){
      
      xx$imageName_s[i] <- paste0("./img/sawmill_",substr(xx$datetaken[i], 1, 10),'_s.jpg')
      xx$imageName_m[i] <- paste0("./img/sawmill_",substr(xx$datetaken[i], 1, 10),'_m.jpg')

      # small images
      if( !file.exists(xx$imageName_s[i]) ) download.file(xx$url_s[i], destfile = xx$imageName_s[i], mode = "wb")
      # medium images
      if( !file.exists(xx$imageName_m[i]) ) download.file(xx$url_m[i], destfile = xx$imageName_m[i], mode = "wb")
      
    }

  return(xx)
}

 
