# =============================================================================
#   COMPONENTES DO PERFIL DO MUNICÍPIO
#   Monta o palco de um município — identificação, índice, pétalas dos seis
#   blocos e rankings — de forma reutilizável para o município principal e para
#   o município de comparação.
# =============================================================================

#' Definindo uma função que cria uma métrica do cabeçalho do perfil
#'
#' @param rotulo Rótulo da métrica.
#' @param valor Valor principal já formatado.
#' @param detalhe Texto auxiliar (opcional).
#' @param tooltip Guarda o texto completo para o tooltip exibido quando cortado.
#' @return Elemento HTML da métrica.
#' Usada em: perfil_palco() (métricas territoriais) e perfil_rankings() (rankings).
#' @noRd
metrica_hero <- function(rotulo, valor, detalhe = NULL, tooltip = FALSE) {
  # Montando um campo que expõe o próprio texto para o tooltip condicional
  montar_campo <- function(classe, texto) {
    if (!tooltip) {
      return(htmltools::tags$span(class = classe, texto))
    }
    htmltools::tags$span(
      class = paste(classe, "metrica-tooltip"),
      `data-tooltip-texto` = texto,
      texto
    )
  }

  htmltools::tags$div(
    class = "metrica",
    montar_campo("metrica-rotulo", rotulo),
    montar_campo("metrica-valor", valor),
    if (!is.null(detalhe)) {
      htmltools::tags$span(class = "metrica-detalhe", detalhe)
    }
  )
}

#' Definindo uma função que produz a frase de leitura do percentil do Índice VIDAS
#'
#' @param valor Valor do índice na escala 0 a 100.
#' @param pos_nac Posição do município no ranking nacional (opcional).
#' @param total_nac Total de municípios ranqueados (opcional).
#' @return Texto comparando o município aos demais municípios brasileiros.
#' Usada em: perfil_indice().
#' @noRd
frase_percentil <- function(valor, pos_nac = NULL, total_nac = NULL) {
  ## Obs.: este bloco usa funções auxiliares de fct_dados.
  if (is.na(valor)) {
    return("Sem dado disponível para este ano.")
  }
  # Destacando os extremos do ranking, que definem as prioridades do índice
  if (!is.null(pos_nac) && !is.null(total_nac) &&
      !is.na(pos_nac) && !is.na(total_nac)) {
    if (pos_nac == 1) {
      return("Menor VIDA entre todos os municípios brasileiros")
    }
    if (pos_nac == total_nac) {
      return("Maior VIDA entre todos os municípios brasileiros")
    }
  }
  # Mostrando a parcela de municípios que está abaixo deste no índice
  paste0(
    "Maior VIDA que ",
    formatar_numero(valor),
    "% dos municípios brasileiros"
  )
}

#' Definindo uma função que calcula a posição de um ponto no trilho do ranking
#'
#' @param posicao Posição do município (1 = pior).
#' @param total Número de municípios avaliados.
#' @return Percentual de 0 a 100 da posição no trilho.
#' Usada em: fct_perfil.R (perfil_ranking_item).
#' @noRd
posicao_trilho <- function(posicao, total) {
  # Colocando o pior à esquerda e o melhor à direita do trilho
  if (is.na(posicao) || is.na(total) || total <= 1) {
    return(100)
  }
  max(0, min(100, 100 * (posicao - 1) / (total - 1)))
}

#' Definindo uma função que monta a régua de categorias do Índice VIDAS
#'
#' @param valor Valor do índice na escala 0 a 100.
#' @return Elemento HTML com as cinco faixas e o marcador do município.
#' Usada em: perfil_indice().
#' @noRd
regua_indice <- function(valor) {
  ## Obs.: este bloco usa funções auxiliares de fct_dados.
  # Usando a rampa do índice da faixa mais baixa para a mais alta
  faixas <- lapply(unname(PALETAS$indice_final), function(cor) {
    htmltools::tags$span(
      class = "perfil-indice__faixa",
      style = paste0("background:", cor, ";")
    )
  })

  # Posicionando o marcador na escala de 0 a 100
  marcador <- if (is.na(valor)) {
    NULL
  } else {
    htmltools::tags$span(
      class = "perfil-indice__marcador",
      style = sprintf("left:%.1f%%;", max(0, min(100, valor))),
      `aria-hidden` = "true"
    )
  }

  # Montando a régua com os rótulos dos extremos
  htmltools::tags$div(
    class = "perfil-indice__regua",
    `role` = "img",
    `aria-label` = paste0(
      "Posição do município na escala do Índice VIDAS: ",
      formatar_numero(valor), " de 100"
    ),
    htmltools::tags$div(
      class = "perfil-indice__trilho",
      htmltools::tags$div(class = "perfil-indice__faixas", faixas),
      marcador
    ),
    htmltools::tags$div(
      class = "perfil-indice__extremos",
      htmltools::tags$span("0 · muito baixo"),
      htmltools::tags$span("100 · muito alto")
    )
  )
}

