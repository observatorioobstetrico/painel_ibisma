# =============================================================================
#   ESQUELETOS DE CARREGAMENTO
#   Monta os marcadores que ocupam o lugar de cada output enquanto os dados são
#   processados. Cada esqueleto é irmão do output dentro de um slot e é exibido
#   pelo CSS quando o output está vazio ou em recálculo, sem trocar o conteúdo.
# =============================================================================

# Definindo a silhueta simplificada do Brasil usada no esqueleto do mapa
# O caminho foi gerado a partir das malhas estaduais, dissolvidas e simplificadas
ESQUELETO_MAPA_BRASIL <- paste0(
  "M 96.4 36.7 L 97.1 36.9 L 98 32.6 L 96.5 27.9 L 92.2 27.2 L 89 24.2 L 85.4 22.2 ",
  "L 82 22.4 L 77.1 20.9 L 76 21.2 L 76.3 20.6 L 75.2 21.9 L 75.4 21 L 74.6 21.3 ",
  "L 74 22.6 L 74.6 20.8 L 73.8 20.7 L 74.3 20 L 73.4 18.6 L 72.2 19 L 72.3 18.4 ",
  "L 71.8 18.7 L 70.9 17.7 L 70.2 18.1 L 70.1 17.3 L 69.4 17.6 L 66.4 16.4 L 64.5 17.3 ",
  "L 64.6 15.7 L 62.2 15.5 L 61.5 14.8 L 61.8 14.1 L 60.3 14.3 L 60.9 10.9 L 59.1 9.9 ",
  "L 58.1 5.6 L 56.7 4.1 L 56.7 5.2 L 53.6 9.8 L 46.2 8.9 L 46.1 10.6 L 42.9 10.2 ",
  "L 39 12.1 L 39 15.2 L 39 12 L 37 10.8 L 36.3 8.8 L 36.6 6.4 L 37.4 5.5 L 37.1 4.4 ",
  "L 35.9 4.1 L 36.3 2.7 L 35.7 2.2 L 34.5 2.3 L 34.8 3.1 L 33.8 4.1 L 29.6 5.2 ",
  "L 29 6.3 L 28.2 5.4 L 26.6 5.6 L 24.5 4.6 L 26 6.4 L 26.3 9 L 27.9 9.1 L 28.2 9.8 ",
  "L 26.5 10.3 L 25.6 11.7 L 23.7 12.4 L 22.7 13.5 L 22.5 12.7 L 20.8 13.3 L 18.9 12.3 ",
  "L 18.2 9.7 L 16.8 10.6 L 16.1 10.4 L 16.3 10.9 L 12.2 10.9 L 12.2 12.5 L 13.5 12.5 ",
  "L 13.9 13.6 L 11.7 13.8 L 11.6 15.6 L 13.2 17.9 L 11.9 25.7 L 9.9 25.3 L 4.9 27.6 ",
  "L 3.8 29.9 L 4 31.1 L 2.5 32.5 L 5.4 33.6 L 2.5 32.6 L 2 33.6 L 4.6 37.1 L 3.9 38.2 ",
  "L 6 38.4 L 6.4 39.6 L 8.7 39.6 L 10.6 38.2 L 10.2 42.1 L 14.9 42.4 L 20 39.5 ",
  "L 18.3 38.6 L 20.1 39.4 L 22.9 38.8 L 23.1 42.6 L 23.9 44.5 L 25.7 45.7 L 28.5 46.1 ",
  "L 31.7 48.3 L 34.6 48.5 L 35.3 49.4 L 35.7 52.1 L 34.9 52.1 L 35.7 53 L 35.8 55 ",
  "L 40.4 55 L 40.2 57.2 L 41.8 58.1 L 42.5 59.8 L 40.8 63.5 L 41.5 64.1 L 40.8 64.5 ",
  "L 41.6 66.5 L 41.2 69.2 L 46.4 69.7 L 47.5 73.7 L 50.7 73.8 L 49.5 77.8 L 50.7 77.6 ",
  "L 52.2 79.6 L 51.5 81.6 L 47 84 L 42.2 89.1 L 44.2 88.9 L 46 91.3 L 47.1 90.7 ",
  "L 52.4 94.9 L 53.2 95.1 L 54.3 93.9 L 53.9 95.7 L 53.1 95.5 L 52.4 96.4 L 52.5 97.8 ",
  "L 54.2 96.4 L 55.9 92 L 57.2 91.3 L 58.1 89.5 L 57.6 88.7 L 58.5 89.7 L 59.3 89.1 ",
  "L 59.3 89.8 L 55.7 93.8 L 58.9 91.3 L 61.5 87 L 63.7 85.1 L 64.8 82.3 L 64.2 82 ",
  "L 64.2 78.8 L 66.4 76 L 70.2 73.5 L 71.8 73.5 L 74 72.3 L 73.7 71.8 L 74.4 71.3 ",
  "L 76.5 71.7 L 77.7 70.7 L 77.8 71.4 L 80.3 71.4 L 80.4 70.3 L 82.9 69 L 82.8 67.2 ",
  "L 86 62.4 L 86.1 60 L 84.5 59.1 L 86.1 60 L 87.4 58.4 L 88.1 53.9 L 87.8 47.6 ",
  "L 89.4 46.8 L 91.7 43.2 L 91.3 43.4 L 96.8 37.5 L 97.1 37 L 96.4 36.7 Z"
)

