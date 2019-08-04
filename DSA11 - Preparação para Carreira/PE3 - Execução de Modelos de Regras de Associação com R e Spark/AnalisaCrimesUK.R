# Análise de Associação de Crimes nos Arredores de Londres
# Usando Algoritmo de Regras de Associação com R e Spark

# Dataset: https://data.police.uk/data/
# Depois de baixar o dataset, concatene os arquivos csv com o script concat.sh (Mac ou Linux)

# Instala os Pacotes
install.packages("tidyverse")
install.packages("visNetwork")
install.packages("leaflet")
install.packages("leaflet.extras")

# Instale o sparklyr preferencialmente a partir do Github para obter a versão mais nova
install.packages("sparklyr")
devtools::install_github("rstudio/sparklyr")

# Carrega na memória
library(tidyverse)
library(visNetwork)
library(sparklyr)
library(reshape2)
library(leaflet)
library(leaflet.extras)

# Instal o Spark
spark_install()

# Conecta no Cluster Spark
sc <- spark_connect(master = "local")
#sc <- spark_connect(master="spark://ec2-18-220-46-60.us-east-2.compute.amazonaws.com:7077", 
#                    version = "2.3.0",
#                    spark_home = "/opt/spark/")


# Carrega o dataset
setwd("~/Dropbox/DSA/ProjetosEspeciais/Projeto3")
df <- read_csv('wiltshirepolice.csv')
summary(df)
View(df)


# --------------------- Análise Exploratória e Visualização --------------------- 

# Vamos visualizar um pouco do que temos até aqui
df %>% dplyr::filter(Month == '2018-04' | Month == '2018-05') %>%
  filter(`Crime type`== 'Anti-social behaviour') %>%
  select(Longitude, Latitude) %>% 
  group_by(Longitude, Latitude) %>% 
  count() %>%
  leaflet() %>%
  addTiles() %>%
  addWebGLHeatmap(lng=~Longitude, lat=~Latitude, intensity = ~n, size=1000, opacity = 0.6)

df %>% dplyr::filter(Month == '2018-05')  %>%
  select(Longitude, Latitude, 'Crime type') %>% 
  leaflet() %>%
  addTiles() %>%
  addMarkers(
    clusterOptions = markerClusterOptions(),
    popup = ~'Crime type'
  )

# --------------------- Data Wrangling (Limpeza e Manipulação de Dados) --------------------- 

# Na inspeção inicial, parece que os casos / incidentes que não possuem um Crime ID 
# também não possuem uma Last outcome category. Vamos verificar isso:
null_test <- df %>% select('Crime ID', 'Last outcome category')
test_1 <- null_test %>% filter(is.na('Crime ID') & !is.na('Last outcome category')) %>% nrow()
test_2 <- null_test %>% filter(!is.na('Crime ID') & is.na('Last outcome category')) %>% nrow()

# Print
print(c(test_1, test_2))

# Nome das colunas
colnames(df)

# Count
df %>% count('Reported by')

# Estou interessado apenas nos dados de Wiltshire (inc. Swindon). 
# Portanto, eu quero remover quaisquer LSOAs que não sejam Wiltshire ou Swindon. 
# Vamos ver se existe algum.
df %>% filter(!grepl('Swindon', `LSOA name`) & !grepl('Wiltshire', `LSOA name`)) %>% count()

# Agora a coluna Contexto parece estar completamente cheia de NAs. Vamos verificar isso.
df %>% filter(!is.na(Context)) %>% nrow()

# Agora vamos ver os elementos mais comuns na última categoria de resultados.
# Parece que temos uma grande quantidade de NAs, mas por quê?
df %>% select(`Last outcome category`) %>%
  table(useNA = 'always') %>%
  sort(decreasing = T) %>%
  head(10)

# À primeira vista, parece haver casos de comportamento anti-social que todos têm NA
df %>% filter(is.na(`Last outcome category`)) %>% 
  select(-c(`LSOA code`, `Crime ID`,  `Reported by`, `Falls within`, Context, Month, Longitude, Latitude)) %>%
  head(10)

# Para confirmar isso, vamos analisar mais profundamente:
df %>% filter(is.na(`Last outcome category`)) %>% 
  select(`Crime type`) %>%
  table()

# Isso é muito preocupante pois todos os casos de comportamento anti-social são nulos 
# para sua categoria de resultado.
# Infelizmente, pode haver vários resultados associados ao Anti Social Behavior, 
# não posso simplesmente presumir que eles não estão resolvidos. 
# Então, infelizmente, terei que excluir o comportamento anti-social das minhas regras de associação.
df %>% filter(`Crime type` == 'Anti-social behaviour') %>% 
  select(`Last outcome category`) %>%
  table()

# Vamos terminar a limpeza dos dados
df_clean <- df %>% select(-c(`Crime ID`, `Reported by`, 
                             `Falls within`, `LSOA code`, Context)) %>%
  filter(grepl('Swindon', `LSOA name`) | grepl('Wiltshire', `LSOA name`)) %>%
  filter(`Crime type` != 'Anti-social behaviour') %>%
  mutate(Location = trimws(str_replace(Location, 'On or near', ""))) %>%
  rowid_to_column("id")

