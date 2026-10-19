#' The application server-side
#'
#' @param input,output,session Internal parameters for {shiny}.
#'     DO NOT REMOVE.
#' @import shiny
#' @noRd
app_server <- function(input, output, session) {
  # Preparando a base do painel uma única vez por processo
  dados <- dados_ibisma()

  # Compartilhando o município selecionado entre as duas seções do painel
  municipio <- shiny::reactiveVal(municipio_padrao(dados))

  # Registrando o módulo Onde? com o mapa e o ranking integrados
  mod_onde_server("onde", dados = dados, municipio = municipio)

  # Registrando o módulo Como? com o perfil do município
  mod_como_server("como", dados = dados, municipio = municipio)
}
