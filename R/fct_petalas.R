# =============================================================================
#   GRÁFICO DE PÉTALAS DOS SEIS BLOCOS
#   Constrói o leque de pétalas em SVG a partir da implementação da v3,
#   mantendo o valor de cada bloco em um disco fixo no fim da guia.
# =============================================================================

# Definindo os ângulos do leque simétrico em que as seis pétalas são distribuídas
# Abrindo o leque até perto da horizontal para reduzir a sobreposição entre pétalas
ANGULOS_PETALAS <- c(-80, -48, -16, 16, 48, 80)

# Definindo o centro e o raio máximo do leque no sistema do viewBox
PETALAS_CX <- 250
PETALAS_CY <- 275
PETALAS_RAIO <- 185

# Definindo o raio do disco azul escuro que sustenta o leque
PETALAS_RAIO_CENTRO <- 6

# Definindo o comprimento do caminho base da pétala no sistema do viewBox
PETALAS_COMPRIMENTO <- 170

# Definindo os rótulos exibidos diretamente junto de cada pétala
ROTULOS_PETALAS <- c(
  bloco1 = "Social",
  bloco2 = "Planejamento\nReprodutivo",
  bloco3 = "Pré-natal",
  bloco4 = "Parto",
  bloco5 = "Sistema de Saúde",
  bloco6 = "Clima"
)

# Definindo o caminho base da pétala, compartilhado pela silhueta e pela forma real
PETALAS_CAMINHO <- sprintf(
  "M 0 0 C -26 -40, -28 -120, 0 -%s C 28 -120, 26 -40, 0 0 Z",
  PETALAS_COMPRIMENTO
)

# Definindo a escala da pétala na extensão máxima, usada pela silhueta de referência
PETALAS_ESCALA_MAXIMA <- PETALAS_RAIO / PETALAS_COMPRIMENTO

# Definindo a área visível do desenho, com espaço para os rótulos das pétalas
PETALAS_VIEWBOX <- "0 45 500 260"

#' Definindo uma função que escolhe o rótulo de uma pétala
#'
#' @param medida Identificador do bloco ("bloco1"..."bloco6").
#' @param nome Nome completo do bloco, usado quando não houver rótulo próprio.
#' @return Texto exibido junto da pétala, com quebras de linha quando houver.
#' Usada em: fct_petalas.R (petala_svg).
#' @noRd
rotulo_petala <- function(medida, nome) {
  # Buscando o rótulo do bloco e mantendo o nome completo como reserva
  rotulo <- unname(ROTULOS_PETALAS[as.character(medida)])
  ifelse(is.na(rotulo), as.character(nome), rotulo)
}

#' Definindo uma função que monta o rodapé com município e ano dos tooltips
#'
#' @param contexto Texto com o município e o ano (opcional).
#' @return Linha HTML discreta ou texto vazio.
#' Usada em: fct_petalas.R (tooltip_petala) e fct_perfil.R (tooltip_ranking e tooltip_indice).
#' @noRd
contexto_tooltip <- function(contexto = NULL) {
  if (is.null(contexto) || is.na(contexto) || !nzchar(contexto)) {
    return("")
  }
  paste0(
    '<div class="tooltip-petala__contexto">',
    htmltools::htmlEscape(contexto),
    "</div>"
  )
}

