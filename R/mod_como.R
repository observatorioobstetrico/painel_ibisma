# =============================================================================
#   MÓDULO COMO?
#   Permite explorar um município em detalhe: situação no ano escolhido,
#   flor dos seis blocos e evolução temporal do IBISMA e dos blocos.
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
  municipios <- dados_ibisma()$municipios
  municipios <- municipios[order(municipios$municipio, municipios$sigla_uf), ]
  municipios <- stats::setNames(
    municipios$codmunres,
    paste0(municipios$municipio, " (", municipios$sigla_uf, ")")
  )
  # Montando as opções de ano em ordem decrescente
  anos_ordem <- rev(dados_ibisma()$anos)
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
        eyebrow = "Como?",
        titulo = "Como a insegurança se apresenta no município?",
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
        seletor_inline(ns("ano"), anos, selected = max(dados_ibisma()$anos)),
        htmltools::tags$span(class = "controle-texto", "e comparar com"),
        seletor_inline(ns("comparar"), opcoes_comparacao, selected = "nenhum", largura = "320px")
      ),
      # Explicando as pétalas uma única vez, acima dos palcos
      htmltools::tags$p(
        class = "petalas-caption",
        paste(
          "Cada pétala representa um bloco do IBISMA: quanto maior a pétala,",
          "maior a insegurança naquele bloco."
        )
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
      # Evolução temporal com o IBISMA em destaque e os blocos em pequenos múltiplos
      htmltools::tags$div(
        class = "painel-bloco painel-bloco--evolucao",
        htmltools::tags$div(
          class = "bloco-cabecalho",
          htmltools::tags$h3(class = "bloco-titulo", "Evolução ao longo do tempo"),
          htmltools::tags$p(
            class = "bloco-descricao",
            paste(
              "Acompanhe a evolução do IBISMA e de seus seis blocos entre 2015 e 2024."
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
      )
    )
  )
}

#' Server do módulo Como?
#'
#' @param id Identificador do módulo.
#' @param dados Lista lida por dados_ibisma().
#' @param municipio Reativo compartilhado com o município selecionado.
#' @return Nada; registra os outputs e observadores do módulo.
#' @noRd
mod_como_server <- function(id, dados, municipio) {
  shiny::moduleServer(id, function(input, output, session) {
    ns <- session$ns

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

    # Convertendo o ano escolhido no controle para número
    ano <- shiny::reactive(as.integer(input$ano))

    # Obtendo os dados territoriais do município selecionado
    info <- shiny::reactive({
      dados$municipios[dados$municipios$codmunres == municipio(), ][1, ]
    })

    # Definindo uma função que monta o resumo completo de um município em um ano
    # Usada em: mod_como.R (palcos principal e comparado).
    resumo_municipio <- function(codmunres, ano) {
      ## Obs.: este bloco usa funções auxiliares de fct_dados e fct_cores.
      # Reunindo as linhas do município em todas as medidas do ano
      tabela <- tabela_ano(dados, ano)
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
        rotulo = "Município comparado"
      )
    })

    # Avisando o navegador para animar a transição dos palcos
    shiny::observeEvent(tem_comparacao(), {
      session$sendCustomMessage("ibisma_comparacao", list(
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

    # Calculando os limites do eixo Y de um grupo de medidas nos dois municípios
    limites_do_grupo <- function(medidas) {
      # Reunindo os limites apenas dos gráficos que têm dado para desenhar
      pisos <- numeric(0)
      tetos <- numeric(0)
      if (series_tem_valor(series_principal())) {
        pisos <- c(pisos, piso_eixo_y(series_principal(), medidas))
        tetos <- c(tetos, teto_eixo_y(series_principal(), medidas))
      }
      if (comparacao_tem_serie()) {
        pisos <- c(pisos, piso_eixo_y(series_comparacao(), medidas))
        tetos <- c(tetos, teto_eixo_y(series_comparacao(), medidas))
      }
      if (length(pisos) == 0) {
        return(list(min = 0, max = 100))
      }
      # Abrindo a faixa ao máximo para nenhuma das duas séries ser cortada
      list(min = min(pisos), max = max(tetos))
    }

    # Dando ao IBISMA uma escala própria, mais estreita que a dos blocos
    limites_ibisma <- shiny::reactive(limites_do_grupo("indice_final"))
    # Compartilhando a escala dos seis blocos para os cartões serem comparáveis
    limites_blocos <- shiny::reactive(limites_do_grupo(BLOCOS$medida))

    # Montando o gráfico de evolução de uma medida
    grafico_da_medida <- function(medida) {
      # Desenhando a linha comparada apenas quando ela tem algum valor
      comparacao <- if (comparacao_tem_serie()) series_comparacao() else NULL
      # Usando a escala compartilhada do grupo de medidas do gráfico
      limites <- if (identical(medida, "indice_final")) limites_ibisma() else limites_blocos()
      grafico_evolucao(
        series_principal(),
        medida = medida,
        nome = nome_municipio(dados, municipio()),
        comparacao = comparacao,
        nome_comparacao = if (is.null(comparacao)) NULL else {
          nome_municipio(dados, cod_comparacao())
        },
        minimo_y = limites$min,
        maximo_y = limites$max
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

    # Montando a identificação dos municípios exibidos na grade
    output$evolucao_identificacao <- shiny::renderUI({
      # Escondendo a identificação quando o município não tem série temporal
      shiny::req(series_tem_valor(series_principal()))
      # Mostrando cada município com o traço e a bolinha do próprio gráfico
      nomes <- list(chip_municipio(nome_municipio(dados, municipio())))
      if (comparacao_tem_serie()) {
        nomes <- c(nomes, list(chip_municipio(
          nome_municipio(dados, cod_comparacao()),
          comparado = TRUE
        )))
      }
      htmltools::tags$p(class = "evolucao-identificacao", nomes)
    })

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
  })
}
