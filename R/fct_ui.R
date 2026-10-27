# =============================================================================
#   COMPONENTES DE INTERFACE REUTILIZÁVEIS
#   Reúne os componentes de interface que o painel reaproveita; cada função
#   registra na própria documentação exatamente onde é usada.
# =============================================================================

#' Definindo uma função que monta o cabeçalho de uma seção do painel
#'
#' @param titulo Título principal da seção.
#' @param descricao Parágrafo de apoio (opcional).
#' @return Elemento HTML com o cabeçalho da seção.
#' Usada em: mod_onde.R e mod_como.R (cabeçalho de cada seção).
#' @noRd
titulo_secao <- function(titulo, descricao = NULL) {
  htmltools::tags$header(
    class = "secao-cabecalho",
    htmltools::tags$h2(class = "secao-titulo", titulo),
    if (!is.null(descricao)) {
      htmltools::tags$p(class = "secao-descricao", descricao)
    }
  )
}

#' Definindo uma função que cria um seletor inline integrado à frase de controles
#'
#' @param input_id Identificador do input.
#' @param choices Vetor nomeado de opções.
#' @param selected Valor selecionado inicialmente.
#' @param largura Largura do seletor (mínima).
#' @param busca Habilita o campo de busca dentro do dropdown.
#' @return Elemento HTML do seletor estilizado.
#' Usada em: mod_onde.R (medida, ano e escopo) e mod_como.R (município, ano e comparação).
#' @noRd
seletor_inline <- function(input_id, choices, selected = NULL, largura = "auto",
                           busca = TRUE) {
  shinyWidgets::slimSelectInput(
    inputId = input_id,
    label = NULL,
    choices = choices,
    selected = selected,
    width = largura,
    search = busca,
    placeholder = "Selecione",
    # Traduzindo os textos e realçando o trecho encontrado pela busca
    searchPlaceholder = "Buscar...",
    searchText = "Nenhum resultado",
    searchHighlight = TRUE
  )
}

#' Definindo uma função que cria o selo colorido de uma categoria
#'
#' @param categoria Rótulo da categoria.
#' @param cor Cor de fundo do selo (opcional).
#' @return Elemento HTML do selo.
#' Usada em: fct_perfil.R (selo do índice no placar) e fct_petalas.R (selo do tooltip da pétala).
#' @noRd
badge_categoria <- function(categoria, cor = NULL) {
  # Usando a cor da categoria quando nenhuma cor for informada
  if (is.null(cor) || is.na(cor)) {
    cor <- cor_categoria(categoria)
  }
  htmltools::tags$span(
    class = "badge-categoria",
    style = paste0(
      "--cor-fundo:", cor, ";",
      "color:", cor_texto_sobre(cor), ";"
    ),
    categoria
  )
}

#' Definindo uma função que monta selos de categoria em HTML de forma vetorizada
#'
#' @param categorias Vetor de categorias.
#' @param medida Identificador da medida que define a rampa de cores.
#' @return Vetor de textos HTML com os selos coloridos.
#' Usada em: mod_onde.R (coluna Categoria da tabela do ranking).
#' @noRd
badge_categoria_html <- function(categorias, medida = "indice_final") {
  # Calculando as cores de fundo e de texto de uma só vez
  cores <- cor_categoria(categorias, medida)
  sprintf(
    '<span class="badge-categoria" style="--cor-fundo:%s;color:%s">%s</span>',
    cores,
    cor_texto_sobre(cores),
    categorias
  )
}

#' Definindo uma função que monta a chip do sentido de interpretação de um indicador
#'
#' @param protetor Indica se valores maiores são favoráveis ao Índice VIDAS.
#' @return Elemento HTML da chip com a seta e o sentido do indicador.
#' Usada em: mod_como.R (cartões dos indicadores do bloco).
#' @noRd
chip_sentido_indicador <- function(protetor) {
  # Escolhendo a seta, o rótulo e a explicação conforme o sentido no índice
  maior_melhor <- isTRUE(protetor)
  htmltools::tags$span(
    class = paste0(
      "indicador-card__sentido ",
      if (maior_melhor) "indicador-card__sentido--maior" else "indicador-card__sentido--menor"
    ),
    # Ativando a tooltip padrão do painel no lugar da tooltip nativa do navegador
    `data-bs-toggle` = "tooltip",
    # Explicando a leitura em uma frase completa ao passar o mouse
    title = if (maior_melhor) {
      "Neste indicador, valores maiores indicam melhores condições."
    } else {
      "Neste indicador, valores menores indicam melhores condições."
    },
    htmltools::tags$span(
      class = "indicador-card__sentido-seta",
      `aria-hidden` = "true",
      if (maior_melhor) "↑" else "↓"
    ),
    if (maior_melhor) "Maior é melhor" else "Menor é melhor"
  )
}

#' Definindo uma função que exibe um estado vazio com mensagem amigável
#'
#' @param mensagem Texto explicativo.
#' @param icone Nome do ícone do fontawesome (opcional).
#' @return Elemento HTML do estado vazio.
#' Usada em: fct_perfil.R (palco sem seleção e sem dado) e mod_como.R (evolução sem série).
#' @noRd
estado_vazio <- function(mensagem, icone = NULL) {
  htmltools::tags$div(
    class = "estado-vazio",
    if (!is.null(icone)) {
      # Envolvendo o ícone do fontawesome em um contêiner com classe de estilo
      htmltools::tags$span(class = "estado-vazio__icone", fontawesome::fa(icone))
    },
    htmltools::tags$p(class = "estado-vazio__texto", mensagem)
  )
}