#' Definindo uma função que monta um slot que empilha o output e o esqueleto correspondente
#'
#' @param output Elemento do output do Shiny.
#' @param esqueleto Elemento do esqueleto exibido durante o carregamento.
#' @param classe Classe extra aplicada ao slot (opcional).
#' @return Elemento HTML do slot.
#' Usada em: mod_onde.R e mod_como.R (empilhando os outputs).
#' @noRd
esqueleto_slot <- function(output, esqueleto, classe = NULL) {
  htmltools::tags$div(
    class = paste(c("esqueleto-slot", classe), collapse = " "),
    output,
    esqueleto
  )
}

#' Definindo uma função que monta uma barra do esqueleto
#'
#' @param largura Largura da barra (qualquer unidade CSS).
#' @param altura Altura da barra (qualquer unidade CSS).
#' @param classe Classe extra aplicada à barra (opcional).
#' @return Elemento HTML da barra.
#' Usada em: fct_esqueleto.R (todos os esqueletos).
#' @noRd
esqueleto_barra <- function(largura = "100%", altura = "0.6em", classe = NULL) {
  htmltools::tags$span(
    class = paste(c("esqueleto__barra", classe), collapse = " "),
    style = sprintf("width:%s;height:%s;", largura, altura)
  )
}

#' Definindo uma função que monta um bloco de métrica do esqueleto do perfil
#'
#' @param rotulo Largura da barra do rótulo.
#' @param valor Largura da barra do valor.
#' @return Elemento HTML com a métrica esquelética.
#' Usada em: fct_esqueleto.R (esqueleto_palco e esqueleto_rankings).
#' @noRd
esqueleto_metrica <- function(rotulo, valor) {
  htmltools::tags$div(
    class = "metrica",
    htmltools::tags$span(class = "metrica-rotulo", esqueleto_barra(rotulo, "0.55em")),
    htmltools::tags$span(class = "metrica-valor", esqueleto_barra(valor, "0.6em"))
  )
}

#' Definindo uma função que monta o esqueleto da área do mapa
#'
#' @return Elemento HTML com a silhueta do Brasil e o controle de zoom.
#' Usada em: mod_onde.R (esqueleto do mapa).
#' @noRd
esqueleto_mapa <- function() {
  htmltools::tags$div(
    class = "esqueleto esqueleto--mapa",
    `aria-hidden` = "true",
    # Desenhando a silhueta do país na mesma área do mapa real
    htmltools::tags$div(
      class = "esqueleto__desenho",
      htmltools::tags$svg(
        class = "esqueleto__mapa-desenho",
        viewBox = "0 0 100 100",
        preserveAspectRatio = "xMidYMid meet",
        htmltools::tags$path(class = "esqueleto__forma", d = ESQUELETO_MAPA_BRASIL)
      )
    ),
    # Reservando o lugar do controle de zoom do leaflet
    htmltools::tags$div(class = "esqueleto__controle")
  )
}

