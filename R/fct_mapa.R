# =============================================================================
#   FUNÇÕES AUXILIARES DO MAPA
#   Prepara a malha, o desenho enviado por mensagem e os dados compactos que
#   alimentam o mapa, além de definir o estilo-base do mapa do painel.
# =============================================================================

# Guardando a malha e o desenho em memória para não reler os arquivos a cada sessão
.malha_cache <- new.env(parent = emptyenv())

#' Definindo uma função que carrega a malha municipal simplificada
#'
#' @return Objeto sf com os polígonos dos municípios brasileiros.
#' Usada em: fct_mapa.R (dados_mapa) e mod_onde.R (destaque do município selecionado).
#' @noRd
carregar_malha_municipios <- function() {
  # Lendo o arquivo apenas na primeira chamada e reutilizando depois
  if (is.null(.malha_cache$municipios)) {
    .malha_cache$municipios <- readRDS(
      app_sys("app", "data", "malha_municipios.rds")
    )
  }
  .malha_cache$municipios
}

#' Definindo uma função que carrega a malha estadual simplificada
#'
#' @return Objeto sf com os polígonos das unidades da federação.
#' Usada em: fct_mapa.R (desenhar_ufs, limites_escopo e destacar_uf).
#' @noRd
carregar_malha_ufs <- function() {
  # Lendo o arquivo apenas na primeira chamada e reutilizando depois
  if (is.null(.malha_cache$ufs)) {
    .malha_cache$ufs <- readRDS(
      app_sys("app", "data", "malha_ufs.rds")
    )
  }
  .malha_cache$ufs
}

#' Definindo uma função que carrega o desenho pronto dos municípios
#'
#' Guarda o texto dos polígonos e os identificadores das camadas gerados por
#' data-raw/cria_rda.R, evitando converter o sf a cada sessão do painel.
#'
#' @return Lista com o texto JSON dos polígonos e os códigos das camadas.
#' Usada em: fct_mapa.R (enviar_desenho_municipios) e testes do desenho.
#' @noRd
carregar_desenho_municipios <- function() {
  # Lendo o arquivo apenas na primeira chamada e reutilizando depois
  if (is.null(.malha_cache$desenho)) {
    arquivo <- app_sys("app", "data", "malha_mapa.rds")
    if (!file.exists(arquivo)) {
      stop(
        "Desenho do mapa não encontrado. ",
        "Rode data-raw/cria_rda.R para gerar o arquivo."
      )
    }
    .malha_cache$desenho <- readRDS(arquivo)
  }
  .malha_cache$desenho
}

#' Definindo uma função que prepara os dados compactos que alimentam o mapa
#'
#' Os valores ficam na ordem da malha (a mesma das camadas do mapa) e os textos
#' são curtos: o HTML do tooltip é montado no JavaScript do painel.
#'
#' @param dados Lista lida por dados_ibisma().
#' @param ano Ano de referência.
#' @param medida Identificador da medida exibida.
#' @return Data frame com nome, UF, valor em texto e código da categoria.
#' Usada em: mod_onde.R (reactive do mapa).
#' @noRd
dados_mapa <- function(dados, ano, medida) {
  # Buscando os valores do ano e da medida selecionados
  base <- valores_ano(dados, ano, medida)

  # Alinhando os valores à ordem da malha, que é a ordem das camadas do mapa
  malha <- carregar_malha_municipios()
  indice <- match(malha$codmunres, base$codmunres)
  valor <- base$valor[indice]
  categoria <- as.character(base$categoria[indice])

  # Buscando nome e UF no cadastro para municípios sem valor no ano (ex.: Borá/2023)
  cadastro <- match(malha$codmunres, dados$municipios$codmunres)

  # Montando as colunas compactas consumidas pelo JavaScript do mapa
  data.frame(
    municipio = dados$municipios$municipio[cadastro],
    sigla_uf = dados$municipios$sigla_uf[cadastro],
    valor_texto = ifelse(is.na(valor), "—", formatar_numero(valor)),
    categoria_cod = match(categoria, CATEGORIAS),
    stringsAsFactors = FALSE
  )
}