# Dataset limpo
View(df_clean)


# --------------------- Feature Engineering e Machine Learning com Spark --------------------- 

# Para usar regras de associação no sparklyr, precisamos ter os dados no formato correto.
# Precisamos converter os dados de formato amplo (wide) em um formato longo (long) 
# e coletar cada elemento por id em uma lista.

# Estaremos procurando associações entre a localização do crime, o resultado e o tipo de crime.
df_assoc <- df_clean %>% select(id,
                                `LSOA name`,
                                Location,
                                `Crime type`, 
                                `Last outcome category`) %>%
  melt(id.vars = 'id') %>%
  select(id, value)

# Visualiza o dataframe com ids e valores
head(df_assoc)

# Copia o dataframe para o cluster
sc <- spark_connect(master = "local")
df_assoc_tbl <- sparklyr::sdf_copy_to(sc, df_assoc, overwrite = T)

# Para criar o 'basket' comumente usado na Mineração da Regra de Associação, 
# precisaremos coletar cada elemento por id em uma lista.
df_assoc_collect <- df_assoc_tbl %>% 
  group_by(id) %>%
  summarise(
    items = collect_list(value)
  )

# Visualiza o dataframe
head(df_assoc_collect)

# Usaremos o algoritmo FPGrowth, que é uma versão melhorada do algoritmo apriori para grandes conjuntos de dados.
# Não costumava haver nenhum método para isso no sparklyr, então era necessário invocá-lo a partir da linguagem Scala. 
# Mas agora existe!
  
# Agora vamos construir nosso modelo de regras de associação, especificando uma confiança mínima de 0,7 
# e um suporte mínimo de 0,01
model <- sparklyr::ml_fpgrowth(df_assoc_collect, min_support = 0.01, min_confidence = 0.7)
rules <- sparklyr::ml_association_rules(model)

# O que temos aqui? Se a sua bicicleta, carro ou casa foram roubados em Swindon ou Wiltshire, 
# desista. O caso será encerrado sem nenhum suspeito identificado.
as.data.frame(rules)

# Minerando as regras de associação
?ml_fpgrowth
ml_fpgrowth(df_assoc_collect)

# Preparando o algoritmo
uid = sparklyr:::random_string("fpgrowth_")
jobj = invoke_new(sc, "org.apache.spark.ml.fpm.FPGrowth", uid) 

# Criando o modelo
FPGmodel <- jobj %>% 
  invoke("setItemsCol", "items") %>%
  invoke("setMinConfidence", 0.03) %>%
  invoke("setMinSupport", 0.01)  %>%
  invoke("fit", spark_dataframe(df_assoc_collect))

# Função para extração das regras de associação
ml_fpgrowth_extract_rules = function(FPGmodel, nLHS = 2, nRHS = 1)
{
  rules = FPGmodel %>% invoke("associationRules")
  sdf_register(rules, "rules")
  
  exprs1 <- lapply(
    0:(nLHS - 1), 
    function(i) paste("CAST(antecedent[", i, "] AS string) AS LHSitem", i, sep="")
  )
  exprs2 <- lapply(
    0:(nRHS - 1), 
    function(i) paste("CAST(consequent[", i, "] AS string) AS RHSitem", i, sep="")
  )
  
  splittedLHS = rules %>% invoke("selectExpr", exprs1) 
  splittedRHS = rules %>% invoke("selectExpr", exprs2) 
  p1 = sdf_register(splittedLHS, "tmp1")
  p2 = sdf_register(splittedRHS, "tmp2")
  
  # Coletando regras de saída para o R
  bind_cols(
    sdf_bind_cols(p1, p2) %>% collect(),
    rules %>% collect() %>% select(confidence)
  )
}

# Extraindo as regras geradas pelo modelo
rules <- ml_fpgrowth_extract_rules(FPGmodel)
head(rules)
View(rules)

# Mapa de Associação
rules = rules %>% filter(confidence > 0.5)
nds = unique(
    c(
      rules[,"LHSitem0"][[1]],
      rules[,"RHSitem0"][[1]]
    )
  )
  
# Nodes do Grafo de Redes
nodes = data.frame(id = nds, label = nds, title = nds) %>% arrange(id)
  
# Arestas do Grafo de Redes
edges = data.frame(
    from =  rules[,"LHSitem0"][[1]],
    to = rules[,"RHSitem0"][[1]]
  )
  
# Visualização da rede
visNetwork(nodes, edges, main = "Associação de Crimes nos Arredores de Londres", size=1) %>%
    visOptions(highlightNearest = TRUE, nodesIdSelection = TRUE) %>%
    visEdges(arrows = 'from') %>%
    visPhysics(
      solver = "barnesHut", 
      forceAtlas2Based = list(gravitationalConstant = -20, maxVelocity = 1)
    )

# Encerra conexão com Spark
spark_disconnect(sc)

