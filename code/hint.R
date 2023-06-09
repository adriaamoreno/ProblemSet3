
rm(list = ls())
## librerias
require(pacman)
p_load(tidyverse,rio,stargazer,coefplot,sf,leaflet,rvest,xml2,osmdata
       ,ggsn,tmaptools,ggmap,ggspatial,writexl,wordcloud,tm, SnowballC,htmlwidgets)

setwd("C:/Users/LENOVO/Desktop/R spacial data")

#########
#Punto 1
#########

## datos
df = import("input/data_regresiones.rds")


## modelos
modelo_1 = lm(price ~ dist_cbd + as.factor(property_type) , data= df)
modelo_2 = lm(price ~ dist_cbd + as.factor(property_type) + rooms , data= df)
modelo_3 = lm(price ~ dist_cbd + as.factor(property_type) + rooms + bathrooms, data= df)

## visualizacion
coefplot(model = modelo_3) + theme_test()

## 
ggsave(filename = "output/plot_regresiones.png")
stargazer(modelo_1,modelo_2,modelo_3,
          type = "text", 
          out = "output/resultados_regresiones.xlsx")



#########
#Punto 2
#########

###Punto 2.1 Descargar Datos
available_features() %>% head(50) # Mirando las posibles propieadades donde pueda encontrar parques y restaureantes
available_tags("amenity") %>% head(100) # Observando los tags de la propiedad "amenity" para encontrar restaurantes
available_tags("leisure") %>% head(100) # Observando los tags de la propiedad "leisure" para encontrar Parques

#Es Posible identificar que en amenities se encuentra "restaurant" en la posición 100
#Es Posible identificar que en leisure se encuentra "Park" en la posición 24

#Extraemos incialmente los datos OSM
restaurantes = opq(bbox = getbb("Medellín Colombia")) %>%
  add_osm_feature(key="amenity" , value="restaurant") 

parques = opq(bbox = getbb("Medellín Colombia")) %>%
  add_osm_feature(key="leisure" , value="park") 

#Transformamos los OSM de restaurantes y parques en OSM_sf
restaurantes = restaurantes %>% osmdata_sf()
parques =parques %>% osmdata_sf()

#Transformamos a sf
restaurantes  = restaurantes$osm_points %>% select(osm_id,amenity)
parques = parques$osm_polygons %>% select(osm_id,name)

### Punto 2.2 
#generamos el mapa con leaflet de parques y restaurantes 

leaflet() %>% addTiles() %>% addPolygons(data = parques, color = "red") %>% addCircles(data=restaurantes)

### Punto 2.3 


direccion <- "Cl 52 52 43, Medellín, Colombia"
geocod <- geocode_OSM(direccion)

### Punto 2.4

#Agregar map base de Medellín 
mapa_Medellin <- get_stamenmap(bbox=getbb("Medellín Colombia"), zoom = 12)

#retomar algunos ammenities en osmdata_sf para influir en el plot

restaurantes = opq(bbox = getbb("Medellín Colombia")) %>%
  add_osm_feature(key="amenity" , value="restaurant") %>%
  osmdata_sf()


parques = opq(bbox = getbb("Medellín Colombia")) %>%
  add_osm_feature(key="leisure" , value="park") %>% 
  osmdata_sf()

#retomar dirección de Museo
geocod <- as.data.frame(t(geocod$coords))

##### Mapa Completo
### Para Mapa_Medellin agregamos todos los puntos y poligonos correspondientes a restaurantes, parques y a la dirección
Mapa_Medellin<-ggmap(mapa_Medellin)+
  geom_sf(
    data = parques$osm_polygons,
    inherit.aes = FALSE,
    colour = "#08519c",
    fill = "#08306b",
    alpha = .5,
    size = 1
  )+
  geom_point(data = geocod, aes(x=geocod$x, y=geocod$y), fill = "black", size = 2)+ # punto de la dirección
  geom_sf( #Puntos de los restaurantes
    data = restaurantes$osm_points,
    inherit.aes = FALSE,
    colour = "#F8766D", #color borde del punto
    fill = "#F8766D", #color relleno del punto
    alpha = .5,
    size = 1
  )