#' Definindo uma função que monta o esqueleto da legenda das categorias
#'
#' @return Elemento HTML com título e itens esqueléticos.
#' Usada em: mod_onde.R (esqueleto da legenda).
#' @noRd
esqueleto_legenda <- function() {
  # Variando as larguras para lembrar os rótulos reais das categorias
  larguras <- c("3rem", "2rem", "2.4rem", "2.2rem", "3.4rem")
  itens <- lapply(larguras, function(largura) {
    htmltools::tags$span(
      class = "legenda-item",
      esqueleto_barra("14px", "14px", "esqueleto__barra--quadrada"),
      htmltools::tags$span(class = "legenda-rotulo", esqueleto_barra(largura, "0.55em"))
    )
  })
  htmltools::tags$div(
    class = "legenda-categorias esqueleto esqueleto--legenda",
    `aria-hidden` = "true",
    htmltools::tags$span(class = "legenda-titulo", esqueleto_barra("7rem", "0.55em")),
    htmltools::tags$div(class = "legenda-itens", itens)
  )
}

#' Definindo uma função que monta o esqueleto de um texto curto
#'
#' @return Elemento HTML com a barra que ocupa o lugar da frase.
#' Usada em: mod_onde.R (esqueleto do resumo do ranking).
#' @noRd
esqueleto_texto <- function() {
  htmltools::tags$span(
    class = "esqueleto esqueleto__barra esqueleto--texto",
    `aria-hidden` = "true"
  )
}

#' Definindo uma função que monta o esqueleto da identificação da evolução
#'
#' @return Elemento HTML com a barra que ocupa o lugar do nome e do período.
#' Usada em: mod_como.R (esqueleto da identificação da evolução).
#' @noRd
esqueleto_identificacao <- function() {
  htmltools::tags$span(
    class = "esqueleto esqueleto__barra esqueleto--identificacao",
    `aria-hidden` = "true"
  )
}

#' Definindo uma função que monta a célula do esqueleto da tabela do ranking
#'
#' @param largura Largura fixa da coluna; NULL usa a coluna flexível.
#' @param barra Largura da barra interna; NULL deixa a célula sem barra.
#' @param altura Altura da barra interna.
#' @param celula Classe extra aplicada à célula (opcional).
#' @param marca Classe extra aplicada à barra (opcional).
#' @return Elemento HTML da célula.
#' Usada em: fct_esqueleto.R (esqueleto_ranking).
#' @noRd
esqueleto_celula <- function(largura = NULL, barra = NULL, altura = "0.6em",
                             celula = NULL, marca = NULL) {
  # Mantendo a coluna flexível para o nome do município ocupar a sobra
  classes <- "esqueleto__celula"
  estilos <- "width:auto;"
  if (!is.null(largura)) {
    estilos <- sprintf("width:%s;", largura)
  } else {
    classes <- paste(classes, "esqueleto__celula--flexivel")
  }
  if (!is.null(celula)) {
    classes <- paste(classes, celula)
  }
  htmltools::tags$div(
    class = classes,
    style = estilos,
    if (!is.null(barra)) esqueleto_barra(barra, altura, marca)
  )
}

