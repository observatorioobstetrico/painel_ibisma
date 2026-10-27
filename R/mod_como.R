# =============================================================================
#   MÓDULO COMO?
#   Permite explorar um município em detalhe: situação no ano escolhido,
#   flor dos seis blocos e evolução temporal do Índice VIDAS e dos blocos.
#   Quando há comparação ativa, palcos e gráficos aparecem lado a lado.
# =============================================================================

#' Interface do módulo Como?
#'
#' @param id Identificador do módulo.
#' @return Elemento HTML da seção Como?.
#' @noRd
mod_como_ui <- function(id) {
  ns <- shiny::NS(id)

  ## Obs.: este bloco usa funções auxiliares de fct_dados, fct_ui e fct_esqueleto.
  # Montando as opções de municípios em ordem alfabética, com a UF no rótulo
  municipios <- dados_vidas()$municipios
  municipios <- municipios[order(municipios$municipio, municipios$sigla_uf), ]
  municipios <- stats::setNames(
    municipios$codmunres,
    paste0(municipios$municipio, " (", municipios$sigla_uf, ")")
  )
  # Montando as opções de ano em ordem decrescente
  anos_ordem <- rev(dados_vidas()$anos)
  anos <- stats::setNames(anos_ordem, anos_ordem)
  # Incluindo a opção de não comparar com nenhum município
  opcoes_comparacao <- c("Nenhum" = "nenhum", municipios)

  htmltools::tags$section(
    id = "como",
    class = "secao-painel secao-como",
    htmltools::tags$div(
      class = "painel-container",
      # Cabeçalho editorial da seção
      titulo_secao(
        titulo = "Como o Índice VIDAS se apresenta no município?",
        descricao = paste(
          "Escolha um município para ver a situação no ano selecionado",
          "e a evolução ao longo do tempo, comparando com outro município",
          "quando quiser."
        )
      ),
      # Controles principais escritos como uma frase
      htmltools::tags$div(
        class = "controles-inline",
        htmltools::tags$span(class = "controle-texto", "Ver"),
        seletor_inline(ns("municipio"), municipios, selected = municipio_padrao(), largura = "320px"),
        htmltools::tags$span(class = "controle-texto", "em"),
        seletor_inline(ns("ano"), anos, selected = max(dados_vidas()$anos)),
        htmltools::tags$span(class = "controle-texto", "e comparar com"),
        seletor_inline(ns("comparar"), opcoes_comparacao, selected = "nenhum", largura = "320px")
      ),
      # Palcos do município principal e do comparado, exibidos lado a lado
      htmltools::tags$div(
        class = "dupla dupla--palcos",
        id = ns("palcos"),
        htmltools::tags$div(
          class = "dupla__item dupla__item--principal",
          esqueleto_slot(
            shiny::uiOutput(ns("palco_principal")),
            esqueleto_palco(),
            classe = "esqueleto-slot--palco esqueleto-slot--principal"
          )
        ),
        htmltools::tags$div(
          class = "dupla__item dupla__item--comparado",
          esqueleto_slot(
            shiny::uiOutput(ns("palco_comparado")),
            esqueleto_palco(),
            classe = "esqueleto-slot--palco esqueleto-slot--comparado"
          )
        )
      ),
      # Evolução temporal com o Índice VIDAS em destaque e os blocos em pequenos múltiplos
      htmltools::tags$div(
        class = "painel-bloco painel-bloco--evolucao",
        htmltools::tags$div(
          class = "bloco-cabecalho",
          htmltools::tags$h3(class = "bloco-titulo", "Evolução ao longo do tempo"),
          htmltools::tags$p(
            class = "bloco-descricao",
            paste(
              "Acompanhe a evolução do Índice VIDAS e de suas seis dimensões entre 2015 e 2024."
            )
          ),
          # Identificando os municípios e o período exibidos nos gráficos
          esqueleto_slot(
            shiny::uiOutput(ns("evolucao_identificacao")),
            esqueleto_identificacao(),
            classe = "esqueleto-slot--identificacao"
          )
        ),
        # Grade com sete cartões, preenchida apenas quando houver série para desenhar
        esqueleto_slot(
          shiny::uiOutput(ns("evolucoes")),
          esqueleto_grade_evolucao(),
          classe = "esqueleto-slot--evolucao"
        )
      ),
      # Indicadores em detalhe, um bloco por vez, para os mesmos municípios
      # A seção só aparece quando a base reconstrói as séries com os indicadores
      if (tem_indicadores(dados_vidas())) {
        htmltools::tags$div(
          class = "painel-bloco painel-bloco--indicadores",
          htmltools::tags$div(
            class = "bloco-cabecalho",
            htmltools::tags$h3(class = "bloco-titulo", "Os indicadores por trás de cada dimensão"),
            htmltools::tags$p(
              class = "bloco-descricao",
              paste(
                "Escolha uma dimensão para ver os indicadores que a compõem",
                "e como cada um mudou ao longo do tempo."
              )
            )
          ),
          # Escolhendo o bloco em botões com a cor de identificação de cada dimensão
          htmltools::tags$div(
            class = "indicadores-controles",
            shinyWidgets::radioGroupButtons(
              inputId = ns("bloco"),
              label = NULL,
              choices = stats::setNames(BLOCOS$medida, BLOCOS$nome),
              selected = BLOCOS$medida[1],
              size = "sm"
            )
          ),
          # Identificando os municípios logo abaixo do seletor de bloco
          esqueleto_slot(
            shiny::uiOutput(ns("indicadores_identificacao")),
            esqueleto_identificacao(),
            classe = "esqueleto-slot--identificacao"
          ),
          # Grade com os cartões do bloco escolhido e esqueleto empilhado
          esqueleto_slot(
            shiny::uiOutput(ns("indicadores")),
            esqueleto_indicadores(),
            classe = "esqueleto-slot--indicadores"
          )
        )
      }
    )
  )
}

