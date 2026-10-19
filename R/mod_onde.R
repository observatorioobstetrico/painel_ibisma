# =============================================================================
#   MÓDULO ONDE?
#   Reúne o mapa e o ranking em uma única experiência: os dois blocos
#   compartilham os controles de medida, nível e ano, e a seleção de município
#   circula entre o mapa, o ranking e o perfil.
# =============================================================================

#' Interface do módulo Onde?
#'
#' @param id Identificador do módulo.
#' @return Elemento HTML da seção Onde?.
#' @noRd
mod_onde_ui <- function(id) {
  ns <- shiny::NS(id)

  # Montando as opções de medida com o prefixo "Bloco" para leitura natural
  medidas <- stats::setNames(MEDIDAS$medida, MEDIDAS$rotulo)

  # Montando as opções de nível de análise a partir da configuração central
  niveis <- stats::setNames(NIVEIS_ANALISE$id, NIVEIS_ANALISE$rotulo)

  # Montando as opções de ano em ordem decrescente
  anos_ordem <- rev(dados_ibisma()$anos)
  anos <- stats::setNames(anos_ordem, anos_ordem)

  # Montando as opções de escopo do ranking com o Brasil à frente das UFs
  ufs_escopo <- unique(dados_ibisma()$municipios[, c("sigla_uf", "uf")])
  ufs_escopo <- ufs_escopo[order(ufs_escopo$uf), ]
  escopos <- stats::setNames(
    c("nacional", ufs_escopo$sigla_uf),
    c("Brasil (nacional)", paste0(ufs_escopo$uf, " (", ufs_escopo$sigla_uf, ")"))
  )

  # Obs.: este bloco usa funções auxiliares de fct_dados, fct_ui e fct_esqueleto.
  htmltools::tags$section(
    id = "onde",
    class = "secao-painel",
    htmltools::tags$div(
      class = "painel-container",
      # Cabeçalho editorial da seção
      titulo_secao(
        titulo = "Onde o Índice VIDAS revela maiores desafios?",
        descricao = paste(
          "O Índice VIDAS varia de 0 a 100: quanto menor o valor,",
          "maior a prioridade de atenção e piores as condições de saúde das mulheres no município."
        )
      ),
      # Controles principais escritos como uma frase
      htmltools::tags$div(
        class = "controles-inline",
        htmltools::tags$span(class = "controle-texto", "Mostrar"),
        seletor_inline(
          ns("medida"), medidas, selected = "indice_final",
          largura = "300px", busca = FALSE
        ),
        htmltools::tags$span(class = "controle-texto", "dos"),
        seletor_inline(ns("nivel"), niveis, selected = "municipio", busca = FALSE),
        htmltools::tags$span(class = "controle-texto", "em"),
        seletor_inline(ns("ano"), anos, selected = max(dados_ibisma()$anos))
      ),
      # Organizando mapa e ranking lado a lado no desktop
      bslib::layout_columns(
        col_widths = bslib::breakpoints(sm = c(12, 12), lg = c(6, 6)),
        gap = "1.5rem",
        # ----- Bloco do mapa -----
        htmltools::tags$div(
          class = "painel-bloco painel-bloco--mapa",
          htmltools::tags$div(
            class = "bloco-cabecalho",
            htmltools::tags$div(
              htmltools::tags$h3(class = "bloco-titulo", "Distribuição no território"),
              htmltools::tags$p(
                class = "bloco-descricao",
                "Passe o mouse para ver o valor e a categoria. Clique em um município para destacá-lo em todo o painel."
              )
            )
          ),
          # Área do mapa com altura responsiva e esqueleto empilhado
          esqueleto_slot(
            leaflet::leafletOutput(ns("mapa"), height = "100%"),
            esqueleto_mapa(),
            classe = "mapa-area"
          ),
          # Legenda das cinco categorias, recalculada por medida
          esqueleto_slot(
            shiny::uiOutput(ns("legenda")),
            esqueleto_legenda(),
            classe = "mapa-legenda"
          )
        ),
        # ----- Bloco do ranking -----
        htmltools::tags$div(
          class = "painel-bloco painel-bloco--ranking",
          htmltools::tags$div(
            class = "bloco-cabecalho",
            htmltools::tags$h3(class = "bloco-titulo", "Ranking dos municípios"),
            # Explicando a primeira posição; o texto padrão só muda quando há bloco
            htmltools::tags$div(
              class = "ranking-descricao",
              shiny::uiOutput(ns("ranking_descricao")),
              htmltools::tags$p(
                class = "bloco-descricao ranking-descricao__padrao",
                paste(
                  "A primeira posição indica o município com menor Índice VIDAS",
                  "do escopo escolhido, que é a maior prioridade de atenção."
                )
              )
            )
          ),
          # Controle de escopo do ranking (Brasil ou uma UF)
          htmltools::tags$div(
            class = "controles-inline",
            htmltools::tags$span(class = "controle-texto", "Ranking para"),
            seletor_inline(ns("escopo"), escopos, selected = "nacional")
          ),
          # Resumindo o total de municípios, o ano e a medida logo acima da tabela
          esqueleto_slot(
            shiny::textOutput(ns("ranking_resumo"), inline = TRUE),
            esqueleto_texto(),
            classe = "ranking-resumo"
          ),
          # Tabela interativa com a lista de municípios e esqueleto empilhado
          esqueleto_slot(
            reactable::reactableOutput(ns("ranking")),
            esqueleto_ranking(),
            classe = "esqueleto-slot--ranking"
          )
        )
      )
    )
  )
}