#' Definindo uma função que monta o esqueleto do ranking
#'
#' @param linhas Número de linhas exibidas, igual ao tamanho de página real.
#' @return Elemento HTML com busca, cabeçalho, linhas e paginação.
#' Usada em: mod_onde.R (esqueleto da tabela do ranking).
#' @noRd
esqueleto_ranking <- function(linhas = 12) {
  # Reproduzindo as larguras de coluna configuradas no reactable
  celulas <- function() {
    list(
      esqueleto_celula("45px", "14px", "14px", marca = "esqueleto__barra--circulo"),
      esqueleto_celula("88px", "55%", celula = "esqueleto__celula--direita"),
      esqueleto_celula(NULL, "70%"),
      esqueleto_celula("54px", "60%"),
      esqueleto_celula("84px", "70%", celula = "esqueleto__celula--direita"),
      esqueleto_celula("118px", "75%", marca = "esqueleto__barra--selo")
    )
  }
  # Montando o cabeçalho com barras no lugar dos rótulos de cada coluna
  cabecalho <- list(
    esqueleto_celula("45px"),
    esqueleto_celula("88px", "26px", "7px", celula = "esqueleto__celula--direita"),
    esqueleto_celula(NULL, "58px", "7px"),
    esqueleto_celula("54px", "16px", "7px"),
    esqueleto_celula("84px", "30px", "7px", celula = "esqueleto__celula--direita"),
    esqueleto_celula("118px", "50px", "7px")
  )
  # Montando o corpo com a mesma quantidade de linhas da página real
  corpo <- lapply(seq_len(linhas), function(i) {
    htmltools::tags$div(class = "esqueleto__linha", celulas())
  })
  # Reproduzindo a sequência de botões da paginação real
  paginacao <- htmltools::tags$div(
    class = "esqueleto__paginacao",
    htmltools::tags$div(
      class = "esqueleto__paginacao-nav",
      esqueleto_barra("60px", "28px"),
      # Unindo os botões de página em uma única barra
      esqueleto_barra("147px", "28px"),
      # Reservando o lugar das reticências entre as páginas
      esqueleto_barra("10px", "6px", "esqueleto__barra--reticencias"),
      esqueleto_barra("40px", "28px"),
      esqueleto_barra("60px", "28px")
    )
  )
  htmltools::tags$div(
    class = "esqueleto esqueleto--ranking",
    `aria-hidden` = "true",
    # Reservando o campo de busca e a área da tabela
    htmltools::tags$div(class = "esqueleto__busca"),
    htmltools::tags$div(
      class = "esqueleto__tabela",
      # Mantendo a largura mínima real para reproduzir a rolagem horizontal
      htmltools::tags$div(
        class = "esqueleto__tabela-conteudo",
        htmltools::tags$div(class = "esqueleto__cabecalho", cabecalho),
        htmltools::tags$div(class = "esqueleto__corpo", corpo)
      )
    ),
    paginacao
  )
}

#' Definindo uma função que monta o esqueleto do leque de pétalas
#'
#' @return Elemento HTML com guias, pétalas e discos neutros.
#' Usada em: fct_esqueleto.R (esqueleto_palco).
#' @noRd
esqueleto_petalas <- function() {
  # Desenhando as seis pétalas com uma escala fixa e sem qualquer dado
  petalas <- lapply(seq_along(ANGULOS_PETALAS), function(i) {
    angulo <- ANGULOS_PETALAS[i]
    rad <- (angulo - 90) * (pi / 180)
    ponta_x <- round(PETALAS_CX + PETALAS_RAIO * cos(rad), 1)
    ponta_y <- round(PETALAS_CY + PETALAS_RAIO * sin(rad), 1)
    htmltools::tags$g(
      htmltools::tags$line(
        class = "esqueleto__guia",
        x1 = PETALAS_CX, y1 = PETALAS_CY, x2 = ponta_x, y2 = ponta_y
      ),
      htmltools::tags$path(
        class = "esqueleto__forma",
        d = sprintf(
          "M 0 0 C -26 -40, -28 -120, 0 -%s C 28 -120, 26 -40, 0 0 Z",
          PETALAS_COMPRIMENTO
        ),
        transform = sprintf(
          "translate(%s, %s) rotate(%s) scale(0.6)",
          PETALAS_CX, PETALAS_CY, angulo
        )
      ),
      # Mantendo os discos no fim das guias, como no gráfico real
      htmltools::tags$circle(
        class = "esqueleto__disco",
        cx = ponta_x, cy = ponta_y, r = 16
      )
    )
  })
  htmltools::tags$div(
    class = "petalas esqueleto esqueleto--petalas",
    `aria-hidden` = "true",
    htmltools::tags$div(
      class = "esqueleto__desenho",
      htmltools::tags$svg(
        viewBox = PETALAS_VIEWBOX,
        class = "svg-petalas",
        xmlns = "http://www.w3.org/2000/svg",
        htmltools::tags$circle(
          class = "esqueleto__centro",
          cx = PETALAS_CX, cy = PETALAS_CY, r = PETALAS_RAIO_CENTRO
        ),
        petalas
      )
    )
  )
}