#' Server do módulo Como?
#'
#' @param id Identificador do módulo.
#' @param dados Lista lida por dados_vidas().
#' @param municipio Reativo compartilhado com o município selecionado.
#' @param ano Reativo compartilhado com o ano selecionado.
#' @return Nada; registra os outputs e observadores do módulo.
#' @noRd
mod_como_server <- function(id, dados, municipio, ano) {
  shiny::moduleServer(id, function(input, output, session) {
    ns <- session$ns

    # Mantendo o seletor de ano sincronizado com o restante do painel
    shiny::observeEvent(ano(), {
      selecionado <- ano()
      if (!is.null(selecionado) && !is.na(selecionado)) {
        shinyWidgets::updateSlimSelect(
          session = session,
          inputId = "ano",
          selected = as.character(selecionado)
        )
      }
    }, ignoreInit = FALSE)

    # Registrando a troca de ano feita no próprio seletor
    shiny::observeEvent(input$ano, {
      novo <- suppressWarnings(as.integer(input$ano))
      if (!is.na(novo) && !identical(novo, ano())) {
        ano(novo)
      }
    })

    # Mantendo o seletor do perfil sincronizado com o restante do painel
    shiny::observeEvent(municipio(), {
      selecionado <- municipio()
      if (!is.null(selecionado) && !is.na(selecionado)) {
        # Removendo nomes do valor para a mensagem JSON não carregar vetor nomeado
        shinyWidgets::updateSlimSelect(
          session = session,
          inputId = "municipio",
          selected = unname(as.character(selecionado))
        )
      }
    }, ignoreInit = FALSE)

    # Registrando a troca de município feita no próprio seletor
    shiny::observeEvent(input$municipio, {
      novo <- suppressWarnings(as.integer(input$municipio))
      if (!is.na(novo) && !identical(novo, municipio())) {
        municipio(novo)
      }
    })

    # Obtendo os dados territoriais do município selecionado
    info <- shiny::reactive({
      dados$municipios[dados$municipios$codmunres == municipio(), ][1, ]
    })

    # Definindo uma função que monta o resumo completo de um município em um ano
    # Usada em: mod_como.R (palcos principal e comparado).
    resumo_municipio <- function(codmunres, ano_ref) {
      ## Obs.: este bloco usa funções auxiliares de fct_dados e fct_cores.
      # Reunindo as linhas do município em todas as medidas do ano
      tabela <- tabela_ano(dados, ano_ref)
      linhas <- tabela[tabela$codmunres == codmunres, ]

      # Identificando o município a partir das próprias linhas
      info <- dados$municipios[dados$municipios$codmunres == codmunres, ]
      if (nrow(info) == 0 || nrow(linhas) == 0) {
        return(NULL)
      }

      # Separando a linha do índice final e a dos seis blocos na ordem configurada
      linha_indice <- linhas[linhas$medida == "indice_final", ]
      blocos <- linhas[match(BLOCOS$medida, linhas$medida), ]
      blocos$nome <- nome_medida(blocos$medida)
      blocos$cor <- cor_medida(blocos$medida)

      # Montando a lista final consumida pelo componente de perfil
      list(
        codmunres = codmunres,
        municipio = info$municipio,
        sigla_uf = info$sigla_uf,
        uf = info$uf,
        regiao = info$regiao,
        r_saude = info$r_saude,
        macro_r_saude = info$macro_r_saude,
        valor = linha_indice$valor,
        categoria = as.character(linha_indice$categoria),
        pos_nac = linha_indice$pos_nac,
        total_nac = linha_indice$total_nac,
        pos_uf = linha_indice$pos_uf,
        total_uf = linha_indice$total_uf,
        pos_macro = linha_indice$pos_macro,
        total_macro = linha_indice$total_macro,
        blocos = blocos
      )
    }

    ## Obs.: este bloco usa funções auxiliares de fct_dados.
    # Montando o resumo do município no ano escolhido
    resumo <- shiny::reactive({
      resumo_municipio(municipio(), ano())
    })

    # ----- Município de comparação -----
    ## Obs.: este bloco usa funções auxiliares de fct_dados.

    # Descobrindo o município de comparação escolhido, se houver
    cod_comparacao <- shiny::reactive({
      valor <- input$comparar
      if (is.null(valor) || identical(valor, "nenhum")) {
        return(NULL)
      }
      suppressWarnings(as.integer(valor))
    })

    # Verificando se existe um município de comparação escolhido
    tem_comparacao <- shiny::reactive({
      !is.null(cod_comparacao())
    })

    # Obtendo os dados territoriais do município comparado
    info_comparacao <- shiny::reactive({
      cod <- cod_comparacao()
      if (is.null(cod)) return(NULL)
      dados$municipios[dados$municipios$codmunres == cod, ][1, ]
    })

    # Montando o resumo do município comparado no mesmo ano
    resumo_comparacao <- shiny::reactive({
      cod <- cod_comparacao()
      if (is.null(cod)) return(NULL)
      resumo_municipio(cod, ano())
    })

    # ----- Palcos -----
    ## Obs.: este bloco usa funções auxiliares de fct_perfil.

    # Montando o palco do município principal, com rótulo apenas na comparação
    output$palco_principal <- shiny::renderUI({
      perfil_palco(
        municipio = info(),
        resumo = resumo(),
        ano = ano(),
        comparacao_ativa = tem_comparacao(),
        rotulo = if (tem_comparacao()) "Município principal" else NULL
      )
    })

    # Montando o palco do município comparado; fica suspenso sem comparação
    output$palco_comparado <- shiny::renderUI({
      shiny::req(cod_comparacao())
      perfil_palco(
        municipio = info_comparacao(),
        resumo = resumo_comparacao(),
        ano = ano(),
        comparado = TRUE,
        comparacao_ativa = TRUE,
        rotulo = "Município comparado"
      )
    })

    # Avisando o navegador para animar a transição dos palcos
    shiny::observeEvent(tem_comparacao(), {
      session$sendCustomMessage("vidas_comparacao", list(
        palcos = ns("palcos"),
        ativa = tem_comparacao()
      ))
    }, ignoreInit = TRUE)

    # ----- Evolução temporal -----
    ## Obs.: este bloco usa funções auxiliares de fct_graficos_evolucao, fct_dados e fct_ui.

    # Montando as séries das sete medidas de cada município
    series_principal <- shiny::reactive(series_municipio(dados, municipio()))
    series_comparacao <- shiny::reactive({
      shiny::req(cod_comparacao())
      series_municipio(dados, cod_comparacao())
    })

    # Verificando se o comparado tem alguma série para desenhar
    comparacao_tem_serie <- shiny::reactive({
      tem_comparacao() && series_tem_valor(series_comparacao())
    })

    # Calculando a escala compartilhada do eixo de um grupo de medidas
    limites_do_grupo <- function(medidas) {
      limites_medidas(
        if (series_tem_valor(series_principal())) series_principal() else NULL,
        medidas,
        if (comparacao_tem_serie()) series_comparacao() else NULL
      )
    }

    # Dando ao Índice VIDAS uma escala própria, mais estreita que a dos blocos
    limites_vidas <- shiny::reactive(limites_do_grupo("indice_final"))
    # Compartilhando a escala dos seis blocos para os cartões serem comparáveis
    limites_blocos <- shiny::reactive(limites_do_grupo(BLOCOS$medida))

    # Montando o gráfico de evolução de uma medida
    grafico_da_medida <- function(medida) {
      # Desenhando a linha comparada apenas quando ela tem algum valor
      comparacao <- if (comparacao_tem_serie()) series_comparacao() else NULL
      # Usando a escala compartilhada do grupo de medidas do gráfico
      limites <- if (identical(medida, "indice_final")) limites_vidas() else limites_blocos()
      grafico_evolucao(
        series_principal(),
        medida = medida,
        nome = nome_municipio(dados, municipio()),
        comparacao = comparacao,
        nome_comparacao = if (is.null(comparacao)) NULL else {
          nome_municipio(dados, cod_comparacao())
        },
        limites = limites
      )
    }

    # Renderizando um gráfico para cada medida em um laço para evitar repetição
    for (i in seq_len(nrow(MEDIDAS))) {
      local({
        medida <- MEDIDAS$medida[i]
        output[[paste0("grafico_", medida)]] <- echarts4r::renderEcharts4r({
          shiny::req(series_tem_valor(series_principal()))
          grafico_da_medida(medida)
        })
      })
    }

    # Montando o nome de um município com a amostra do traço usado no gráfico
    chip_municipio <- function(nome, comparado = FALSE) {
      htmltools::tags$span(
        class = "evolucao-identificacao__serie",
        htmltools::tags$span(class = paste0(
          "evolucao-identificacao__amostra",
          if (comparado) " evolucao-identificacao__amostra--comparacao"
        )),
        nome
      )
    }

    # Montando a identificação dos municípios exibidos nas grades
    # A cor da série é opcional: na seção dos indicadores ela é a do bloco
    identificacao_series <- function(cor = NULL) {
      # Escondendo a identificação quando o município não tem série temporal
      if (!series_tem_valor(series_principal())) {
        return(NULL)
      }
      # Mostrando cada município com o traço e a bolinha do próprio gráfico
      nomes <- list(chip_municipio(nome_municipio(dados, municipio())))
      if (comparacao_tem_serie()) {
        nomes <- c(nomes, list(chip_municipio(
          nome_municipio(dados, cod_comparacao()),
          comparado = TRUE
        )))
      }
      htmltools::tags$p(
        class = "evolucao-identificacao",
        style = if (!is.null(cor)) paste0("--cor-serie:", cor, ";"),
        nomes
      )
    }

    # Identificando os municípios no cabeçalho da evolução temporal
    output$evolucao_identificacao <- shiny::renderUI({
      # Escondendo a identificação quando o município não tem série temporal
      shiny::req(series_tem_valor(series_principal()))
      identificacao_series()
    })

    # Repetindo a identificação logo abaixo do título dos blocos
    output$evolucao_identificacao_blocos <- shiny::renderUI(identificacao_series())

    # Inserindo a grade de cartões apenas quando existir algum valor
    output$evolucoes <- shiny::renderUI({
      if (!series_tem_valor(series_principal())) {
        return(estado_vazio(
          "Sem dados de série temporal para este município.",
          icone = "circle-info"
        ))
      }
      grade_evolucao_ui(ns)
    })

    # ----- Indicadores do bloco -----
    ## Obs.: este bloco usa funções auxiliares de fct_graficos_evolucao, fct_dados e fct_ui.

    # Definindo o bloco exibido no detalhe dos indicadores
    bloco_indicadores <- shiny::reactive({
      if (is.null(input$bloco)) BLOCOS$medida[1] else input$bloco
    })

    # Verificando se o indicador tem valor em algum dos municípios exibidos
    indicador_tem_valor <- function(indicador) {
      series_tem_valor(series_principal(), indicador) ||
        (comparacao_tem_serie() && series_tem_valor(series_comparacao(), indicador))
    }

    # Renderizando um gráfico para cada indicador em um laço para evitar repetição
    for (i in seq_len(nrow(INDICADORES))) {
      local({
        indicador <- INDICADORES$indicador[i]
        output[[paste0("indicador_", indicador)]] <- echarts4r::renderEcharts4r({
          shiny::req(indicador_tem_valor(indicador))
          # Desenhando a linha comparada apenas quando ela tem valor próprio
          comparacao <- if (comparacao_tem_serie() &&
                            series_tem_valor(series_comparacao(), indicador)) {
            series_comparacao()
          } else {
            NULL
          }
          grafico_evolucao_indicador(
            series_principal(),
            indicador = indicador,
            nome = nome_municipio(dados, municipio()),
            comparacao = comparacao,
            nome_comparacao = if (is.null(comparacao)) NULL else {
              nome_municipio(dados, cod_comparacao())
            }
          )
        })
      })
    }

    # Montando os cartões dos indicadores do bloco selecionado
    output$indicadores <- shiny::renderUI({
      shiny::req(series_tem_valor(series_principal()) || comparacao_tem_serie())
      indicadores_bloco <- indicadores_do_bloco(bloco_indicadores())
      cartoes <- lapply(indicadores_bloco$indicador, function(indicador) {
        info <- info_indicador(indicador)
        htmltools::tags$div(
          class = "indicador-card",
          style = paste0("--cor-bloco:", cor_medida(info$bloco), ";"),
          htmltools::tags$div(
            class = "indicador-card__cabecalho",
            htmltools::tags$h4(
              class = "indicador-card__titulo",
              info$nome
            ),
            # Indicando ao lado do título se o melhor é subir ou descer no valor
            chip_sentido_indicador(info$protetor)
          ),
          if (indicador_tem_valor(indicador)) {
            echarts4r::echarts4rOutput(
              ns(paste0("indicador_", indicador)),
              height = paste0(ALTURA_GRAFICO_INDICADOR, "px")
            )
          } else {
            estado_vazio("Sem dados no período.")
          }
        )
      })
      htmltools::tags$div(class = "indicadores-grade", cartoes)
    })

    # Identificando os municípios logo abaixo do seletor de bloco
    # Com a cor do bloco escolhido, para casar com o traço dos gráficos
    output$indicadores_identificacao <- shiny::renderUI({
      identificacao_series(cor_linha_medida(bloco_indicadores()))
    })
  })
}