#' Definindo uma função que monta o conteúdo do tooltip da régua do índice
#'
#' @param resumo Lista retornada por resumo_municipio().
#' @param contexto Texto com o município e o ano (opcional).
#' @return Texto HTML com valor, categoria e leitura do percentil.
#' Usada em: perfil_indice().
#' @noRd
tooltip_indice <- function(resumo, contexto = NULL) {
  ## Obs.: este bloco usa funções auxiliares de fct_ui, fct_dados e fct_perfil.
  paste0(
    '<div class="tooltip-petala" style="--cor-medida:', COR_VIDAS, ';">',
    contexto_tooltip(contexto),
    '<div class="tooltip-petala__titulo">',
    '<span class="tooltip-petala__marca"></span>Índice VIDAS',
    "</div>",
    '<div class="tooltip-petala__linha">',
    '<span class="tooltip-petala__rotulo">Valor</span>',
    '<span class="tooltip-petala__resultado">',
    '<span class="tooltip-petala__valor">', formatar_numero(resumo$valor), "</span>",
    badge_categoria(resumo$categoria),
    "</span>",
    "</div>",
    '<div class="tooltip-petala__frase">',
    frase_percentil(resumo$valor, resumo$pos_nac, resumo$total_nac),
    "</div>",
    "</div>"
  )
}

#' Definindo uma função que monta o bloco do índice do município
#'
#' @param resumo Lista retornada por resumo_municipio().
#' @param ano Ano de referência exibido no rótulo do valor.
#' @param contexto Texto com o município e o ano (opcional).
#' @return Elemento HTML com rótulo, valor, categoria e leitura do percentil.
#' Usada em: perfil_palco().
#' @noRd
perfil_indice <- function(resumo, ano, contexto = NULL) {
  ## Obs.: este bloco usa funções auxiliares de fct_ui, fct_dados e fct_perfil.
  # Tornando a régua interativa com a leitura completa do índice
  regua <- htmltools::tagAppendAttributes(
    regua_indice(resumo$valor),
    `data-bs-toggle` = "tooltip",
    `data-bs-placement` = "top",
    tabindex = "0",
    title = tooltip_indice(resumo, contexto)
  )

  htmltools::tags$div(
    class = "perfil-indice",
    # Nomeando o valor em destaque, com a categoria e a leitura do percentil
    htmltools::tags$span(
      class = "perfil-indice__rotulo",
      paste0("Índice VIDAS em ", ano)
    ),
    htmltools::tags$div(
      class = "perfil-indice__linha",
      htmltools::tags$span(
        class = "perfil-indice__valor",
        # Todos os valores do painel são exibidos com uma casa decimal
        formatar_numero(resumo$valor)
      ),
      htmltools::tags$span(class = "perfil-indice__escala", "de 100"),
      badge_categoria(resumo$categoria)
    ),
    htmltools::tags$p(
      class = "perfil-indice__frase",
      frase_percentil(resumo$valor, resumo$pos_nac, resumo$total_nac)
    ),
    # Mostrando a régua com as categorias e a posição do município no índice
    regua
  )
}

#' Definindo uma função que separa o destaque da posição no ranking
#'
#' @param posicao Posição do município (1 = menor VIDA).
#' @param total Número de municípios avaliados.
#' @return Lista com o trecho em destaque e o complemento da frase.
#' Usada em: fct_perfil.R (frase_ranking e tooltip_ranking).
#' @noRd
partes_ranking <- function(posicao, total) {
  ## Obs.: este bloco usa funções auxiliares de fct_dados.
  if (is.na(posicao) || is.na(total)) {
    return(list(destaque = "Sem dados", complemento = ""))
  }
  # Ajustando o plural quando o escopo tem um único município
  municipios <- if (total == 1) "município" else "municípios"
  complemento <- paste0("entre ", formatar_inteiro(total), " ", municipios)
  if (posicao == 1) {
    return(list(destaque = "Menor VIDA", complemento = complemento))
  }
  if (posicao == total) {
    return(list(destaque = "Maior VIDA", complemento = complemento))
  }
  list(
    destaque = paste0(formatar_inteiro(posicao), "ª menor VIDA"),
    complemento = complemento
  )
}

