library(ggplot2)

### Carregando os dados ###
dataset <- read.csv("credit-card.csv")

### Tranformando e limpando os dados ###
# Substitui faixa de idades por categorias de idade
head(dataset$AGE)
dataset$AGE <- cut(dataset$AGE, c(0, 30, 50, 100), labels = c("Jovem", "Adulto", "Idoso"))
head(dataset$AGE)

# Substitui indicadores de sexo pela literal do gênero
dataset$SEX <- cut(dataset$SEX, c(0, 1, 2), labels = c("M", "F"))
head(dataset$SEX)

# Substitui indicadores de escolaridade por níveis escolares
dataset$EDUCATION <- cut(dataset$EDUCATION, c(0, 1, 2, 3, 4), labels = c("Pos graduado", "Graduado", "Ensino media", "Outros"))
head(dataset$EDUCATION)

# Substitui indicadores de estado civil pelo estado civil
dataset$MARRIAGE <- cut(dataset$MARRIAGE, c(-1, 0, 1, 2, 3), labels = c("Desconhecido", "Casado", "Solteiro", "Outros"))
head(dataset$MARRIAGE)

# Trata pagamentos
dataset$PAY_0 <- as.factor(dataset$PAY_0)
dataset$PAY_2 <- as.factor(dataset$PAY_2)
dataset$PAY_3 <- as.factor(dataset$PAY_3)
dataset$PAY_4 <- as.factor(dataset$PAY_4)
dataset$PAY_5 <- as.factor(dataset$PAY_5)
dataset$PAY_6 <- as.factor(dataset$PAY_6)

# Altera a variável dependente para tipo fator
dataset$default.payment.next.month <- as.factor(dataset$default.payment.next.month)
head(dataset)
str(dataset)
# Renomear a coluna de índice 25
colnames(dataset)
colnames(dataset)[25] <- "Inadimplentes"

# Verifica valores missing
sapply(dataset, function(x) sum(is.na(x)))
missmap(dataset, main = "Valores missing observados")
dataset <- na.omit(dataset)

# Remove a coluna ID
dataset$ID <- NULL

# Total de inad x adim (coluna 0 é adimplentes e 1 inadim)
table(dataset$Inadimplentes)

# Plot da distribuição usando ggplot
qplot(Inadimplentes, data = dataset, geom = "bar") + theme(axis.text.x = element_text(angle = 90, hjust = 1))

# Set the seed
set.seed(12345)

# Amostragem estratificada. Seleciona linhas conforme campo Inadimplentes como stratagem
TrainingDataIndex <- createDataPartition(dataset$Inadimplentes, p = 0.45, list = FALSE)
TrainingDataIndex

# Criar dados de treinamento como subconjunto do conjunto de dados com números de índices de linha
# conforme identificado acima e todas as colunas
trainData <- dataset[TrainingDataIndex,]
table(trainData$Inadimplentes)

# Ver proporção 
prop.table(table(trainData$Inadimplentes))

# Número de linhas em treinamento
nrow(trainData)

# Compara proporção entre dados de treino e originais
DistributionCompare <- cbind(prop.table(table(trainData$Inadimplentes)), prop.table(table(dataset$Inadimplentes)))
colnames(DistributionCompare) <- c("Treinamento", "Original")
DistributionCompare

# Melt Data - converte colunas em linhas
meltedComp <- melt(DistributionCompare)
meltedComp

# Plot distribuição original x treinamento
ggplot(meltedComp, aes(x = X1, y = value)) + geom_bar(aes(fill = X2), stat = "identity", position = "dodge")

# O que não está no dataset de treinamento está no original (sinal de subtração)
testData <- dataset[-TrainingDataIndex,]

# Usa validação cruzada de 10 folds para treinar e avaliar o modelo
TrainingParameters <- trainControl(method = "cv", number = 10)

######## Modelo de Classificação Random Forest ########

# Construindo o modelo
rf_model <- randomForest(Inadimplentes ~ ., data = trainData)
rf_model

# Confere o erro do modelo
plot(rf_model, ylim = c(0, 0.36))
legend('topright', colnames(rf_model$err.rate), col = 1:3, fill = 1:3)
varImpPlot(rf_model)

# Mostra os campos mais importantes
importance <- importance(rf_model)
varImportance <- data.frame(Variables = row.names(importance), Importance = round(importance[, 'MeanDecreaseGini']))

# Rankeia as variáveis mais importantes
rankImportance <- varImportance %>%
  mutate(Rank = paste0('#', dense_rank(desc(Importance))))

# Visualiza o ranking de importância
ggplot(rankImportance, aes(x = reorder(Variables, Importance), y = Importance, fill = Importance)) + 
  geom_bar(stat='identity') + 
  geom_text(aes(x = Variables, y = 0.5, label = Rank), hjust=0, vjust=0.55, size = 4, colour = 'red') +
  labs(x = 'Variables') + coord_flip()

# Previsoes
predictionrf <- predict(rf_model, testData)

# Confusion Matrix
install.packages("e1071")
library(e1071)
cmrf <- confusionMatrix(predictionrf, testData$Inadimplentes, positive = "1")
cmrf

# Salvando o modelo
saveRDS(rf_model, file = "rf_model.rds")

# Carregando o modelo
modelo <- readRDS("rf_model.rds")

# Calculando Precision, Recall e F1-Score, que sao metricas de avaliacao do modelo preditivo
y <- testData$inadimplente
predictions <- predictionrf

precision <- posPredValue(predictions, y)
precision

recall <- sensitivity(predictions, y)
recall

F1 <- (2 * precision * recall) / (precision + recall)
F1