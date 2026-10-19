# =============================================================================
#   CONSULTA DOS DADOS PRONTOS DO PAINEL
#   O painel não faz contas sobre a base bruta: lê os arquivos gerados por
#   data-raw/cria_rda.R e devolve os recortes usados pelas seções.
# =============================================================================

# Criando um cache em memória para não reler os arquivos a cada sessão
.ibisma_cache <- new.env(parent = emptyenv())

#' Definindo uma função que obtém a base preparada do painel com cache
#'
#' @return Lista com o cadastro de municípios, os anos e as séries temporais.
#' Usada em: app_server.R (abertura do app), fct_dados.R (internamente) e mod_como.R.
#' @noRd
dados_ibisma <- function() {
  # Lendo o arquivo uma única vez por processo e reutilizando depois
  if (is.null(.ibisma_cache$dados)) {
    dados <- readRDS(app_sys("app", "data", "dados_ibisma.rds"))
    # Apontando a pasta onde ficam as tabelas anuais geradas
    dados$pasta_tabelas <- app_sys("app", "data")
    .ibisma_cache$dados <- dados
  }
  .ibisma_cache$dados
}

#' Definindo uma função que lê a tabela anual em cache
#'
#' @param dados Lista lida por dados_ibisma().
#' @param ano Ano de referência.
#' @return Data frame com uma linha por município e medida.
#' Usada em: fct_dados.R (valores_ano) e mod_como.R (resumo_municipio).
#' @noRd
tabela_ano <- function(dados, ano) {
  # Guardando em memória a tabela de cada ano já lida
  chave <- paste0("tabela_", dados$pasta_tabelas, "_", ano)
  if (!is.null(.ibisma_cache[[chave]])) {
    return(.ibisma_cache[[chave]])
  }

  # Lendo o arquivo gerado por data-raw/cria_rda.R
  arquivo <- file.path(
    dados$pasta_tabelas,
    sprintf("tabela_ano_%d.rds", ano)
  )
  if (!file.exists(arquivo)) {
    stop(
      "Tabela do ano ", ano, " não encontrada. ",
      "Rode data-raw/cria_rda.R para gerar os arquivos."
    )
  }
  .ibisma_cache[[chave]] <- readRDS(arquivo)
  .ibisma_cache[[chave]]
}

#' Definindo uma função que obtém os valores de uma medida em um ano
#'
#' @param dados Lista lida por dados_ibisma().
#' @param ano Ano de referência.
#' @param medida Identificador da medida ("indice_final", "bloco1"...).
#' @return Data frame com uma linha por município, já com categoria e rankings.
#' Usada em: fct_dados.R (municipio_padrao), fct_mapa.R (dados_mapa) e mod_onde.R (ranking).
#' @noRd
valores_ano <- function(dados, ano, medida) {
  # Selecionando a medida desejada dentro da tabela anual
  tabela <- tabela_ano(dados, ano)
  tabela[tabela$medida == medida, ]
}

#' Definindo uma função que descobre o município padrão de abertura do painel
#'
#' @param dados Lista lida por dados_ibisma().
#' @return Código do município com o menor Índice VIDAS do ano mais recente.
#' Usada em: app_server.R (município de abertura) e mod_como.R (valor inicial do seletor).
#' @noRd
municipio_padrao <- function(dados = dados_ibisma()) {
  # Abrindo o painel no município prioritário, com o menor Índice VIDAS do ano
  ano <- max(dados$anos)
  base <- valores_ano(dados, ano, "indice_final")
  base$codmunres[which.min(base$valor)]
}

#' Definindo uma função que obtém as séries das medidas e dos indicadores de um município
#'
#' @param dados Lista lida por dados_ibisma().
#' @param codmunres Código do município.
#' @param colunas Colunas pedidas; por padrão as sete medidas e os indicadores.
#' @return Data frame com uma linha por ano e uma coluna por coluna disponível.
#' Usada em: mod_como.R (evolução, comparação e indicadores).
#' @noRd
series_municipio <- function(dados, codmunres,
                             colunas = c(MEDIDAS$medida, INDICADORES$indicador)) {
  # Selecionando as linhas do município nas colunas disponíveis na base pronta
  serie <- dados$series[
    dados$series$codmunres == codmunres,
    intersect(c("ano", colunas), names(dados$series))
  ]
  row.names(serie) <- NULL
  serie
}

#' Definindo uma função que verifica se uma série tem algum valor para desenhar
#'
#' @param series Data frame retornado por series_municipio().
#' @param colunas Colunas consideradas na verificação; por padrão as sete medidas.
#' @return TRUE quando existe pelo menos um valor entre as colunas pedidas.
#' Usada em: mod_como.R (evolução, comparação e indicadores).
#' @noRd
series_tem_valor <- function(series, colunas = MEDIDAS$medida) {
  # Reunindo os valores das colunas pedidas que existem na série
  valores <- unlist(
    series[, intersect(colunas, names(series)), drop = FALSE],
    use.names = FALSE
  )
  any(!is.na(valores))
}