#' Definindo uma função que descreve a posição no ranking
#'
#' @param posicao Posição do município (1 = menor VIDA).
#' @param total Número de municípios avaliados.
#' @return Texto com o menor, o maior ou a posição intermediária.
#' Usada em: fct_perfil.R (perfil_ranking_item).
#' @noRd
frase_ranking <- function(posicao, total) {
  ## Obs.: este bloco usa funções auxiliares de fct_perfil.
  partes <- partes_ranking(posicao, total)
  trimws(paste(partes$destaque, partes$complemento))
}

#' Definindo uma função que monta o conteúdo do tooltip de um ranking
#'
#' @param rotulo Rótulo do ranking.
#' @param posicao Posição do município (1 = menor VIDA).
#' @param total Número de municípios avaliados.
#' @param escopo Nome do território avaliado (opcional).
#' @param contexto Texto com o município e o ano (opcional).
#' @return Texto HTML com a posição e o escopo do ranking.
#' Usada em: fct_perfil.R (perfil_ranking_item).
#' @noRd
tooltip_ranking <- function(rotulo, posicao, total, escopo = NULL,
                            contexto = NULL) {
  ## Obs.: este bloco usa funções auxiliares de fct_perfil.
  # Incluindo o nome do território no título quando houver
  titulo <- if (!is.null(escopo) && !is.na(escopo) && nzchar(escopo)) {
    paste0(rotulo, " (", escopo, ")")
  } else {
    rotulo
  }
  partes <- partes_ranking(posicao, total)
  # Montando o cartão com o título e a leitura da posição
  paste0(
    '<div class="tooltip-petala" style="--cor-medida:', COR_VIDAS, ';">',
    contexto_tooltip(contexto),
    '<div class="tooltip-petala__titulo">',
    '<span class="tooltip-petala__marca"></span>', titulo,
    "</div>",
    '<div class="tooltip-petala__frase">',
    "<strong>", partes$destaque, "</strong> ", partes$complemento,
    "</div>",
    "</div>"
  )
}

#' Definindo uma função que monta um item de ranking com trilho de posição
#'
#' @param rotulo Rótulo do ranking.
#' @param posicao Posição do município (1 = menor VIDA).
#' @param total Número de municípios avaliados.
#' @param classe Classe extra do item na grade.
#' @param escopo Nome do território avaliado (opcional).
#' @param contexto Texto com o município e o ano (opcional).
#' @return Elemento HTML com rótulo, trilho e extremos.
#' Usada em: perfil_rankings().
#' @noRd
perfil_ranking_item <- function(rotulo, posicao, total, classe, escopo = NULL,
                                contexto = NULL) {
  ## Obs.: este bloco usa funções auxiliares de fct_dados e fct_perfil.
  # Calculando a posição do ponto no trilho, do pior ao melhor
  posicao_ponto <- posicao_trilho(posicao, total)
  # Montando o ponto apenas quando houver posição válida
  ponto <- if (is.na(posicao)) {
    NULL
  } else {
    htmltools::tags$span(
      class = "perfil-rankings__ponto",
      style = sprintf("left:%.1f%%;", posicao_ponto)
    )
  }
  # Montando o título com o escopo para a leitura acessível
  titulo <- if (!is.null(escopo) && !is.na(escopo) && nzchar(escopo)) {
    paste0(rotulo, " (", escopo, ")")
  } else {
    rotulo
  }

  htmltools::tags$div(
    class = paste("perfil-rankings__item", classe),
    htmltools::tags$span(class = "perfil-rankings__rotulo", rotulo),
    # Desenhando o trilho com o ponto na posição do município
    htmltools::tags$div(
      class = "perfil-rankings__trilho",
      `data-bs-toggle` = "tooltip",
      `data-bs-placement` = "top",
      tabindex = "0",
      `aria-label` = paste0(titulo, ": ", frase_ranking(posicao, total)),
      title = tooltip_ranking(rotulo, posicao, total, escopo, contexto),
      ponto
    ),
    htmltools::tags$div(
      class = "perfil-rankings__extremos",
      htmltools::tags$span("menor VIDA"),
      htmltools::tags$span("maior VIDA")
    )
  )
}

