#' The application User-Interface
#'
#' @param request Internal parameter for `{shiny}`.
#'     DO NOT REMOVE.
#' @import shiny
#' @noRd
app_ui <- function(request) {
  tagList(
    # Deixando este chamado para adicionar os recursos externos do app
    golem_add_external_resources(),
    # Montando a página rolável com o tema visual do projeto
    bslib::page_fillable(
      padding = 0,
      gap = 0,
      fillable = FALSE,
      theme = tema_ibisma(),
      lang = "pt-BR",
      # Criando o ponto de ancoragem do topo da página
      htmltools::tags$a(id = "topo"),
      # Inserindo a barra de navegação por âncoras
      navbar_ibisma(),
      # Montando as seções do painel em página única
      htmltools::tags$main(
        class = "conteudo-painel",
        mod_onde_ui("onde"),
        mod_como_ui("como")
      ),
      # Inserindo o rodapé institucional
      rodape_ibisma()
    )
  )
}

# -----------------------------------------------------------------------------
#   COMPONENTES DA CASCA DO PAINEL
#   Tema, barra de navegação e rodapé, usados apenas pela interface do app.
#   Os nomes internos mantêm a sigla histórica do pacote; o índice exibido é o VIDAS.
# -----------------------------------------------------------------------------

#' Definindo uma função que monta o tema bslib do painel
#'
#' @return Objeto bs_theme com as cores e fontes do projeto.
#' @noRd
tema_ibisma <- function() {
  bslib::bs_theme(
    version = 5,
    bg = "#FFFFFF",
    fg = COR_AZUL_ESCURO,
    primary = COR_VIDAS,
    secondary = COR_AZUL_CLARO,
    base_font = bslib::font_collection(
      "'Source Sans Pro'",
      "system-ui",
      "sans-serif"
    ),
    heading_font = bslib::font_collection(
      "'Source Sans Pro'",
      "system-ui",
      "sans-serif"
    ),
    "body-bg" = "#FFFFFF",
    "border-radius" = "12px",
    "font-size-base" = "1rem"
  )
}

#' Definindo uma função que monta a barra de navegação fixa do painel
#'
#' @return Elemento HTML da navbar com âncoras para as seções.
#' @noRd
navbar_ibisma <- function() {
  # Montando uma navbar escura Bootstrap 5 com colapso automático em telas pequenas
  htmltools::tags$nav(
    class = "navbar navbar-expand-md navbar-dark navbar-ibisma",
    `aria-label` = "Navegação principal",
    id = "navbar-ibisma",
    htmltools::tags$div(
      class = "painel-container navbar-conteudo",
      # Ligando a marca do painel ao topo da página
      htmltools::tags$a(
        class = "navbar-brand",
        href = "#topo",
        `aria-label` = "Voltar ao topo",
        htmltools::tags$img(
          src = "www/logos/logo-oobr-curto.png",
          alt = "Observatório Obstétrico Brasileiro",
          class = "navbar-brand__logo"
        ),
        htmltools::tags$span(
          class = "navbar-brand__identidade",
          htmltools::tags$span(class = "navbar-brand__texto", "VIDAS"),
          # Mantendo a descrição do índice visível apenas quando houver espaço
          htmltools::tags$span(
            class = "navbar-brand__descricao d-none d-lg-block",
            "Índice de Vigilância dos Indicadores, Determinantes e Assistência à Saúde das Mulheres"
          )
        )
      ),
      # Criando o botão de menu para telas pequenas
      htmltools::tags$button(
        class = "navbar-toggler",
        type = "button",
        `data-bs-toggle` = "collapse",
        `data-bs-target` = "#menu-ibisma",
        `aria-controls` = "menu-ibisma",
        `aria-expanded` = "false",
        `aria-label` = "Abrir menu de navegação",
        htmltools::tags$span(class = "navbar-toggler-icon")
      ),
      # Listando as âncoras das seções do painel
      htmltools::tags$div(
        class = "collapse navbar-collapse",
        id = "menu-ibisma",
        htmltools::tags$ul(
          class = "navbar-nav ms-auto",
          htmltools::tags$li(
            class = "nav-item",
            htmltools::tags$a(class = "nav-link", href = "#onde", "Onde?")
          ),
          htmltools::tags$li(
            class = "nav-item",
            htmltools::tags$a(class = "nav-link", href = "#como", "Como?")
          )
        )
      )
    )
  )
}