#' Definindo uma função que monta a mensagem com os dados do mapa
#'
#' A paleta, os rótulos das categorias e as cores de texto vão uma única vez
#' por mensagem; por município vão apenas nome, UF, valor e categoria.
#'
#' @param output_id Identificador do output do mapa.
#' @param base Data frame retornado por dados_mapa().
#' @param medida Identificador da medida exibida no mapa.
#' @return Lista pronta para o sendCustomMessage do Shiny.
#' Usada em: fct_mapa.R (enviar_desenho_municipios e atualizar_municipios).
#' @noRd
mensagem_mapa <- function(output_id, base, medida) {
  list(
    id = output_id,
    medida = nome_medida(medida),
    municipios = base$municipio,
    ufs = base$sigla_uf,
    valores = base$valor_texto,
    categorias = base$categoria_cod,
    paleta = unname(PALETAS[[medida]]),
    rotulos = unname(CATEGORIAS),
    cores_texto = unname(cor_texto_sobre(PALETAS[[medida]])),
    cor_sem_dados = COR_SEM_DADOS,
    cor_texto_sem_dados = cor_texto_sobre(COR_SEM_DADOS)
  )
}

#' Definindo uma função que cria o mapa-base do painel
#'
#' @return Objeto leaflet sem camadas de dados.
#' Usada em: mod_onde.R (desenho do mapa).
#' @noRd
mapa_base <- function() {
  # Configurando um mapa limpo, sem tiles externos e com desenho em canvas
  leaflet::leaflet(
    options = leaflet::leafletOptions(
      preferCanvas = TRUE,
      attributionControl = FALSE,
      # Limitando o zoom mínimo ao enquadramento que mostra o Brasil inteiro
      minZoom = 4,
      maxZoom = 10,
      maxBoundsViscosity = 1.0,
      zoomControl = TRUE
    )
  ) |>
    # Impedindo que o usuário afaste ou arraste o mapa para fora do Brasil
    leaflet::setMaxBounds(
      lng1 = -75.0, lat1 = -34.5,
      lng2 = -32.0, lat2 = 6.0
    ) |>
    # Enquadrando o Brasil no carregamento inicial
    leaflet::fitBounds(lng1 = -74, lat1 = -34, lng2 = -34, lat2 = 6) |>
    # Criando a camada que mantém os contornos das UFs acima dos municípios
    leaflet::addMapPane("ufs", zIndex = 450) |>
    # Criando a camada que apaga as UFs fora do escopo, entre municípios e UFs
    leaflet::addMapPane("apagado", zIndex = 445) |>
    # Criando a camada do contorno do município selecionado, acima das UFs
    leaflet::addMapPane("destaque", zIndex = 460)
}

#' Definindo uma função que envia ao navegador o desenho e os dados dos municípios
#'
#' O texto dos polígonos e os identificadores das camadas vêm prontos de
#' data-raw/cria_rda.R, então a geometria não é convertida nem serializada a
#' cada sessão; o JavaScript cria as camadas com o próprio binding do leaflet.
#'
#' @param session Sessão do Shiny.
#' @param output_id Identificador do output do mapa.
#' @param base Data frame retornado por dados_mapa().
#' @param medida Identificador da medida exibida no mapa.
#' @return Nada; envia a mensagem para o JavaScript do painel.
#' Usada em: mod_onde.R (desenho inicial do mapa).
#' @noRd
enviar_desenho_municipios <- function(session, output_id, base, medida) {
  # Montando a mensagem com os dados e acrescentando o desenho pronto
  desenho <- carregar_desenho_municipios()
  mensagem <- mensagem_mapa(output_id, base, medida)
  mensagem$pgons <- desenho$pgons
  mensagem$layers <- desenho$layers

  # Criando as camadas e preenchendo cores e tooltips em uma única mensagem
  session$sendCustomMessage("ibisma_mapa_desenha", mensagem)
}