#' Definindo uma função que monta os rankings do município
#'
#' @param resumo Lista retornada por resumo_municipio().
#' @param contexto Texto com o município e o ano (opcional).
#' @return Elemento HTML com os rankings da macrorregião, da UF e do Brasil.
#' Usada em: perfil_palco().
#' @noRd
perfil_rankings <- function(resumo, contexto = NULL) {
  ## Obs.: este bloco usa funções auxiliares de fct_dados e fct_perfil.
  htmltools::tags$div(
    class = "perfil-rankings",
    # Ranking da macrorregião de saúde à esquerda do palco
    perfil_ranking_item(
      "Na macrorregião",
      resumo$pos_macro,
      resumo$total_macro,
      "perfil-rankings__item--macro",
      escopo = resumo$macro_r_saude,
      contexto = contexto
    ),
    # Ranking estadual ao centro do palco
    perfil_ranking_item(
      "Na UF",
      resumo$pos_uf,
      resumo$total_uf,
      "perfil-rankings__item--uf",
      escopo = resumo$uf,
      contexto = contexto
    ),
    # Ranking nacional à direita do palco
    perfil_ranking_item(
      "No Brasil",
      resumo$pos_nac,
      resumo$total_nac,
      "perfil-rankings__item--brasil",
      contexto = contexto
    )
  )
}

#' Definindo uma função que monta as barras do resultado por bloco
#'
#' @param blocos Data frame com nome, valor e cor dos blocos.
#' @param contexto Texto com o município e o ano (opcional).
#' @return Elemento HTML com o título e uma barra preenchida por bloco.
#' Usada em: perfil_palco() (visão sem comparação).
#' @noRd
grafico_barras_blocos <- function(blocos, contexto = NULL) {
  ## Obs.: este bloco usa funções auxiliares de fct_dados, fct_cores e fct_petalas.
  # Garantindo os nomes, as cores e as medidas dos blocos
  blocos$nome <- as.character(blocos$nome)
  if (is.null(blocos$medida)) {
    blocos$medida <- MEDIDAS$medida[match(blocos$nome, MEDIDAS$nome)]
  }
  if (is.null(blocos$cor)) {
    blocos$cor <- cor_medida(blocos$medida)
  }

  # Montando uma linha de barra para cada bloco, na ordem canônica
  linhas <- lapply(seq_len(nrow(blocos)), function(i) {
    valor <- blocos$valor[i]
    # Limitando o preenchimento à escala de 0 a 100
    largura <- if (is.na(valor)) 0 else max(0, min(100, valor))
    htmltools::tags$div(
      class = "resultado-blocos__linha",
      htmltools::tags$div(
        class = "resultado-blocos__cabecalho",
        htmltools::tags$span(
          class = "resultado-blocos__nome",
          blocos$nome[i]
        ),
        htmltools::tags$span(
          class = "resultado-blocos__valor",
          htmltools::tags$span(
            class = "resultado-blocos__numero",
            formatar_numero(valor)
          ),
          # Explicando a escala do valor em um texto mais discreto
          if (!is.na(valor)) {
            htmltools::tags$span(
              class = "resultado-blocos__escala",
              "de 100"
            )
          }
        )
      ),
      # Preenchendo a barra com a cor do bloco até o valor do percentil
      htmltools::tags$div(
        class = "resultado-blocos__trilho",
        `data-bs-toggle` = "tooltip",
        `data-bs-placement` = "top",
        tabindex = "0",
        # Reaproveitando a tooltip das pétalas apenas na área da barra
        title = tooltip_petala(
          blocos$nome[i], blocos$valor[i], blocos$categoria[i],
          blocos$pos_nac[i], blocos$total_nac[i], blocos$medida[i],
          contexto = contexto
        ),
        htmltools::tags$span(
          class = "resultado-blocos__preenchimento",
          style = sprintf(
            "width:%.1f%%;background:%s;", largura, blocos$cor[i]
          )
        )
      )
    )
  })

  htmltools::tags$div(
    class = "resultado-blocos",
    linhas
  )
}