#' Server do módulo Onde?
#'
#' @param id Identificador do módulo.
#' @param dados Lista lida por dados_ibisma().
#' @param municipio Reativo compartilhado com o município selecionado.
#' @return Nada; registra os outputs e observadores do módulo.
#' @noRd
mod_onde_server <- function(id, dados, municipio) {
  shiny::moduleServer(id, function(input, output, session) {
    ns <- session$ns

    ## Obs.: este bloco usa funções auxiliares de fct_mapa.
    # Calculando os dados do mapa para a medida e o ano selecionados
    base_mapa <- shiny::reactive({
      dados_mapa(dados, as.integer(input$ano), input$medida)
    })

    # ----- Mapa -----

    # Montando o mapa-base uma única vez; os municípios chegam por mensagem
    output$mapa <- leaflet::renderLeaflet({
      desenhar_ufs(mapa_base()) |>
        htmlwidgets::onRender(
          sprintf(
            "function(el) {
               var w = HTMLWidgets.getInstance(el);
               if (w && w.getMap) {
                 var mapa = w.getMap();
                 mapa.invalidateSize();
                 /* Enquadrando o Brasil e impedindo qualquer zoom menor */
                 var brasil = L.latLngBounds([[-34.5, -74.5], [6.5, -33.5]]);
                 var ajustar = function () {
                   /* O cálculo do enquadramento é limitado pelo mínimo atual */
                   mapa.setMinZoom(0);
                   var zoomBrasil = mapa.getBoundsZoom(brasil, false, L.point(16, 16));
                   mapa.setMinZoom(zoomBrasil);
                   if (mapa.getZoom() < zoomBrasil) mapa.setZoom(zoomBrasil);
                 };
                 ajustar();
                 mapa.fitBounds(brasil, {padding: [8, 8]});
                 window.addEventListener('resize', ajustar);
               }
               Shiny.setInputValue('%s', Date.now(), {priority: 'event'});
             }",
            ns("mapa_pronto")
          )
        )
    })

    # Atualizando cores e tooltips do mapa quando muda o ano ou a medida
    shiny::observeEvent(list(input$ano, input$medida), {
      atualizar_municipios(session, ns("mapa"), base_mapa(), input$medida)
    }, ignoreInit = TRUE)

    # Enviando o desenho dos municípios assim que o mapa termina de montar
    shiny::observeEvent(input$mapa_pronto, {
      enviar_desenho_municipios(session, ns("mapa"), base_mapa(), input$medida)
      # Aplicando a UF escolhida antes de o mapa terminar de montar
      if (!identical(input$escopo, "nacional")) {
        aplicar_escopo(session, ns("mapa"), input$escopo)
      }
    }, once = TRUE)

    # Acompanhando o escopo do ranking com o destaque e o voo do mapa
    shiny::observeEvent(input$escopo, {
      shiny::req(input$mapa_pronto)
      aplicar_escopo(session, ns("mapa"), input$escopo)
    }, ignoreInit = TRUE)

    # Destacando no mapa o município selecionado em qualquer parte do painel
    shiny::observe({
      shiny::req(input$mapa_pronto)
      selecionado <- municipio()
      proxy <- leaflet::leafletProxy(ns("mapa"), session = session)
      proxy <- leaflet::removeShape(proxy, "selecionado")
      if (!is.null(selecionado) && !is.na(selecionado)) {
        malha <- carregar_malha_municipios()
        destaque <- malha[malha$codmunres == selecionado, ]
        if (nrow(destaque) > 0) {
          proxy <- leaflet::addPolygons(
            proxy,
            data = destaque,
            layerId = "selecionado",
            fill = FALSE,
            color = COR_AZUL_ESCURO,
            weight = 1.8,
            opacity = 0.95,
            smoothFactor = 0,
            # Desenhando no painel acima das UFs, sem capturar o mouse
            options = leaflet::pathOptions(pane = "destaque", interactive = FALSE)
          )
        }
      }
    })

    # Registrando o clique no mapa como seleção de município
    shiny::observeEvent(input$mapa_shape_click, {
      clique <- input$mapa_shape_click
      if (!is.null(clique$id) && !identical(clique$id, "selecionado")) {
        novo <- suppressWarnings(as.integer(clique$id))
        if (!is.na(novo) && !identical(novo, municipio())) {
          municipio(novo)
        }
      }
    })

    # ----- Legenda -----
    ## Obs.: este bloco usa funções auxiliares de fct_mapa e constantes.

    # Recriando a legenda sempre que a medida exibida mudar
    output$legenda <- shiny::renderUI({
      medida <- if (is.null(input$medida)) "indice_final" else input$medida
      legenda_categorias(
        paleta = PALETAS[[medida]],
        titulo = paste0(
          "Nível do ",
          nome_medida(medida, prefixo_bloco = TRUE)
        )
      )
    })

    # ----- Ranking -----
    ## Obs.: este bloco usa funções auxiliares de fct_dados, constantes, fct_cores e fct_ui.

    # Montando a tabela do ranking conforme medida, ano e escopo escolhidos
    tabela_ranking <- shiny::reactive({
      base <- valores_ano(dados, as.integer(input$ano), input$medida)
      escopo <- input$escopo
      if (!is.null(escopo) && !identical(escopo, "nacional")) {
        base <- base[base$sigla_uf == escopo, ]
      }
      # Colocando primeiro os menores valores, que são as maiores prioridades
      base <- base[order(base$valor, decreasing = FALSE, na.last = TRUE), ]
      row.names(base) <- NULL
      base
    })

    # Mantendo o município em foco quando ele segue no ranking após a troca
    shiny::observeEvent(list(input$medida, input$escopo), {
      tabela <- tabela_ranking()
      selecionado <- municipio()
      # Verificando se o município em foco continua presente no novo ranking
      presente <- !is.null(selecionado) && !is.na(selecionado) &&
        selecionado %in% tabela$codmunres
      # Resetando para o primeiro colocado quando o município sai do ranking
      if (!presente && nrow(tabela) > 0) {
        municipio(tabela$codmunres[1])
      }
    }, ignoreInit = TRUE)

    # Trocando a descrição padrão apenas quando um bloco estiver selecionado
    output$ranking_descricao <- shiny::renderUI({
      medida <- input$medida
      if (is.null(medida) || identical(medida, "indice_final")) {
        return(NULL)
      }
      htmltools::tags$p(
        class = "bloco-descricao",
        paste0(
          "A primeira posição indica o município com menor valor no ",
          nome_medida(medida, prefixo_bloco = TRUE),
          " do escopo escolhido, que é a maior prioridade de atenção."
        )
      )
    })

    # Escrevendo o texto com o total de municípios do ranking
    output$ranking_resumo <- shiny::renderText({
      tabela <- tabela_ranking()
      total <- sum(!is.na(tabela$valor))
      escopo <- input$escopo
      local <- if (identical(escopo, "nacional")) {
        "do Brasil"
      } else {
        paste0("de ", nome_uf(escopo))
      }
      paste0(
        formatar_inteiro(total), " municípios ", local,
        " em ", input$ano, " · ", nome_medida(input$medida, prefixo_bloco = TRUE)
      )
    })

    # Renderizando a tabela interativa com busca e ordenação
    output$ranking <- reactable::renderReactable({
      tabela <- tabela_ranking()

      # Montando apenas as colunas exibidas no ranking, com a posição no escopo
      exibicao <- data.frame(
        posicao = seq_len(nrow(tabela)),
        municipio = tabela$municipio,
        sigla_uf = tabela$sigla_uf,
        valor = tabela$valor,
        categoria = as.character(tabela$categoria),
        codmunres = tabela$codmunres,
        stringsAsFactors = FALSE
      )
      # Montando os selos de categoria de uma vez, com a rampa da medida exibida
      exibicao$categoria_html <- badge_categoria_html(exibicao$categoria, input$medida)

      # Localizando a linha do município em foco para marcar já na montagem
      destaque <- which(exibicao$codmunres == shiny::isolate(municipio()))

      reactable::reactable(
        exibicao,
        searchable = TRUE,
        searchMethod = busca_sem_acento,
        language = reactable::reactableLang(
          searchPlaceholder = "Buscar município...",
          noData = "Nenhum município encontrado",
          pagePrevious = "Anterior",
          pageNext = "Próxima",
          pageInfo = "{rowStart}–{rowEnd} de {rows} municípios"
        ),
        defaultSorted = "posicao",
        defaultSortOrder = "asc",
        # Fixando a quantidade de linhas para manter a altura do bloco previsível
        defaultPageSize = 12,
        showPageSizeOptions = FALSE,
        showPageInfo = FALSE,
        highlight = TRUE,
        compact = TRUE,
        striped = FALSE,
        bordered = FALSE,
        onClick = "select",
        selection = "single",
        # Marcando o município em foco já na montagem, junto com a tabela
        defaultSelected = if (length(destaque) > 0) destaque else NULL,
        columns = list(
          posicao = reactable::colDef(
            name = "Pos.", width = 62, align = "right", sticky = "left",
            cell = reactable::JS(
              "function (cellInfo) { return cellInfo.value + 'º'; }"
            )
          ),
          municipio = reactable::colDef(name = "Município", minWidth = 170),
          sigla_uf = reactable::colDef(name = "UF", width = 54),
          valor = reactable::colDef(
            name = "Valor", width = 84, align = "right",
            cell = reactable::JS(
              "function (cellInfo) {
                 if (cellInfo.value === null) return 'Sem dados';
                 return cellInfo.value.toFixed(1).replace('.', ',');
               }"
            )
          ),
          categoria_html = reactable::colDef(
            name = "Faixa", width = 118, html = TRUE, sortable = FALSE
          ),
          categoria = reactable::colDef(show = FALSE),
          codmunres = reactable::colDef(show = FALSE)
        ),
        theme = tema_reactable(input$medida)
      )
    })

    # Registrando a linha clicada no ranking como seleção de município
    shiny::observeEvent(reactable::getReactableState("ranking", "selected"), {
      linha <- reactable::getReactableState("ranking", "selected")
      if (!is.null(linha) && length(linha) > 0) {
        tabela <- tabela_ranking()
        novo <- tabela$codmunres[linha]
        if (!is.na(novo) && !identical(novo, municipio())) {
          municipio(novo)
        }
      }
    })

    # Destacando no ranking o município em foco escolhido fora da tabela
    shiny::observeEvent(municipio(), {
      selecionado <- municipio()
      if (is.null(selecionado) || is.na(selecionado)) return()
      tabela <- tabela_ranking()
      linha <- match(selecionado, tabela$codmunres)
      if (is.na(linha)) return()
      if (!identical(reactable::getReactableState("ranking", "selected"), linha)) {
        reactable::updateReactable("ranking", selected = linha)
      }
    }, ignoreInit = TRUE)

    # Movendo a página para exibir a linha em foco quando ela fica fora da página
    shiny::observeEvent(reactable::getReactableState("ranking", "selected"), {
      selecionada <- reactable::getReactableState("ranking", "selected")
      if (length(selecionada) == 0) return()
      alvo <- ceiling(selecionada[1] / 12)
      pagina <- reactable::getReactableState("ranking", "page")
      if (!is.null(pagina) && !identical(as.integer(pagina), as.integer(alvo))) {
        reactable::updateReactable("ranking", page = alvo)
      }
    }, ignoreInit = TRUE)

    # Voltando à página do município em foco quando a busca da tabela é limpa
    shiny::observeEvent(input$ranking_busca_limpa, {
      tabela <- tabela_ranking()
      linha <- match(municipio(), tabela$codmunres)
      if (is.na(linha)) return()
      reactable::updateReactable("ranking", page = ceiling(linha / 12))
    })
  })
}