#' Definindo uma função que monta o conteúdo HTML do tooltip de uma pétala
#'
#' @param nome Nome do bloco.
#' @param valor Valor do bloco na escala 0 a 100.
#' @param categoria Faixa do Índice VIDAS no bloco.
#' @param pos_nac Posição do município no ranking nacional.
#' @param total_nac Total de municípios ranqueados.
#' @param medida Identificador do bloco que define a cor da dimensão.
#' @param contexto Texto com o município e o ano (opcional).
#' @return Texto HTML pronto para o tooltip do Bootstrap.
#' Usada em: fct_petalas.R (petala_svg) e fct_perfil.R (grafico_barras_blocos).
#' @noRd
tooltip_petala <- function(nome, valor, categoria, pos_nac, total_nac, medida,
                           contexto = NULL) {
  # Montando o cartão com nome, valor, categoria e ranking
  # O marcador ao lado do nome e o selo usam a rampa de cor da dimensão
  paste0(
    '<div class="tooltip-petala" style="--cor-medida:', cor_medida(medida), ';">',
    contexto_tooltip(contexto),
    '<div class="tooltip-petala__titulo">',
    '<span class="tooltip-petala__marca"></span>', nome,
    "</div>",
    '<div class="tooltip-petala__linha">',
    '<span class="tooltip-petala__rotulo">Valor</span>',
    '<span class="tooltip-petala__resultado">',
    '<span class="tooltip-petala__valor">', formatar_numero(valor), "</span>",
    # Colocando o selo na mesma linha do valor para deixar clara a relação
    badge_categoria(categoria, cor = cor_categoria(categoria, medida)),
    "</span>",
    "</div>",
    '<div class="tooltip-petala__linha">',
    '<span class="tooltip-petala__rotulo">Prioridade</span>',
    '<span class="tooltip-petala__valor">',
    rotulo_posicao(pos_nac, total_nac),
    "</span></div>",
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

#' Definindo uma função que monta a guia pontilhada de uma pétala
#'
#' @param i Índice do bloco.
#' @return Elemento HTML com a linha guia da pétala.
#' Usada em: fct_petalas.R (grafico_petalas).
#' @noRd
guia_petala_svg <- function(i) {
  # Calculando a ponta da guia na escala máxima do leque
  angulo <- ANGULOS_PETALAS[i]
  rad <- (angulo - 90) * (pi / 180)
  ponta_x <- round(PETALAS_CX + PETALAS_RAIO * cos(rad), 1)
  ponta_y <- round(PETALAS_CY + PETALAS_RAIO * sin(rad), 1)

  htmltools::tags$line(
    class = "guia-petala",
    x1 = PETALAS_CX,
    y1 = PETALAS_CY,
    x2 = ponta_x,
    y2 = ponta_y,
    stroke = "#E2E5EA",
    `stroke-width` = 1.5,
    `stroke-dasharray` = "2,3"
  )
}

#' Definindo uma função que monta uma pétala individual do gráfico
#'
#' @param i Índice do bloco.
#' @param blocos Data frame com nome, valor, categoria, cor e ranking dos blocos.
#' @param contexto Texto com o município e o ano (opcional).
#' @return Elemento HTML com o grupo SVG da pétala.
#' Usada em: fct_petalas.R (grafico_petalas).
#' @noRd
petala_svg <- function(i, blocos, contexto = NULL) {
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

  # Posicionando o rótulo do bloco um pouco além do disco do valor
  rotulo_raio <- PETALAS_RAIO + 25
  rotulo_x <- round(PETALAS_CX + rotulo_raio * cos(rad), 1)
  rotulo_y <- round(PETALAS_CY + rotulo_raio * sin(rad), 1)
  # Alinhando o rótulo para fora nos blocos laterais e ao centro nos demais
  rotulo_ancora <- if (angulo > 30) "start" else if (angulo < -30) "end" else "middle"

  # Quebrando o rótulo em linhas para os blocos com nomes longos
  linhas_rotulo <- strsplit(
    rotulo_petala(blocos$medida[i], nome), "\n", fixed = TRUE
  )[[1]]

  # Centralizando as linhas seguintes em relação à primeira linha do rótulo
  ancoras_rotulo <- rep(rotulo_ancora, length(linhas_rotulo))
  deslocamentos_rotulo <- rep("0", length(linhas_rotulo))
  if (length(linhas_rotulo) > 1) {
    # Estimando a largura da primeira linha em em para achar o centro do bloco
    largura_em <- nchar(linhas_rotulo[1]) * 0.52
    ancoras_rotulo[-1] <- "middle"
    deslocamentos_rotulo[-1] <- paste0(
      if (rotulo_ancora == "start") largura_em / 2 else -largura_em / 2,
      "em"
    )
  }

  tspans_rotulo <- lapply(seq_along(linhas_rotulo), function(j) {
    htmltools::tags$tspan(
      x = rotulo_x,
      dx = deslocamentos_rotulo[j],
      dy = if (j == 1) {
        if (length(linhas_rotulo) > 1) "-0.6em" else "0"
      } else {
        "1.2em"
      },
      `text-anchor` = ancoras_rotulo[j],
      linhas_rotulo[j]
    )
  })

  # Montando o grupo com guia, pétala, valor, rótulo e tooltip
  htmltools::tags$g(
    class = "grupo-petala",
    `data-bs-toggle` = "tooltip",
    `data-bs-placement` = "top",
    tabindex = "0",
    title = tooltip_petala(
      nome, blocos$valor[i], blocos$categoria[i],
      blocos$pos_nac[i], blocos$total_nac[i], blocos$medida[i],
      contexto = contexto
    ),
    # Cobrindo todo o leque com uma área invisível para facilitar o hover
    htmltools::tags$path(
      d = PETALAS_CAMINHO,
      transform = transformacao_petala(angulo, PETALAS_ESCALA_MAXIMA),
      class = "area-petala"
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
    ),
    # Nome do bloco posicionado fora do disco, sem a legenda abaixo
    htmltools::tags$text(
      x = rotulo_x,
      y = rotulo_y,
      `text-anchor` = rotulo_ancora,
      `dominant-baseline` = "middle",
      class = "rotulo-petala",
      tspans_rotulo
    )
  )
}

#' Definindo uma função que monta o gráfico de pétalas dos seis blocos do Índice VIDAS
#'
#' @param blocos Data frame com nome, valor, categoria, cor e ranking dos blocos.
#' @param contexto Texto com o município e o ano (opcional).
#' @return Elemento HTML com o leque de pétalas e as legendas de apoio.
#' Usada em: fct_perfil.R (palco do município).
#' @noRd
grafico_petalas <- function(blocos, contexto = NULL) {
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

  # Montando as guias em uma camada própria para ficarem sob o disco central
  guias <- lapply(seq_len(nrow(blocos)), function(i) {
    guia_petala_svg(i)
  })

  # Montando cada pétala na ordem dos seis blocos do painel
  petalas <- lapply(seq_len(nrow(blocos)), function(i) {
    petala_svg(i, blocos, contexto = contexto)
  })

  # Montando o disco central que sustenta o leque
  centro <- htmltools::tags$circle(
    cx = PETALAS_CX,
    cy = PETALAS_CY,
    r = PETALAS_RAIO_CENTRO,
    fill = "#0A1E3C",
    stroke = "#FFFFFF",
    `stroke-width` = 2
  )

  # Montando o contêiner final com o SVG responsivo
  htmltools::tags$div(
    class = "petalas",
    htmltools::tags$svg(
      viewBox = PETALAS_VIEWBOX,
      class = "svg-petalas",
      xmlns = "http://www.w3.org/2000/svg",
      `role` = "img",
      `aria-label` = "Leque com as seis dimensões do Índice VIDAS",
      # Desenhando as fantasmas e as guias antes do centro para ficarem por baixo
      htmltools::tags$g(class = "camada-silhuetas", silhuetas),
      htmltools::tags$g(class = "camada-guias", guias),
      # Cobrindo as pontas das guias e das fantasmas sem esconder as pétalas reais
      centro,
      petalas
    )
  )
}
