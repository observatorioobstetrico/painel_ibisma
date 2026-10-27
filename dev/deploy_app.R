#!/usr/bin/env Rscript
# Publicando o painel no shinyapps.io com a conta do Observatório Obstétrico Brasileiro
# Uso: executar com `Rscript dev/deploy_app.R` ou rodar interativamente na raiz do projeto

# Verificando se o script está sendo rodado na raiz do projeto
if (!file.exists("app.R")) {
  stop("Execute este script na raiz do projeto (arquivo app.R não encontrado).")
}

# Verificando se o pacote rsconnect está instalado antes de seguir
if (!requireNamespace("rsconnect", quietly = TRUE)) {
  stop("O pacote 'rsconnect' é necessário. Instale com install.packages('rsconnect').")
}

# Definindo a conta e o nome do aplicativo no shinyapps.io
account <- "observatorioobstetrico"
appName <- "painel_vidas"

# Fazendo o deploy sem appFiles para que o .rscignore seja respeitado
rsconnect::deployApp(
  appDir = ".",
  appName = appName,
  appTitle = appName,
  account = account,
  server = "shinyapps.io",
  forceUpdate = TRUE,
  launch.browser = FALSE
)