# Definindo a busca do reactable que ignora acentos, sinais e maiúsculas
# O reactable entrega objetos de linha e os valores ficam em linha.values
busca_sem_acento <- reactable::JS(
  "function (rows, colunas, busca) {
     var normalizar = function (texto) {
       return String(texto)
         .normalize('NFD')
         .replace(/[\\u0300-\\u036f]/g, '')
         .toLowerCase()
         .replace(/[^a-z0-9]+/g, '');
     };
     var alvo = normalizar(busca);
     if (alvo === '') return rows;
     return rows.filter(function (linha) {
       var valores = linha.values || {};
       var texto = normalizar([valores.municipio, valores.sigla_uf].join(' '));
       return texto.indexOf(alvo) !== -1;
     });
   }"
)

#' Definindo o tema visual das tabelas reactable
#'
#' @param medida Identificador da medida exibida no ranking.
#' @return Objeto reactableTheme com as cores do projeto.
#' @noRd
tema_reactable <- function(medida = "indice_final") {
  ## Obs.: este bloco usa funções auxiliares de fct_cores.
  # Obtendo a cor de identificação da medida exibida no ranking
  base <- cor_medida(medida)[1]
  # Derivando os tons suaves da cor da medida usados nos destaques da tabela
  destaque <- misturar_cores(base, "#FFFFFF", 0.90)
  hover <- misturar_cores(base, "#FFFFFF", 0.94)

  reactable::reactableTheme(
    color = COR_AZUL_ESCURO,
    backgroundColor = "#FFFFFF",
    borderColor = "#ECEEF2",
    stripedColor = "#F8F9FB",
    highlightColor = hover,
    cellPadding = "8px 10px",
    style = list(
      fontFamily = "'Source Sans Pro', system-ui, sans-serif",
      fontSize = "0.8125rem",
      # Expondo as cores da medida para o CSS das linhas com coluna fixa
      "--cor-hover-ranking" = hover,
      "--cor-selecao-ranking" = destaque
    ),
    headerStyle = list(
      backgroundColor = "#FFFFFF",
      borderBottom = "1px solid #DDE1E8",
      color = "#5A6472",
      fontWeight = "600",
      fontSize = "0.6875rem"
    ),
    rowSelectedStyle = list(
      backgroundColor = destaque,
      boxShadow = paste0("inset 3px 0 0 0 ", base)
    ),
    pageButtonHoverStyle = list(backgroundColor = hover),
    pageButtonActiveStyle = list(
      backgroundColor = base,
      color = cor_texto_sobre(base)
    )
  )
}