#' Definindo uma função que monta o esqueleto das barras por bloco
#'
#' @return Elemento HTML com o título e seis barras neutras.
#' Usada em: fct_esqueleto.R (esqueleto_palco).
#' @noRd
esqueleto_barras_blocos <- function() {
  # Repetindo a estrutura de cada linha de barra sem qualquer valor
  linhas <- lapply(seq_along(BLOCOS$medida), function(i) {
    htmltools::tags$div(
      class = "resultado-blocos__linha",
      htmltools::tags$div(
        class = "resultado-blocos__cabecalho",
        htmltools::tags$span(
          class = "resultado-blocos__nome",
          esqueleto_barra("6rem", "0.55em")
        ),
        esqueleto_barra("2rem", "0.55em")
      ),
      htmltools::tags$div(
        class = "resultado-blocos__trilho",
        esqueleto_barra("100%", "100%")
      )
    )
  })
  htmltools::tags$div(
    class = "resultado-blocos esqueleto--barras",
    `aria-hidden` = "true",
    linhas
  )
}

#' Definindo uma função que monta o esqueleto do Índice VIDAS
#'
#' @return Elemento HTML com rótulo, valor e frase neutros.
#' Usada em: fct_esqueleto.R (esqueleto_palco).
#' @noRd
esqueleto_indice <- function() {
  # Mantendo a mesma divisão do bloco real do Índice VIDAS
  htmltools::tags$div(
    class = "perfil-indice",
    htmltools::tags$span(
      class = "perfil-indice__rotulo",
      esqueleto_barra("7.2rem", "0.55em")
    ),
    htmltools::tags$div(
      class = "perfil-indice__linha",
      htmltools::tags$span(
        class = "perfil-indice__valor",
        esqueleto_barra("4.5rem", "0.72em")
      ),
      htmltools::tags$span(
        class = "perfil-indice__escala",
        esqueleto_barra("3rem", "0.55em")
      ),
      esqueleto_barra("4.75rem", "1.3em", "esqueleto__barra--selo")
    ),
    # Reservando a frase do resultado em uma única linha, como no texto real
    htmltools::tags$p(
      class = "perfil-indice__frase",
      esqueleto_barra("16rem", "0.7em")
    ),
    # Reservando a régua de categorias e os rótulos dos extremos
    htmltools::tags$div(
      class = "perfil-indice__regua",
      htmltools::tags$div(
        class = "perfil-indice__trilho",
        esqueleto_barra("100%", "0.5rem")
      ),
      htmltools::tags$div(
        class = "perfil-indice__extremos",
        style = "min-height:1.5em;align-items:center;",
        esqueleto_barra("5rem", "0.65em"),
        esqueleto_barra("5rem", "0.65em")
      )
    )
  )
}

#' Definindo uma função que monta o esqueleto dos rankings do palco
#'
#' @return Elemento HTML com os três rankings neutros da base do palco.
#' Usada em: fct_esqueleto.R (esqueleto_palco).
#' @noRd
esqueleto_rankings <- function() {
  # Montando um item com rótulo, trilho e extremos neutros
  item <- function(classe, largura_rotulo) {
    htmltools::tags$div(
      class = paste("perfil-rankings__item", classe),
      htmltools::tags$span(
        class = "perfil-rankings__rotulo",
        esqueleto_barra(largura_rotulo, "0.65em")
      ),
      htmltools::tags$div(
        class = "perfil-rankings__trilho esqueleto__barra",
        style = "display:block;width:100%;height:0.25rem;",
        # Reservando o ponto que marca o início do trilho real
        htmltools::tags$span(
          class = "esqueleto__barra esqueleto__barra--ponto",
          style = paste0(
            "position:absolute;top:50%;left:0;width:0.75rem;height:0.75rem;",
            "transform:translate(-50%,-50%);"
          )
        )
      ),
      htmltools::tags$div(
        class = "perfil-rankings__extremos",
        style = "min-height:1.5em;align-items:center;",
        esqueleto_barra("3.4rem", "0.65em"),
        esqueleto_barra("3.6rem", "0.65em")
      )
    )
  }

  htmltools::tags$div(
    class = "perfil-rankings",
    item("perfil-rankings__item--macro", "5rem"),
    item("perfil-rankings__item--uf", "2.2rem"),
    item("perfil-rankings__item--brasil", "3rem")
  )
}