#' Definindo uma função que monta o rodapé institucional do painel
#'
#' @return Elemento HTML do rodapé.
#' @noRd
rodape_ibisma <- function() {
  # Definindo os logos negativos e seus textos alternativos para o rodapé
  realizacao <- c(
    "logos/realizacao/logo_oobr_negativo.png" = "Observatório Obstétrico Brasileiro",
    "logos/realizacao/logo_fiocruz_negativo.png" = "Fiocruz",
    "logos/realizacao/logo_ufes_negativo.png" = "Universidade Federal do Espírito Santo",
    "logos/realizacao/logo_ufrj_negativo.png" = "Universidade Federal do Rio de Janeiro"
  )
  financiadores <- c(
    "logos/financiadores/logo_bill_melinda_negativo.png" = "Bill & Melinda Gates Foundation",
    "logos/financiadores/logo_cnpq_negativo.png" = "CNPq",
    "logos/financiadores/logo_fapes_negativo.png" = "FAPES"
  )

  # Montando uma faixa de logos a partir de um vetor nomeado
  faixa_logos <- function(logos) {
    htmltools::tags$div(
      class = "rodape-logos",
      lapply(names(logos), function(caminho) {
        htmltools::tags$img(
          src = paste0("www/", caminho),
          alt = logos[[caminho]],
          class = "rodape-logo",
          loading = "lazy",
          decoding = "async"
        )
      })
    )
  }

  htmltools::tags$footer(
    class = "rodape-painel",
    htmltools::tags$div(
      class = "painel-container",
      htmltools::tags$div(
        class = "rodape-grade",
        htmltools::tags$div(
          class = "rodape-bloco",
          htmltools::tags$h3(class = "rodape-titulo", "Realização"),
          faixa_logos(realizacao)
        ),
        htmltools::tags$div(
          class = "rodape-bloco",
          htmltools::tags$h3(class = "rodape-titulo", "Financiamento"),
          faixa_logos(financiadores)
        )
      ),
      htmltools::tags$div(
        class = "rodape-base",
        htmltools::tags$p(
          class = "rodape-nota",
          "Este painel está em desenvolvimento. ",
          "O Índice VIDAS é um índice relativo: seus valores representam a posição ",
          "dos municípios brasileiros em relação aos demais, não uma medida absoluta de saúde."
        )
      )
    )
  )
}

#' Add external Resources to the Application
#'
#' This function is internally used to add external
#' resources inside the Shiny application.
#'
#' @import shiny
#' @importFrom golem add_resource_path activate_js favicon
#' @noRd
golem_add_external_resources <- function() {
  add_resource_path(
    "www",
    app_sys("app/www")
  )

  # Definindo uma função local que evita cache antigo dos arquivos do painel
  recurso_com_versao <- function(caminho) {
    arquivo <- app_sys("app/www", caminho)
    versao <- format(file.info(arquivo)$mtime, "%Y%m%d%H%M%S")
    paste0("www/", caminho, "?v=", versao)
  }

  tags$head(
    favicon(),
    tags$title(
      "Índice VIDAS — Vigilância dos Indicadores, Determinantes e Assistência à Saúde das Mulheres"
    ),
    tags$meta(
      name = "description",
      content = paste0(
        "Painel interativo do Índice VIDAS, com o índice e as seis dimensões ",
        "que acompanham as condições de saúde das mulheres nos municípios brasileiros."
      )
    ),
    # Carregando a fonte institucional do Google Fonts
    tags$link(rel = "preconnect", href = "https://fonts.googleapis.com"),
    tags$link(
      rel = "preconnect",
      href = "https://fonts.gstatic.com",
      crossorigin = ""
    ),
    tags$link(
      rel = "stylesheet",
      href = "https://fonts.googleapis.com/css2?family=Source+Sans+Pro:ital,wght@0,300;0,400;0,600;0,700;1,400&display=swap"
    ),
    # Carregando o estilo e o script do painel com versão baseada na data
    tags$link(rel = "stylesheet", href = recurso_com_versao("global/custom.css")),
    tags$script(src = recurso_com_versao("global/funcoes_javascript.js"), defer = NA),
    golem::activate_js()
  )
}
