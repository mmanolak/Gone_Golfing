download.file("https://www.ers.usda.gov/webdocs/DataFiles/53251/ruralurbancodes2013.xls", destfile="rucc.xls", mode="wb")
library(readxl)
df <- read_excel("rucc.xls")
write.csv(df, "USDA_RUCC_Codes.csv", row.names=FALSE)
