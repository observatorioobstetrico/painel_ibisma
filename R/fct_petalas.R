# =============================================================================
#   GRÁFICO DE PÉTALAS DOS SEIS BLOCOS
#   Constrói o leque de pétalas em SVG a partir da implementação da v3,
#   mantendo o valor de cada bloco em um disco fixo no fim da guia.
# =============================================================================

# Definindo os ângulos do leque simétrico em que as seis pétalas são distribuídas
ANGULOS_PETALAS <- c(-65, -39, -13, 13, 39, 65)

# Definindo o centro e o raio máximo do leque no sistema do viewBox
PETALAS_CX <- 250
PETALAS_CY <- 275
PETALAS_RAIO <- 185

# Definindo o comprimento do caminho base da pétala no sistema do viewBox
PETALAS_COMPRIMENTO <- 170

# Definindo o caminho base da pétala, compartilhado pela silhueta e pela forma real
PETALAS_CAMINHO <- sprintf(
  "M 0 0 C -26 -40, -28 -120, 0 -%s C 28 -120, 26 -40, 0 0 Z",
  PETALAS_COMPRIMENTO
)

# Definindo a escala da pétala na extensão máxima, usada pela silhueta de referência
PETALAS_ESCALA_MAXIMA <- PETALAS_RAIO / PETALAS_COMPRIMENTO

# Definindo a área visível do desenho, cortando as sobras de topo e laterais
PETALAS_VIEWBOX <- "45 60 410 236"

#' Definindo uma função que monta o conteúdo HTML do tooltip de uma pétala
#'
#' @param nome Nome do bloco.
#' @param valor Valor do bloco na escala 0 a 100.
#' @param categoria Categoria de vulnerabilidade do bloco.
#' @param pos_nac Posição do município no ranking nacional.
#' @param total_nac Total de municípios ranqueados.
#' @param medida Identificador do bloco que define a cor da dimensão.
#' @return Texto HTML pronto para o tooltip do Bootstrap.
#' Usada em: fct_petalas.R (petala_svg).
#' @noRd
tooltip_petala <- function(nome, valor, categoria, pos_nac, total_nac, medida) {
  # Montando o cartão com nome, valor, ranking e selo de categoria
  # O marcador ao lado do nome e o selo usam a rampa de cor da dimensão
  paste0(
    '<div class="tooltip-petala" style="--cor-medida:', cor_medida(medida), ';">',
    '<div class="tooltip-petala__titulo">',
    '<span class="tooltip-petala__marca"></span>', nome,
    "</div>",
    '<div class="tooltip-petala__linha">',
    '<span class="tooltip-petala__rotulo">Valor</span>',
    '<span class="tooltip-petala__valor">', formatar_numero(valor), "</span>",
    "</div>",
    '<div class="tooltip-petala__linha">',
    '<span class="tooltip-petala__rotulo">Ranking</span>',
    '<span class="tooltip-petala__valor">',
    rotulo_posicao(pos_nac, total_nac),
    "</span></div>",
    badge_categoria(categoria, cor = cor_categoria(categoria, medida)),
    "</div>"
  )
}

#' Definindo uma função que monta a transformação de uma pétala no leque
#'
#' @param angulo Ângulo da pétala no leque, em graus.
#' @param escala Fator de escala da pétala.
#' @return Texto da transformação SVG que posiciona a pétala.
#' Usada em: fct_petalas.R (petala_silhueta_svg e petala_svg).
#' @noRd
transformacao_petala <- function(angulo, escala) {
  # Posicionando a pétala no centro do leque, girada e escalada pelo valor
  sprintf(
    "translate(%s, %s) rotate(%s) scale(%s)",
    PETALAS_CX, PETALAS_CY, angulo, round(escala, 3)
  )
}

#' Definindo uma função que monta a silhueta de referência de uma pétala
#'
#' @param i Índice do bloco.
#' @return Elemento HTML com o caminho SVG da silhueta na extensão máxima.
#' Usada em: fct_petalas.R (grafico_petalas).
#' @noRd
petala_silhueta_svg <- function(i) {
  # Montando o caminho na extensão máxima; o cinza de referência fica no CSS
  htmltools::tags$path(
    d = PETALAS_CAMINHO,
    transform = transformacao_petala(ANGULOS_PETALAS[i], PETALAS_ESCALA_MAXIMA),
    class = "silhueta-petala"
  )
}