#' Definindo uma função que monta o esqueleto do palco de um município
#'
#' @return Elemento HTML com identificação, índice, pétalas e rankings neutros.
#' Usada em: mod_como.R (palcos principal e comparado).
#' @noRd
esqueleto_palco <- function() {
  # Reaproveitando as classes do palco real para herdar espaçamentos e fontes
  htmltools::tags$div(
    class = "painel-bloco painel-bloco--palco esqueleto esqueleto--palco",
    `aria-hidden` = "true",
    # O rótulo é exibido pelo CSS apenas quando o palco principal compara
    htmltools::tags$span(
      class = "palco-rotulo esqueleto__rotulo",
      esqueleto_barra("8rem", "0.55em")
    ),
    htmltools::tags$h3(
      class = "perfil-nome",
      esqueleto_barra("14rem", "0.55em")
    ),
    htmltools::tags$div(
      class = "perfil-metricas",
      esqueleto_metrica("3rem", "3.5rem"),
      esqueleto_metrica("1.6rem", "4.5rem"),
      esqueleto_metrica("7rem", "6rem"),
      esqueleto_metrica("6rem", "9rem")
    ),
    esqueleto_indice(),
    htmltools::tags$div(
      class = "perfil-palco__cabecalho",
      htmltools::tags$h4(
        class = "perfil-palco__titulo",
        esqueleto_barra("9.3rem", "0.65em")
      )
    ),
    htmltools::tags$div(
      class = "perfil-palco__graficos",
      htmltools::tags$div(
        class = "perfil-palco__coluna",
        esqueleto_petalas()
      ),
      htmltools::tags$div(
        class = "perfil-palco__coluna perfil-palco__coluna--barras",
        esqueleto_barras_blocos()
      )
    ),
    esqueleto_rankings()
  )
}

# Definindo as margens verticais do desenho dos esqueletos da evolução
ESQUELETO_GRAFICO_TOPO <- 16
ESQUELETO_GRAFICO_RODAPE <- 28

#' Definindo uma função que distribui as marcações do esqueleto na altura útil
#'
#' @return Frações da altura útil, uma por marcação do eixo Y dos gráficos.
#' Usada em: fct_esqueleto.R (esqueleto_grafico_margem e esqueleto_grafico_svg).
#' @noRd
fracoes_grade_esqueleto <- function() {
  seq(0, 1, length.out = MARCACOES_EIXO)
}

#' Definindo uma função que monta a coluna dos números do eixo Y do esqueleto
#'
#' @param altura Altura em pixels da área do gráfico.
#' @return Elemento HTML com as barras que reservam os números do eixo.
#' Usada em: fct_esqueleto.R (esqueleto_grade_evolucao).
#' @noRd
esqueleto_grafico_margem <- function(altura) {
  # Calculando a altura útil do gráfico, como no desenho real
  faixa <- altura - ESQUELETO_GRAFICO_TOPO - ESQUELETO_GRAFICO_RODAPE
  # Repetindo a mesma barra em todas as linhas para um ritmo uniforme
  barras <- lapply(fracoes_grade_esqueleto(), function(fracao) {
    htmltools::tags$span(
      class = "esqueleto__barra esqueleto__barra--rotulo",
      style = paste0(
        "top:", round(ESQUELETO_GRAFICO_TOPO + fracao * faixa, 1), "px;"
      )
    )
  })
  htmltools::tags$div(class = "esqueleto__grafico-margem", barras)
}

