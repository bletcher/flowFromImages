flickr_photosets_getphotos <- function(the_photoset_id = NULL, 
                                       time_start = NULL, 
                                       time_end = NULL, 
                                       the_api_key = "b17072d6e8c8f93662be1635ac49f557", 
                                       the_user_id = "155284079@N03",
                                       page_number = 1) {
  # returns data.frame of photos including datetaken, latitude, longitude, 
  # url_m, height_m, width_m and url_s, height_s, height_m
  # xx <- GET(url=sprintf(
  #   "https://api.flickr.com/services/rest/?method=flickr.photosets.getPhotos&api_key=%s&photoset_id=%s&user_id=%s&extras=%s&format=json&nojsoncallback=1"
  #   , the_api_key
  #   , the_photoset_id
  #   , the_user_id
  #   , "description,date_taken,geo,url_m,url_s"
  # )
  # ) %>% content(as = "text") %>%
  #   fromJSON()  # check that xx$stat == "ok"
  # 
  xx <- GET(url=sprintf(
    "https://api.flickr.com/services/rest/?method=flickr.photosets.getPhotos&api_key=%s&photoset_id=%s&user_id=%s&page=%s&extras=%s&format=json&nojsoncallback=1"
    , the_api_key
    , the_photoset_id
    , the_user_id
    , page_number
    , "description,date_taken,geo,url_m,url_s"
  )
  ) %>% content(as = "text") %>%
    fromJSON()

  if (xx$stat != "ok") {
    print(paste("Flickr error"))
    return(xx$stat)
  }

  # total # of images. Can only grab 500 at a time
  print(xx$photoset$total)
    
  # description gets returned as a data.frame. I'm not sure why. so get _content
  xx$description <- xx$description[ ,"_content"]
  xx$photoset$photo$datetaken <- (xx$photoset$photo$datetaken)
  xx$photoset$latitude <- as.numeric(xx$photoset$latitude)
  xx$photoset$longitude <- as.numeric(xx$photoset$longitude)
  xx$photoset$photo$latitude <- ifelse(xx$photoset$photo$latitude != 0, xx$photoset$photo$latitude, NA)
  xx$photoset$photo$longitude <- ifelse(xx$photoset$photo$longitude != 0, xx$photoset$photo$longitude, NA)
  xx$photoset$photo$total <- xx$photoset$total
  xx$photoset$photo <- xx$photoset$photo %>% select(-description) # remove nested dataframe - gives problems later with rbind in getData()
  if (is.null(time_start) & is.null(time_end)) return(xx$photoset$photo)
  filter(xx$photoset$photo, is.null(time_start) | (datetaken >= time_start), is.null(time_end) | (datetaken >= time_end))
}