#' Definindo uma função que monta uma pétala individual do gráfico
#'
#' @param i Índice do bloco.
#' @param blocos Data frame com nome, valor, categoria, cor e ranking dos blocos.
#' @return Elemento HTML com o grupo SVG da pétala.
#' Usada em: fct_petalas.R (grafico_petalas).
#' @noRd
petala_svg <- function(i, blocos) {
  # Extraindo os dados e calculando os fatores de escala da pétala
  nome <- as.character(blocos$nome[i])
  valor <- blocos$valor[i]
  if (is.na(valor)) valor <- 0
  cor <- blocos$cor[i]
  angulo <- ANGULOS_PETALAS[i]
  # Escalando a pétala para a ponta percorrer a guia na escala do disco
  escala <- (valor / 100) * PETALAS_ESCALA_MAXIMA

  # Convertendo o ângulo do leque em radianos para posicionar os elementos
  rad <- (angulo - 90) * (pi / 180)

  # Mantendo o disco do valor no fim da guia, onde a escala indica 100
  ponta_x <- round(PETALAS_CX + PETALAS_RAIO * cos(rad), 1)
  ponta_y <- round(PETALAS_CY + PETALAS_RAIO * sin(rad), 1)

  # Montando o grupo com guia, pétala, valor e tooltip
  htmltools::tags$g(
    class = "grupo-petala",
    `data-bs-toggle` = "tooltip",
    `data-bs-placement` = "top",
    tabindex = "0",
    title = tooltip_petala(
      nome, blocos$valor[i], blocos$categoria[i],
      blocos$pos_nac[i], blocos$total_nac[i], blocos$medida[i]
    ),
    # Linha guia pontilhada que sustenta a escala da pétala
    htmltools::tags$line(
      x1 = PETALAS_CX,
      y1 = PETALAS_CY,
      x2 = ponta_x,
      y2 = ponta_y,
      stroke = "#E2E5EA",
      `stroke-width` = 1.5,
      `stroke-dasharray` = "2,3"
    ),
    # Forma da pétala rotacionada e escalada pelo valor do bloco
    htmltools::tags$path(
      d = PETALAS_CAMINHO,
      fill = cor,
      `fill-opacity` = 0.82,
      stroke = cor,
      `stroke-width` = 1.2,
      transform = transformacao_petala(angulo, escala),
      class = "forma-petala"
    ),
    # Círculo com o valor em uma casa decimal no topo fixo da guia
    htmltools::tags$circle(
      cx = ponta_x,
      cy = ponta_y,
      r = 16,
      fill = cor,
      stroke = "#FFFFFF",
      `stroke-width` = 2,
      class = "circulo-nota"
    ),
    htmltools::tags$text(
      x = ponta_x,
      y = ponta_y + 3.4,
      `text-anchor` = "middle",
      fill = cor_texto_sobre(cor),
      `font-size` = "9.5px",
      `font-weight` = "700",
      `font-family` = "Source Sans Pro, system-ui, sans-serif",
      formatar_numero(valor)
    )
  )
}

#' Definindo uma função que monta o gráfico de pétalas dos seis blocos do IBISMA
#'
#' @param blocos Data frame com nome, valor, categoria, cor e ranking dos blocos.
#' @return Elemento HTML com o leque de pétalas e as legendas de apoio.
#' Usada em: fct_perfil.R (palco do município).
#' @noRd
grafico_petalas <- function(blocos) {
  # Garantindo que os nomes cheguem como texto
  blocos$nome <- as.character(blocos$nome)
  # Descobrindo a medida de cada pétala quando ela não vier pronta
  if (is.null(blocos$medida)) {
    blocos$medida <- MEDIDAS$medida[match(blocos$nome, MEDIDAS$nome)]
  }
  # Preenchendo a cor de identificação a partir da medida quando necessário
  if (is.null(blocos$cor)) {
    blocos$cor <- cor_medida(blocos$medida)
  }

  # Empilhando todas as silhuetas de referência em uma camada única
  silhuetas <- lapply(seq_len(nrow(blocos)), function(i) {
    petala_silhueta_svg(i)
  })

  # Montando cada pétala na ordem dos seis blocos do painel
  petalas <- lapply(seq_len(nrow(blocos)), function(i) {
    petala_svg(i, blocos)
  })

  # Montando o disco central que sustenta o leque
  centro <- htmltools::tags$circle(
    cx = PETALAS_CX,
    cy = PETALAS_CY,
    r = 8,
    fill = "#0A1E3C",
    stroke = "#FFFFFF",
    `stroke-width` = 2
  )

  # Nomeando cada bloco na legenda para identificar as pétalas sem hover
  itens_legenda <- lapply(seq_len(nrow(blocos)), function(i) {
    htmltools::tags$span(
      class = "petalas-legenda__item",
      htmltools::tags$span(
        class = "petalas-legenda__cor",
        style = paste0("background:", blocos$cor[i], ";")
      ),
      as.character(blocos$nome[i])
    )
  })

  # Montando o contêiner final com o SVG responsivo
  htmltools::tags$div(
    class = "petalas",
    htmltools::tags$svg(
      viewBox = PETALAS_VIEWBOX,
      class = "svg-petalas",
      xmlns = "http://www.w3.org/2000/svg",
      `role` = "img",
      `aria-label` = "Leque com os seis blocos do IBISMA",
      # Desenhando a camada de referência antes das pétalas para ficar por baixo
      htmltools::tags$g(class = "camada-silhuetas", silhuetas),
      centro,
      petalas
    ),
    htmltools::tags$div(class = "petalas-legenda", itens_legenda)
  )
}