#' Definindo uma função que verifica se as séries já trazem os indicadores
#'
#' @param dados Lista lida por dados_ibisma().
#' @return TRUE quando todas as colunas de INDICADORES existem nas séries.
#' Usada em: mod_como.R (exibição da seção de indicadores).
#' @noRd
tem_indicadores <- function(dados) {
  # Exigindo a base completa, para a seção só aparecer com os dados reconstruídos
  all(INDICADORES$indicador %in% names(dados$series))
}

#' Definindo uma função que obtém os indicadores de um bloco
#'
#' @param bloco Identificador do bloco ("bloco1"..."bloco6").
#' @return Data frame com as linhas de INDICADORES do bloco pedido.
#' Usada em: mod_como.R (seção de indicadores do bloco).
#' @noRd
indicadores_do_bloco <- function(bloco) {
  # Mantendo a ordem canônica do dicionário dentro de cada bloco
  INDICADORES[INDICADORES$bloco == bloco, , drop = FALSE]
}

#' Definindo uma função que obtém os dados de um indicador no dicionário
#'
#' @param indicador Identificador do indicador (ex.: "PRE_NATAL").
#' @return Data frame de uma linha com os dados do indicador no dicionário.
#' Usada em: mod_como.R e fct_graficos_evolucao.R (título, unidade e cor do gráfico).
#' @noRd
info_indicador <- function(indicador) {
  # Buscando a linha do dicionário correspondente ao indicador
  INDICADORES[match(indicador, INDICADORES$indicador), , drop = FALSE]
}

#' Definindo uma função que obtém o nome de um município pelo código
#'
#' @param dados Lista lida por dados_ibisma().
#' @param codmunres Código do município.
#' @return Nome do município com a sigla da UF.
#' Usada em: mod_como.R (evolução e identificação dos gráficos).
#' @noRd
nome_municipio <- function(dados, codmunres) {
  info <- dados$municipios[dados$municipios$codmunres == codmunres, ]
  if (nrow(info) == 0) {
    return("Município")
  }
  paste0(info$municipio[1], " (", info$sigla_uf[1], ")")
}

#' Definindo uma função que obtém o nome por extenso de uma unidade da federação
#'
#' @param sigla Sigla da UF.
#' @return Nome da UF correspondente à sigla.
#' Usada em: mod_onde.R (resumo do ranking).
#' @noRd
nome_uf <- function(sigla) {
  # Buscando o nome nos municípios já preparados, sem tocar na base bruta
  ufs <- unique(dados_ibisma()$municipios[, c("sigla_uf", "uf")])
  ufs$uf[match(sigla, ufs$sigla_uf)]
}

#' Definindo uma função que obtém o nome de exibição de uma ou mais medidas
#'
#' @param medida Vetor de identificadores de medida ("indice_final", "bloco1"...).
#' @param prefixo_bloco Se TRUE, usa o rótulo com o prefixo "Bloco".
#' @return Vetor de nomes legíveis, na mesma ordem da entrada.
#' Usada em: fct_graficos_evolucao.R (títulos dos cartões), fct_mapa.R (tooltip do mapa),
#' mod_como.R (resumo do município) e mod_onde.R (resumo do ranking).
#' @noRd
nome_medida <- function(medida, prefixo_bloco = FALSE) {
  # Devolvendo o rótulo com o prefixo quando pedido
  if (prefixo_bloco) {
    return(MEDIDAS$rotulo[match(medida, MEDIDAS$medida)])
  }
  # Devolvendo o nome curto da medida
  MEDIDAS$nome[match(medida, MEDIDAS$medida)]
}

#' Definindo uma função que formata números na convenção brasileira
#'
#' @param x Vetor numérico.
#' @param decimais Número de casas decimais.
#' @return Vetor de texto com vírgula decimal.
#' Usada em: fct_mapa.R (tooltip do mapa), fct_perfil.R (valor do índice e frase do percentil) e fct_petalas.R (valor no disco).
#' @noRd
formatar_numero <- function(x, decimais = 1) {
  # Evitando erro em valores ausentes e formatando com vírgula
  ifelse(
    is.na(x),
    "Sem dados",
    formatC(x, format = "f", digits = decimais, decimal.mark = ",")
  )
}

#' Definindo uma função que formata inteiros na convenção brasileira
#'
#' @param x Vetor numérico.
#' @return Vetor de texto com separador de milhar.
#' Usada em: fct_dados.R (rótulo de posição) e mod_onde.R (resumo do ranking).
#' @noRd
formatar_inteiro <- function(x) {
  ifelse(
    is.na(x),
    "Sem dados",
    format(round(x), big.mark = ".", decimal.mark = ",", scientific = FALSE)
  )
}

#' Definindo uma função que monta o rótulo de posição no ranking
#'
#' @param posicao Posição do município.
#' @param total Número de municípios avaliados.
#' @return Texto no formato "1.234º de 5.570".
#' Usada em: fct_perfil.R (placar) e fct_petalas.R (tooltip da pétala).
#' @noRd
rotulo_posicao <- function(posicao, total) {
  paste0(formatar_inteiro(posicao), "º de ", formatar_inteiro(total))
}