#' Definindo uma função que envia ao navegador a atualização de cores e tooltips do mapa
#'
#' @param session Sessão do Shiny.
#' @param output_id Identificador do output do mapa.
#' @param base Data frame retornado por dados_mapa().
#' @param medida Identificador da medida exibida no mapa.
#' @return Nada; envia a mensagem para o JavaScript do painel.
#' Usada em: mod_onde.R (atualização das cores e tooltips).
#' @noRd
atualizar_municipios <- function(session, output_id, base, medida) {
  # Atualizando os polígonos já desenhados sem reenviar a geometria
  session$sendCustomMessage(
    "ibisma_mapa_atualiza",
    mensagem_mapa(output_id, base, medida)
  )
}

#' Definindo uma função que desenha os contornos das unidades da federação
#'
#' @param mapa Objeto leaflet.
#' @return Objeto leaflet com a camada de contornos estaduais.
#' Usada em: mod_onde.R (desenho do mapa).
#' @noRd
desenhar_ufs <- function(mapa) {
  # Sobrepondo os limites estaduais sem interferir na interação dos municípios
  malha_ufs <- carregar_malha_ufs()
  mapa |>
    leaflet::addPolygons(
      data = malha_ufs,
      fill = FALSE,
      # Suavizando o contorno estadual para não competir com as divisas finas
      color = "#FFFFFF",
      weight = 0.75,
      opacity = 0.75,
      smoothFactor = 0,
      # Desenhando no painel acima dos municípios, sem capturar o mouse
      options = leaflet::pathOptions(pane = "ufs", interactive = FALSE)
    )
}

#' Definindo uma função que calcula o retângulo de enquadramento de um escopo
#'
#' @param escopo Escopo escolhido no ranking ("nacional" ou a sigla de uma UF).
#' @return Lista com lng1, lat1, lng2, lat2 do retângulo que enquadra o escopo.
#' Usada em: fct_mapa.R (enquadrar_escopo) e testes do enquadramento.
#' @noRd
limites_escopo <- function(escopo) {
  # Usando o mesmo retângulo do enquadramento inicial do Brasil no cliente
  if (identical(escopo, "nacional")) {
    return(list(lng1 = -74.5, lat1 = -34.5, lng2 = -33.5, lat2 = 6.5))
  }

  # Buscando a caixa envolvente da UF na malha estadual em cache
  malha <- carregar_malha_ufs()
  estado <- malha[malha$sigla_uf == escopo, ]

  # Descartando as partes que ficam fora do quadro máximo do mapa (ex.: a Ilha
  # da Trindade, no ES): elas nunca aparecem na tela e só esticariam o voo
  partes <- sf::st_cast(sf::st_geometry(estado), "POLYGON")
  dentro <- vapply(seq_along(partes), function(i) {
    sf::st_bbox(partes[i])[["xmin"]] <= -32
  }, logical(1))
  caixa <- sf::st_bbox(partes[dentro])
  list(
    lng1 = unname(caixa[["xmin"]]),
    lat1 = unname(caixa[["ymin"]]),
    lng2 = unname(caixa[["xmax"]]),
    lat2 = unname(caixa[["ymax"]])
  )
}

#' Definindo uma função que enquadra o mapa no escopo escolhido
#'
#' A câmera voa até o enquadramento com o flyToBounds nativo do leaflet, que
#' anima qualquer combinação de deslocamento e zoom sem recriar o widget.
#'
#' @param session Sessão do Shiny.
#' @param output_id Identificador do output do mapa.
#' @param escopo "nacional" ou a sigla de uma UF.
#' @return Nada; envia ao navegador o novo enquadramento do mapa.
#' Usada em: fct_mapa.R (aplicar_escopo) e testes do enquadramento.
#' @noRd
enquadrar_escopo <- function(session, output_id, escopo) {
  # Calculando os limites do escopo e voando até eles, mesmo em saltos curtos
  limites <- limites_escopo(escopo)
  leaflet::leafletProxy(output_id, session = session) |>
    leaflet::flyToBounds(
      lng1 = limites$lng1, lat1 = limites$lat1,
      lng2 = limites$lng2, lat2 = limites$lat2,
      options = list(
        # Duração fixa de 0,8 s para o voo ser previsível em qualquer distância
        duration = 0.8,
        # Reservando 16 px de folga em cada lado para o enquadramento não colar
        padding = c(32, 32)
      )
    )
}

