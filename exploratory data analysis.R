# ///////////////////
# LIBRARIES
library(httr)
library(magrittr)
library(rvest)
library(ggplot2)
# //////////////////
clientID = ""
secret = ""

response = POST(
  'https://accounts.spotify.com/api/token',
  accept_json(),
  authenticate(clientID, secret),
  body = list(grant_type = 'client_credentials'),
  encode = 'form',
  verbose()
)

token = content(response)$access_token

authorization.header = paste0("Bearer ", token)
#GET(url = paste("https://api.spotify.com/v1/tracks/", ":ID", sep = ""),
#           config = add_headers(authorization = authorization.header))
# //////////////////
# WEB SCRAPING


weekly.top.songs = read_html("https://spotifycharts.com/regional/global/weekly/latest") %>%
  html_nodes("#content > div > div > div > span > table > tbody > tr > td.chart-table-image > a")

id.start = regexpr("/track/", weekly.top.songs) # seems to always be 34
id.end = regexpr('" target="', weekly.top.songs) # seems to always be 63

top.song.ids = substr(weekly.top.songs, id.start+7, id.end-1)
# //////////////////
# API REQUESTS

# Audio Analysis
#analyses = lapply(1:200, function(n) {
#  GET(url = paste0("https://api.spotify.com/v1/audio-analysis/", top.song.ids[n]),
#           config = add_headers(authorization = authorization.header))
#})

# Get track
tracks = lapply(1:200, function(n) {
  GET(url = paste("https://api.spotify.com/v1/tracks/", top.song.ids[n], sep = ""),
                        config = add_headers(authorization = authorization.header))
})

tracks.content = sapply(1:200, function(n) {
  content(tracks[[n]])
})

tracks.content = t(tracks.content)
tracks.artists = sapply(1:200, function(n) {
  tracks.content[[n]]$artists
})

tracks.artist.names = sapply(1:200,function(n){
  tracks.artists[[n]][[1]]$name
})
tracks.artist.names = sapply(1:200,function(n){
  substr(tracks.artist.names[n],1,length(tracks.artist.names)-1)
})
tracks.song =sapply(1:200, function(n){
  tracks.content[[n]]$name
})
tracks.df$name = sapply(1:200,function(n){
  tracks.content[n,11]
})
tracks.df$pop = sapply(1:200,function(n){
  tracks.content[n,12]
})
tracks.df$album = sapply(1:200,function(n){
  tracks.content[n,1][[1]][8]
})


tracks.df$artist  = tracks.artist.names
tracks.df$id = sapply(1:200,function(n){
  tracks.content[n,10]
})
tracks.df = cbind(rating = 1:200, name = tracks.names)
tracks.df = tracks.df %>% as.data.frame

# Audio Features
features = lapply(1:200, function(n) {
  GET(url = paste0("https://api.spotify.com/v1/audio-features/", top.song.ids[n]),
               config = add_headers(authorization = authorization.header))
})

features.content = sapply(1:200, function(n) {
  content(features[[n]])
})

features.content = t(features.content)

features.df = cbind(rank = 1:200, rank.desc = 200:1, danceability = features.content[,1], 
                    energy = features.content[,2], key = features.content[,3], 
                    loudness = features.content[,4], mode = features.content[,5],
                    speechiness = features.content[,6], acousticness = features.content[,7],
                    instrumentalness = features.content[,8], liveness = features.content[,9],
                    valence = features.content[,10], tempo = features.content[,11], 
                    duration_ms = features.content[,17], time_signature = features.content[,18])

features.df = features.df %>% as.data.frame

for (i in 1:ncol(features.df)) {
  features.df[,i] = unlist(features.df[,i])
}

features.df$id = sapply(1:200,function(n){
  features.content[n,13]
})

#Merge features and track info
master.df = cbind(tracks.df,features.df[,-c(1,15)])

# //////////////////
# SUMMARY STATS
feature.means = sapply(3:15, function(n) {
  mean(features.df[,n])
})
feature.sds = sapply(3:15, function(n) {
  sd(features.df[,n])
})
feature.maxes = sapply(3:15, function(n) {
  max(features.df[,n])
})
feature.mins = sapply(3:15, function(n) {
  min(features.df[,n])
})
feature.medians = sapply(3:15, function(n) {
  median(features.df[,n])
})

feature.summaries = cbind(feature = names(features.df)[-c(1,2)],
                          mean = feature.means,
                          median = feature.medians,
                          standard.deviation = feature.sds,
                          min = feature.mins,
                          max = feature.maxes,
                          range = feature.maxes-feature.mins,
                          range.over.sd = (feature.maxes-feature.mins)/feature.sds,
                          skewness = 3*(feature.means-feature.medians)/feature.sds)
# //////////////////
# VISUALIZATIONS
ggplot(features.df, aes(x = danceability)) + geom_histogram(bins = 25) + theme_minimal()
ggplot(features.df, aes(x = energy)) + geom_histogram(bins = 25) + theme_minimal()
ggplot(features.df, aes(x = speechiness)) + geom_histogram(bins = 25) + theme_minimal()
ggplot(features.df, aes(x = liveness)) + geom_histogram(bins = 25) + theme_minimal()
ggplot(features.df, aes(x = valence)) + geom_histogram(bins = 25) + theme_minimal()
ggplot(features.df, aes(x = tempo)) + geom_histogram(bins = 25) + theme_minimal()
ggplot(features.df, aes(x = duration_ms)) + geom_histogram(bins = 25) + theme_minimal()
ggplot(features.df, aes(x = mode)) + geom_bar() + theme_minimal()
ggplot(features.df, aes(x = time_signature)) + geom_bar() + theme_minimal()
ggplot(features.df, aes(x = key)) + geom_bar() + theme_minimal()

ggplot(features.df, aes(x = danceability, y = rank.desc)) + geom_point() + theme_minimal()
ggplot(features.df, aes(x = energy, y = rank.desc)) + geom_point() + theme_minimal()
ggplot(features.df, aes(x = speechiness, y = rank.desc)) + geom_point() + theme_minimal()
ggplot(features.df, aes(x = liveness, y = rank.desc)) + geom_point() + theme_minimal()
ggplot(features.df, aes(x = valence, y = rank.desc)) + geom_point() + theme_minimal()
ggplot(features.df, aes(x = tempo, y = rank.desc)) + geom_point() + theme_minimal()
ggplot(features.df, aes(x = duration_ms, y = rank.desc)) + geom_point() + theme_minimal()

ggplot(features.df, aes(x = key, y = rank.desc)) + geom_point() + theme_minimal()
# //////////////////
# modeling


# Audio Analysis
#analyses = lapply(1:200, function(n) {
#  GET(url = paste0("https://api.spotify.com/v1/audio-analysis/", top.song.ids[n]),
#           config = add_headers(authorization = authorization.header))
#})

clasnames = lapply()
name.start = regexpr('name',s)
name.end = regexpr('type',s)
name = substr(s,name.start+8,name.end-4)
name
