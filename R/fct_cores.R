# =============================================================================
#   FUNÇÕES DE COR DO PAINEL
#   Deriva as cores de identificação e de categoria a partir das constantes de
#   R/constantes.R, mistura tons para os destaques e escolhe a cor de texto
#   com melhor contraste. Nenhum valor hexadecimal mora aqui.
# =============================================================================

#' Definindo uma função que obtém a cor de identificação de uma ou mais medidas
#'
#' @param medida Vetor de identificadores de medida ("indice_final", "bloco1"...).
#' @return Vetor de cores em hexadecimal, na mesma ordem da entrada.
#' Usada em: fct_graficos_evolucao.R, fct_petalas.R, mod_como.R (resumo dos blocos) e mod_onde.R (tema do ranking).
#' @noRd
cor_medida <- function(medida) {
  # Buscando a cor de cada medida no dicionário
  MEDIDAS$cor[match(medida, MEDIDAS$medida)]
}

#' Definindo uma função que obtém a cor do traço de uma medida nos gráficos
#'
#' @param medida Identificador de medida ("indice_final", "bloco1"...).
#' @return Cor do traço em hexadecimal, escurecendo o amarelo do Social.
#' Usada em: fct_graficos_evolucao.R (evolução das medidas e dos indicadores).
#' @noRd
cor_linha_medida <- function(medida) {
  # Escurecendo o traço do Social, cujo amarelo some em linha fina sobre o branco
  if (identical(medida, "bloco1")) {
    return(COR_LINHA_SOCIAL)
  }
  cor_medida(medida)
}

#' Definindo uma função que obtém a cor de uma faixa do Índice VIDAS
#'
#' @param categoria Vetor de categorias ("Muito baixo" ... "Muito alto").
#' @param medida Identificador da medida que define a rampa de cores.
#' @return Vetor de cores em hexadecimal, com cinza para valores ausentes.
#' Usada em: fct_mapa.R (cores e tooltip do mapa), fct_petalas.R (tooltip da pétala) e fct_ui.R (selos de categoria).
#' @noRd
cor_categoria <- function(categoria, medida = "indice_final") {
  # Buscando cada categoria na rampa da medida e tratando valores sem dado
  paleta <- PALETAS[[medida]]
  cores <- unname(paleta[categoria])
  ifelse(is.na(cores), COR_SEM_DADOS, cores)
}

#' Definindo uma função que escolhe a cor de texto com melhor contraste sobre um fundo
#'
#' @param cor Cor de fundo em hexadecimal.
#' @return "#FFFFFF" para fundos escuros e a cor azul escura para fundos claros.
#' Usada em: fct_mapa.R (tooltip do mapa), fct_petalas.R (disco da pétala), mod_onde.R (tema do ranking) e fct_ui.R (selos de categoria).
#' @noRd
cor_texto_sobre <- function(cor) {
  # Calculando a luminância relativa do fundo informado
  rgb <- grDevices::col2rgb(cor) / 255
  luminancia <- 0.2126 * rgb[1, ] + 0.7152 * rgb[2, ] + 0.0722 * rgb[3, ]
  unname(ifelse(luminancia > 0.55, COR_AZUL_ESCURO, "#FFFFFF"))
}

#' Definindo uma função que mistura duas cores em hexadecimal
#'
#' @param cor1 Cor de partida em hexadecimal.
#' @param cor2 Cor de chegada em hexadecimal.
#' @param peso Peso da segunda cor na mistura (0 a 1).
#' @return Cor resultante em hexadecimal.
#' Usada em: mod_onde.R (tema do ranking).
#' @noRd
misturar_cores <- function(cor1, cor2, peso) {
  # Convertendo as duas cores para canais RGB e aplicando a mistura ponderada
  rgb1 <- grDevices::col2rgb(cor1)
  rgb2 <- grDevices::col2rgb(cor2)
  misto <- round((1 - peso) * rgb1 + peso * rgb2)
  grDevices::rgb(misto[1], misto[2], misto[3], maxColorValue = 255)
}