### Para Mapa Medellin All agregamos la escala, la estrella norte y el theme.  
Mapa_Medellin_All<-Mapa_Medellin +
  ggspatial::annotation_scale(
    location = "tr", #indicamos lugar donde va a ir la escala
    bar_cols = c("grey60", "white"),#colores de la escala
    text_family = "ArcherPro Book" # tipo de letra
  ) +
  ggspatial::annotation_north_arrow( 
    location = "tr", which_north = "true",
    pad_x = unit(0.1, "in"), pad_y = unit(0.2, "in"), #indicamos lugar donde va a ir la estrella
    style = ggspatial::north_arrow_nautical(
      fill = c("grey40", "white"), #colores de la estrella y letra del Norte(N)
      line_col = "grey20",
      text_family = "ArcherPro Book"
    )
  ) +theme(plot.title = element_text(size = 20, family = "lato", face="bold", hjust=.5), #ajustes del título en posición, tamaño y tipo de letra
           plot.subtitle = element_text(family = "lato", size = 8, hjust=.5, margin=margin(2, 0, 5, 0))) + #ajustes del subtítulo en posición, tamaño y tipo de letra
  labs(title = "Medellín", subtitle = "Restaurantes/Parques/Museo") 

### salvamos el mapa en la carpeta correspondiente de otuputs
ggsave("output/mapa_amenities.png",Mapa_Medellin_All,width = 8, height = 6, dpi = 300)

#########
#Punto 3
#########

###Punto 3.1 

url <- "https://es.wikipedia.org/wiki/Departamentos_de_Colombia" #ubicamos la URL
browseURL(url) #revisamos que la URL funcione y redireccione a la página corresponsiente

html <- read_html(url) #leemos el HTML y obtenemos un documento tipo XML
class(html)

###Punto 3.2 
Titulo<-html %>% #obtenemos el tírulo mediante Xpath
  html_element(xpath = "//title") %>% 
  html_text()

###Punto 3.3
tablas <- html %>%
  html_elements("table") %>%
  html_table()

departamento <- data.frame(tablas[[4]]) ## creamos la tabla como un data FRame seleccionandola dentro de Tablas
write_xlsx(departamento, "output/tabla_departamentos.xlsx")

###Punto 3.4 

paragraphs <- html_nodes(html, "p") #Extraemos los párrafos del HTMl
texto <- html_text(paragraphs)#Lo volvemos todo en texto de Rdocs 
texto <- Corpus(VectorSource(texto))#Lo pasamos a corpus para poder tratar mejor el texto y modificar signos de puntuación y demás elementos
texto <- texto %>%
  tm_map(removeNumbers) %>% # remover npumeros
  tm_map(removePunctuation) %>% #remover signos de puntuación 
  tm_map(stripWhitespace) # remover espacios en blanco
texto <- tm_map(texto, content_transformer(tolower)) # tranformar a minúsculas todas las letras
dtm <- TermDocumentMatrix(texto) #extraemos el elemento que contiene la matriz de texto con las palabras y la frecuencia
m <- as.matrix(dtm) #extraemos la matriz
v <- sort(rowSums(m),decreasing=TRUE) #ordenamos la matriz de mayor a menos por número de frecuencia de palabras
d <- data.frame(word = names(v),freq=v) #lo tranformamos en data frame y e damos nombres a las columnas
head(d, 10)#primeras 10 palabras con más frecuencia

png("output/nube_palabras.png") #especificamos el path para guardar la nube de datos
set.seed(123)
wordcloud(words = d$word, freq = d$freq, min.freq = 1, max.word = 500,
                      random.order = FALSE, rot.per = 0.5,scale=c(1.5,0.5) ) #obtenemos la nube de texto
dev.off()#guardamos la nube de datos en el path especificado previamente