#' Definindo uma função que monta o palco de um município
#'
#' @param municipio Linha do cadastro de municípios (nome, UF e território).
#' @param resumo Lista retornada por resumo_municipio() ou NULL sem dado no ano.
#' @param ano Ano de referência exibido no índice.
#' @param comparado Indica se o palco é o do município de comparação.
#' @param comparacao_ativa Indica se a visão com dois municípios está ativa.
#' @param rotulo Rótulo de hierarquia exibido acima do nome (opcional).
#' @return Elemento HTML com o palco completo.
#' Usada em: mod_como.R (palcos principal e comparado).
#' @noRd
perfil_palco <- function(municipio, resumo, ano,
                         comparado = FALSE, comparacao_ativa = FALSE,
                         rotulo = NULL) {
  ## Obs.: este bloco usa funções auxiliares de fct_ui e fct_petalas.
  # Reunindo as classes do palco e marcando quando ele é o comparado
  classes <- c("painel-bloco", "painel-bloco--palco")
  if (comparado) {
    classes <- c(classes, "painel-bloco--comparado")
  }

  # Montando a identificação do município a partir do cadastro
  valido <- !is.null(municipio) && nrow(municipio) > 0 && !is.na(municipio$codmunres[1])
  identificacao <- if (!valido) {
    estado_vazio("Selecione um município para ver o perfil.")
  } else {
    htmltools::tagList(
      # Nome e UF em um único destaque, sem elemento separado para a sigla
      htmltools::tags$h3(
        class = "perfil-nome",
        paste0(municipio$municipio[1], ", ", municipio$sigla_uf[1])
      ),
      htmltools::tags$div(
        class = "perfil-metricas",
        metrica_hero("Região", municipio$regiao[1], tooltip = TRUE),
        metrica_hero("UF", municipio$uf[1], tooltip = TRUE),
        metrica_hero("Macrorregião de saúde", municipio$macro_r_saude[1], tooltip = TRUE),
        metrica_hero("Região de saúde", municipio$r_saude[1], tooltip = TRUE)
      )
    )
  }

  # Montando o índice, as pétalas e os rankings somente quando houver dado no ano
  corpo <- if (is.null(resumo)) {
    htmltools::tags$div(
      class = "perfil-palco__grafico",
      estado_vazio(
        paste(
          "Este município não possui dados no ano selecionado.",
          "Veja a evolução ao longo do tempo abaixo."
        ),
        icone = "circle-info"
      )
    )
  } else {
    # Montando a área dos gráficos com as pétalas e, sem comparação, as barras
    classes_graficos <- c("perfil-palco__graficos")
    if (comparado || comparacao_ativa) {
      classes_graficos <- c(classes_graficos, "perfil-palco__graficos--petalas")
    }

    # Explicando as pétalas no botão de informação do título
    texto_petalas <- paste(
      "No gráfico de pétalas, cada pétala representa uma dimensão do Índice VIDAS:",
      "quanto maior a pétala, melhores as condições naquela dimensão.",
      "O contorno pontilhado mostra o tamanho máximo que a pétala poderia ter (100)."
    )

    # Montando o rodapé discreto das tooltips com o município e o ano
    contexto <- paste0(
      resumo$municipio, " (", resumo$sigla_uf, ") · ", ano
    )

    htmltools::tagList(
      perfil_indice(resumo, ano, contexto = contexto),
      # Nomeando a linha com o leque de pétalas e o resultado por dimensão
      htmltools::tags$div(
        class = "perfil-palco__cabecalho",
        htmltools::tags$h4(
          class = "perfil-palco__titulo",
          "Resultado por dimensão"
        ),
        htmltools::tags$button(
          type = "button",
          class = "perfil-palco__info",
          `aria-label` = "Sobre o gráfico de pétalas",
          `data-bs-toggle` = "tooltip",
          `data-tooltip-gatilho` = "hover focus click",
          `data-tooltip-larga` = "sim",
          title = paste0(
            '<span class="perfil-palco__info-texto">',
            texto_petalas,
            "</span>"
          ),
          fontawesome::fa("circle-info")
        )
      ),
      htmltools::tags$div(
        class = paste(classes_graficos, collapse = " "),
        # Desenhando o leque de pétalas dos seis blocos
        htmltools::tags$div(
          class = "perfil-palco__coluna",
          grafico_petalas(resumo$blocos, contexto = contexto)
        ),
        # Mostrando o resultado detalhado por bloco apenas na visão isolada
        if (!comparado && !comparacao_ativa) {
          htmltools::tags$div(
            class = "perfil-palco__coluna perfil-palco__coluna--barras",
            grafico_barras_blocos(resumo$blocos, contexto = contexto)
          )
        }
      ),
      # Mostrando os rankings na base do palco, abaixo dos gráficos
      perfil_rankings(resumo, contexto = contexto)
    )
  }

  htmltools::tags$div(
    class = paste(classes, collapse = " "),
    if (!is.null(rotulo)) htmltools::tags$span(class = "palco-rotulo", rotulo),
    identificacao,
    corpo
  )
}