#' Definindo uma função que destaca a UF escolhida no mapa
#'
#' O destaque é por contraste: as UFs fora do escopo recebem um véu na cor do
#' fundo do mapa, enquanto a UF escolhida fica com as cores dos percentis
#' intactas. O véu fica entre os municípios e os contornos das UFs, de modo
#' que as divisas seguem legíveis como referência geográfica.
#'
#' @param session Sessão do Shiny.
#' @param output_id Identificador do output do mapa.
#' @param escopo "nacional" ou a sigla de uma UF.
#' @return Nada; desenha ou remove o véu sobre as UFs fora do escopo.
#' Usada em: fct_mapa.R (aplicar_escopo) e testes do destaque.
#' @noRd
destacar_uf <- function(session, output_id, escopo) {
  # Removendo o véu anterior: um identificador por UF, sem depender do escopo
  proxy <- leaflet::leafletProxy(output_id, session = session)
  malha <- carregar_malha_ufs()
  for (sigla in malha$sigla_uf) {
    proxy <- leaflet::removeShape(proxy, paste0("apagado_", sigla))
  }

  # No escopo nacional o mapa fica sem destaque de UF
  if (identical(escopo, "nacional")) {
    return(invisible(NULL))
  }

  # Buscando as demais UFs na malha estadual em cache
  fora <- malha[malha$sigla_uf != escopo, ]

  # Cobrindo as demais UFs com um véu na cor do fundo do mapa: o leaflet
  # guarda um identificador por camada, então cada UF leva o seu
  leaflet::addPolygons(
    proxy,
    data = fora,
    layerId = paste0("apagado_", fora$sigla_uf),
    fill = TRUE,
    # Mesma cor de --cor-fundo-mapa, para as demais UFs recuarem para o fundo
    fillColor = "#EDF1F7",
    fillOpacity = 0.5,
    stroke = FALSE,
    smoothFactor = 0,
    options = leaflet::pathOptions(pane = "apagado", interactive = FALSE)
  )
}

#' Definindo uma função que aplica um escopo ao mapa
#'
#' @param session Sessão do Shiny.
#' @param output_id Identificador do output do mapa.
#' @param escopo "nacional" ou a sigla de uma UF.
#' @return Nada; destaca a UF e voa até o enquadramento do escopo.
#' Usada em: mod_onde.R (mudança de escopo e fim da montagem do mapa).
#' @noRd
aplicar_escopo <- function(session, output_id, escopo) {
  # Destacando primeiro, para a UF de destino já estar evidente durante o voo
  destacar_uf(session, output_id, escopo)
  enquadrar_escopo(session, output_id, escopo)
}

#' Definindo uma função que monta a legenda das cinco categorias do mapa
#'
#' @param paleta Vetor nomeado com as cores das categorias.
#' @param titulo Título curto da legenda.
#' @param com_sem_dados Incluir a entrada "Sem dados" (desativado no painel).
#' @return Elemento HTML com a legenda completa.
#' Usada em: mod_onde.R (legenda do mapa).
#' @noRd
legenda_categorias <- function(paleta = PALETAS$indice_final,
                               titulo = NULL, com_sem_dados = FALSE) {
  # Montando um item de legenda para cada categoria
  itens <- lapply(names(paleta), function(nome) {
    htmltools::tags$span(
      class = "legenda-item",
      htmltools::tags$span(class = "legenda-cor", style = paste0("background:", paleta[[nome]], ";")),
      htmltools::tags$span(class = "legenda-rotulo", nome)
    )
  })

  # Acrescentando a entrada de municípios sem dado, quando pedido
  if (com_sem_dados) {
    itens <- c(itens, list(
      htmltools::tags$span(
        class = "legenda-item legenda-item--sem-dados",
        htmltools::tags$span(class = "legenda-cor", style = paste0("background:", COR_SEM_DADOS, ";")),
        htmltools::tags$span(class = "legenda-rotulo", "Sem dados")
      )
    ))
  }

  htmltools::tags$div(
    class = "legenda-categorias",
    if (!is.null(titulo)) htmltools::tags$span(class = "legenda-titulo", titulo),
    htmltools::tags$div(class = "legenda-itens", itens)
  )
}