#' Definindo uma função que monta o desenho abstrato de um gráfico de linhas
#'
#' @param altura Altura em pixels da área do gráfico.
#' @return Elemento SVG com grade e traços de tendência.
#' Usada em: fct_esqueleto.R (esqueleto_grade_evolucao).
#' @noRd
esqueleto_grafico_svg <- function(altura) {
  # Reproduzindo as margens verticais usadas pelos gráficos reais
  topo <- ESQUELETO_GRAFICO_TOPO
  base <- altura - ESQUELETO_GRAFICO_RODAPE
  faixa <- base - topo

  # Desenhando a grade horizontal nas mesmas alturas dos números do eixo
  grade <- lapply(fracoes_grade_esqueleto(), function(fracao) {
    y <- round(topo + fracao * faixa, 1)
    htmltools::tags$line(class = "esqueleto__grade", x1 = 0, y1 = y, x2 = 100, y2 = y)
  })

  # Montando um traço de tendência a partir de frações da altura útil
  traco <- function(valores, classe = "esqueleto__traco") {
    xs <- round(seq(2, 99, length.out = length(valores)), 1)
    ys <- round(topo + valores * faixa, 1)
    htmltools::tags$polyline(
      class = classe,
      points = paste0(xs, ",", ys, collapse = " ")
    )
  }

  htmltools::tags$svg(
    class = "esqueleto__grafico-svg",
    viewBox = paste0("0 0 100 ", altura),
    preserveAspectRatio = "none",
    # Marcando só o eixo horizontal, como no gráfico real (sem linha vertical)
    htmltools::tags$line(class = "esqueleto__eixo", x1 = 0, y1 = base, x2 = 100, y2 = base),
    grade,
    traco(c(0.60, 0.48, 0.53, 0.34, 0.41, 0.16, 0.24)),
    traco(
      c(0.78, 0.71, 0.80, 0.62, 0.71, 0.52, 0.60),
      "esqueleto__traco esqueleto__traco--tracejado"
    )
  )
}

#' Definindo uma função que monta o esqueleto da grade de evolução temporal
#'
#' @return Elemento HTML com o cartão do Índice VIDAS e os seis cartões dos blocos.
#' Usada em: mod_como.R (esqueleto da grade da evolução).
#' @noRd
esqueleto_grade_evolucao <- function() {
  # Reproduzindo um cartão da evolução com a área reservada para o gráfico
  cartao <- function(classe, altura) {
    htmltools::tags$div(
      class = paste(
        c("evolucao-card esqueleto--card-evolucao", classe),
        collapse = " "
      ),
      htmltools::tags$h4(
        class = "evolucao-card__titulo",
        esqueleto_barra("7rem", "0.55em")
      ),
      htmltools::tags$div(
        class = "esqueleto__grafico",
        style = paste0("height:", altura, "px;"),
        # Reservando a coluna dos números do eixo Y, como no gráfico real
        esqueleto_grafico_margem(altura),
        esqueleto_grafico_svg(altura)
      )
    )
  }

  htmltools::tags$div(
    class = "evolucao-grade esqueleto esqueleto--grade-evolucao",
    `aria-hidden` = "true",
    cartao("evolucao-card--vidas", ALTURA_GRAFICO_VIDAS),
    htmltools::tags$h4(
      class = "evolucao-grade__titulo",
      esqueleto_barra("9rem", "0.55em")
    ),
    lapply(seq_len(nrow(BLOCOS)), function(i) {
      cartao("esqueleto--bloco", ALTURA_GRAFICO_BLOCO)
    })
  )
}

#' Definindo uma função que monta o esqueleto dos indicadores de um bloco
#'
#' @return Elemento HTML com os cartões dos indicadores do bloco padrão.
#' Usada em: mod_como.R (esqueleto da seção de indicadores).
#' @noRd
esqueleto_indicadores <- function() {
  # Reproduzindo um cartão de indicador com a área reservada para o gráfico
  cartao <- function() {
    altura <- ALTURA_GRAFICO_INDICADOR
    htmltools::tags$div(
      class = "indicador-card esqueleto--card-evolucao",
      htmltools::tags$div(
        class = "indicador-card__cabecalho",
        htmltools::tags$h4(
          class = "indicador-card__titulo",
          esqueleto_barra("7rem", "0.55em")
        ),
        # Reservando a chip do sentido de interpretação do indicador
        esqueleto_barra("4.5rem", "1.25em", "esqueleto__barra--selo")
      ),
      htmltools::tags$div(
        class = "esqueleto__grafico",
        style = paste0("height:", altura, "px;"),
        # Reservando a coluna dos números do eixo Y, como no gráfico real
        esqueleto_grafico_margem(altura),
        esqueleto_grafico_svg(altura)
      )
    )
  }

  htmltools::tags$div(
    class = "indicadores-grade esqueleto esqueleto--indicadores",
    `aria-hidden` = "true",
    # Reservando os cinco cartões do bloco padrão do seletor
    lapply(seq_len(5), function(i) cartao())
  )
}
