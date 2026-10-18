# =============================================================================
#   GERANDO OS DADOS DO PAINEL IBISMA
#   Rode na raiz do pacote, com o projeto aberto: botão Source do RStudio.
#   O script está em ordem de execução e imprime uma conferência a cada passo,
#   então também dá para rodar linha por linha (Ctrl+Enter) e ir acompanhando.
#
#   Antes de rodar, gere os CSVs da pipeline de indicadores, em
#   data-raw/scripts_bruno: cria_banco_dados_2024.R e depois criar_indice_final.R.
#
#   Etapas:
#     1. Base bruta: índice, blocos e indicadores (CSVs de data-raw/databases)
#     2. Constantes do índice (lidas de R/constantes.R)
#     3. Base longa (memória)
#     4. Tabelas por ano (inst/app/data/tabela_ano_*.rds)
#     5. Cadastro, anos e séries (inst/app/data/dados_ibisma.rds)
#     6. Malha geográfica e desenho do mapa (inst/app/data/malha_mapa.rds)
# =============================================================================

library(dplyr)
library(tidyr)

# =============================================================================
#   1. BASE BRUTA
# =============================================================================

# Lendo o índice e os seis blocos, em percentis, de 2015 a 2024
df_indice <- read.csv("data-raw/databases/indice_materno_final_2015_2024.csv")
print(head(df_indice))
cat("Linhas lidas:", nrow(df_indice), "\n")

# Lendo os indicadores brutos que compõem os blocos, exceto o de hemoterapia
df_indicadores <- read.csv("data-raw/databases/banco_dados_atualizado_2024_abril.csv") |>
  select(
    ano, codmunres,
    idhm, ESC_11, DEP_SUS, NASC_RACA, tx_homicidio_100mil,
    FEC_20, PRE_NATAL, DIST_RES, NASC_CES, cob_hosp_parto,
    prop_menor_1500, desp_total_hab_corrigido,
    tx_leitos_hospitalares_totais, tx_leitos_uti_total, mean_UTCI_C
  )

# Lendo o indicador bruto de hemoterapia, que entra no bloco Sistema de saúde
df_hemo <- read.csv("data-raw/databases/dados_servicos_hemo.csv") |>
  select(ano, codmunres, leitos_obst_med_transfusional = indicador5)

# Juntando o índice, os indicadores e a hemoterapia por município e ano
df_ibisma <- df_indice |>
  transmute(
    ano, codmunres,
    indice_final = indice_mf_v1,
    bloco1, bloco2, bloco3, bloco4, bloco5, bloco6
  ) |>
  left_join(df_indicadores, by = c("ano", "codmunres")) |>
  left_join(df_hemo, by = c("ano", "codmunres"))

# Conferindo se existem duplicatas e removendo
print(janitor::get_dupes(df_ibisma))
df_ibisma <- df_ibisma |>
  distinct()

# Lendo a tabela auxiliar com nome, UF, região e regiões de saúde
df_aux_municipios <- read.csv("data-raw/databases/tabela_aux_municipios.csv")
print(head(df_aux_municipios))

# Adicionando a sigla da UF em uma coluna nova
df_aux_municipios <- df_aux_municipios |>
  mutate(
    sigla_uf = case_when(
      uf == "Acre" ~ "AC",
      uf == "Alagoas" ~ "AL",
      uf == "Amapá" ~ "AP",
      uf == "Amazonas" ~ "AM",
      uf == "Bahia" ~ "BA",
      uf == "Ceará" ~ "CE",
      uf == "Distrito Federal" ~ "DF",
      uf == "Espírito Santo" ~ "ES",
      uf == "Goiás" ~ "GO",
      uf == "Maranhão" ~ "MA",
      uf == "Mato Grosso" ~ "MT",
      uf == "Mato Grosso do Sul" ~ "MS",
      uf == "Minas Gerais" ~ "MG",
      uf == "Pará" ~ "PA",
      uf == "Paraíba" ~ "PB",
      uf == "Paraná" ~ "PR",
      uf == "Pernambuco" ~ "PE",
      uf == "Piauí" ~ "PI",
      uf == "Rio de Janeiro" ~ "RJ",
      uf == "Rio Grande do Norte" ~ "RN",
      uf == "Rio Grande do Sul" ~ "RS",
      uf == "Rondônia" ~ "RO",
      uf == "Roraima" ~ "RR",
      uf == "Santa Catarina" ~ "SC",
      uf == "São Paulo" ~ "SP",
      uf == "Sergipe" ~ "SE",
      uf == "Tocantins" ~ "TO",
      TRUE ~ NA_character_
    ),
    .after = "uf"
  )

# Juntando os dados dos municípios na base do IBISMA
df_ibisma <- df_ibisma |>
  left_join(df_aux_municipios, by = c("codmunres" = "codmun"))

# Conferindo o resultado
cat(
  "Base bruta:", nrow(df_ibisma), "linhas |",
  n_distinct(df_ibisma$codmunres), "municípios |",
  paste(range(df_ibisma$ano), collapse = " a "), "|",
  sum(is.na(df_ibisma$sigla_uf)), "linhas sem UF", "\n"
)
print(colnames(df_ibisma))

# =============================================================================
#   2. CONSTANTES DO ÍNDICE
#   Medidas e categorias vêm de R/constantes.R, a fonte única que o app usa;
#   os cortes de percentis só existem na geração
# =============================================================================

# Carregando as definições do painel em um ambiente próprio, sem tocar no global
config <- new.env(parent = globalenv())
sys.source("R/constantes.R", envir = config)

# Trazendo para o script os objetos usados na geração, com o mesmo nome do app
usar <- function(nome) {
  valor <- config[[nome]]
  assign(nome, valor, envir = globalenv())
  cat("Config:", nome, "->", length(valor), "itens\n")
}
usar("MEDIDAS")
usar("CATEGORIAS")
usar("INDICADORES")

# Nomes das colunas que viram medidas no formato longo
medidas <- MEDIDAS$medida

# Nomes das colunas dos indicadores brutos que compõem os blocos
indicadores <- INDICADORES$indicador

# Rótulos das cinco categorias, do menos para o mais vulnerável
categorias <- CATEGORIAS

# Percentis que cortam as cinco categorias (específicos da geração dos dados)
cortes_percentis <- c(0.2, 0.4, 0.6, 0.8)

# Ampliando os indicadores guardados como proporção (fator 100 = %)
fatores <- stats::setNames(INDICADORES$fator, INDICADORES$indicador)
df_ibisma <- df_ibisma |>
  mutate(across(all_of(indicadores), ~ .x * fatores[[cur_column()]])) |>
  # Convertendo resultados indefinidos das divisões em valores ausentes
  mutate(across(all_of(indicadores), ~ replace(.x, is.nan(.x), NA)))

# =============================================================================
#   3. BASE LONGA
#   Uma linha por município, ano e medida, com os valores de 0 a 100
# =============================================================================

ibisma_longo <- df_ibisma |>
  # Transformando as sete colunas de medidas em duas (medida e valor)
  pivot_longer(
    cols = all_of(medidas),
    names_to = "medida",
    values_to = "valor"
  ) |>
  # Convertendo os valores de 0 a 1 para 0 a 100
  mutate(valor = 100 * valor) |>
  # Mantendo só as colunas usadas pelo painel
  select(
    ano, codmunres, medida, valor,
    municipio, sigla_uf, uf, regiao, r_saude, macro_r_saude
  ) |>
  # Ordenando para facilitar a conferência
  arrange(ano, codmunres, medida)

# Conferindo: cada linha da base bruta vira sete linhas na base longa
cat("Linhas na base longa:", nrow(ibisma_longo), "\n")
cat("Faixa dos valores:", paste(range(ibisma_longo$valor), collapse = " a "), "\n")
print(head(ibisma_longo))

# =============================================================================
#   4. TABELAS POR ANO
#   Para cada ano e medida: categoria (quintis do ano) e rankings Brasil/UF
# =============================================================================

# Criando a pasta que guarda os arquivos lidos pelo painel
dir.create("inst/app/data", showWarnings = FALSE, recursive = TRUE)

# Percorrendo os dez anos da base
for (ano_atual in sort(unique(df_ibisma$ano))) {
  # Filtrando o ano
  base_ano <- filter(ibisma_longo, ano == ano_atual)

  # Classificando nas cinco categorias pelos quintis de cada medida no ano
  tabela_ano <- base_ano |>
    group_by(medida) |>
    mutate(
      corte = findInterval(valor, quantile(valor, cortes_percentis, na.rm = TRUE)),
      categoria = factor(categorias[corte + 1], levels = categorias, ordered = TRUE)
    ) |>
    ungroup() |>
    select(-corte)

  # Ranqueando os municípios no Brasil (posição 1 = mais vulnerável)
  tabela_ano <- tabela_ano |>
    group_by(medida) |>
    mutate(
      pos_nac = rank(-valor, ties.method = "min", na.last = "keep"),
      total_nac = sum(!is.na(valor))
    ) |>
    ungroup()

  # Ranqueando os municípios dentro da própria UF
  tabela_ano <- tabela_ano |>
    group_by(medida, sigla_uf) |>
    mutate(
      pos_uf = rank(-valor, ties.method = "min", na.last = "keep"),
      total_uf = sum(!is.na(valor))
    ) |>
    ungroup()

  # Salvando a tabela do ano
  arquivo <- sprintf("inst/app/data/tabela_ano_%d.rds", ano_atual)
  saveRDS(tabela_ano, arquivo, compress = "xz")

  # Conferindo a tabela do ano
  cat(
    ano_atual, "->", basename(arquivo), "|",
    nrow(tabela_ano), "linhas |",
    n_distinct(tabela_ano$medida), "medidas\n"
  )
}

# =============================================================================
#   5. CADASTRO, ANOS E SÉRIES
# =============================================================================

# Montando o cadastro de municípios (uma linha por município)
municipios <- df_ibisma |>
  distinct(
    codmunres, municipio, sigla_uf, uf,
    regiao, r_saude, macro_r_saude
  ) |>
  arrange(municipio)

# Lista dos anos disponíveis
anos <- sort(unique(df_ibisma$ano))

# Montando as séries: uma linha por município e ano, com medidas e indicadores
series <- ibisma_longo |>
  select(ano, codmunres, medida, valor) |>
  pivot_wider(names_from = medida, values_from = valor) |>
  # Acrescentando os indicadores brutos que compõem os blocos
  left_join(
    select(df_ibisma, ano, codmunres, all_of(indicadores)),
    by = c("ano", "codmunres")
  ) |>
  # Preenchendo os anos que faltam em cada município (Borá não tem 2023)
  group_by(codmunres) |>
  complete(ano = anos) |>
  ungroup() |>
  arrange(codmunres, ano) |>
  select(codmunres, ano, all_of(medidas), all_of(indicadores))

# Conferindo: os anos sem dado aparecem com NA (Borá em 2023)
print(filter(series, is.na(indice_final)))

# Conferindo a cobertura de cada indicador nas séries montadas
cobertura <- vapply(series[indicadores], function(x) mean(!is.na(x)), numeric(1))
print(round(100 * cobertura, 1))

# Salvando o cadastro, os anos e as séries em um arquivo único
saveRDS(
  list(
    municipios = municipios,
    anos = anos,
    series = series
  ),
  "inst/app/data/dados_ibisma.rds",
  compress = "xz"
)

# Conferindo os arquivos gerados
arquivos <- list.files("inst/app/data", pattern = "\\.rds$", full.names = TRUE)
cat(
  "Arquivos em inst/app/data:", length(arquivos),
  "| total:", round(sum(file.size(arquivos)) / 1024^2, 2), "MB\n"
)
cat(
  "Séries:", nrow(series), "linhas |",
  nrow(municipios), "municípios |",
  length(anos), "anos |",
  length(indicadores), "indicadores\n"
)

# =============================================================================
#   6. MALHA GEOGRÁFICA E DESENHO DO MAPA
# =============================================================================

library(geobr)
library(sf)
library(rmapshaper)
library(jsonlite)

# Arredondando as coordenadas para 4 casas (cerca de 11 metros), abaixo de um
# pixel na escala máxima do painel e com um volume bem menor para o navegador
arredondar_coordenadas <- function(geometria, casas = 4) {
  # Percorrendo matrizes e listas da geometria até chegar nas coordenadas
  arredondar <- function(x) {
    if (is.matrix(x)) return(round(x, casas))
    if (is.list(x)) {
      x[] <- lapply(x, arredondar)
      return(x)
    }
    x
  }
  st_sfc(lapply(geometria, arredondar), crs = st_crs(geometria))
}

# Consertando a topologia da malha com o -clean do mapshaper: a versão
# simplificada do geobr chega com as divisas duplicadas entre municípios
# vizinhos (micro-fendas e sobreposições medidos); o -clean funde as cópias,
# preenche as fendas e reparte as sobreposições, deixando a simplificação
# seguinte preservar de verdade as divisas compartilhadas
# Obs.: o rmapshaper não exporta o -clean, então a chamada usa o mesmo caminho
# interno do ms_simplify: sf -> GeoJSON -> comandos do mapshaper -> sf
limpar_malha <- function(malha) {
  geojson <- rmapshaper:::sf_to_GeoJSON(malha, file = FALSE)
  limpa <- rmapshaper::apply_mapshaper_commands(geojson, command = "-clean")
  rmapshaper:::GeoJSON_to_sf(limpa, crs = attr(geojson, "crs"))
}

# ---------------------------------------------------------------- municípios

# Baixando a malha municipal (já vem simplificada pelo geobr)
malha_municipios <- read_municipality(year = 2020, showProgress = FALSE)

# Criando a chave de 6 dígitos usada pela base do IBISMA (padrão DATASUS)
malha_municipios <- malha_municipios |>
  mutate(
    codmunres = as.integer(substr(as.character(code_muni), 1, 6)),
    .before = "geometry"
  ) |>
  # Mantendo apenas as colunas necessárias para o painel
  select(codmunres, sigla_uf = abbrev_state, geometry)

# Consertando a topologia antes de simplificar, para não sobrar fenda nenhuma
malha_municipios <- limpar_malha(malha_municipios)

# Recriando a chave como inteiro (a ida ao mapshaper devolve número decimal)
malha_municipios <- malha_municipios |>
  mutate(codmunres = as.integer(codmunres))

# Simplificando cada divisa uma única vez, agora sobre uma malha sem fendas;
# o keep foi calibrado para o mosaico manter o mesmo nível de detalhe de antes
malha_municipios <- ms_simplify(
  malha_municipios,
  keep = 0.12,
  keep_shapes = TRUE
)

# Convertendo para WGS84, o sistema esperado pelo leaflet
malha_municipios <- st_transform(malha_municipios, 4326)

# ------------------------------------------------- unidades da federação

# Derivando os contornos estaduais do próprio mosaico municipal, para a linha
# da UF coincidir exatamente com a borda formada pelos municípios
sf_use_s2(FALSE)
malha_ufs <- suppressMessages(
  malha_municipios |>
    group_by(sigla_uf) |>
    summarise(geometry = st_union(geometry), .groups = "drop")
)
malha_ufs <- st_set_geometry(
  malha_ufs,
  st_cast(st_geometry(malha_ufs), "MULTIPOLYGON")
)

# ---------------------------------------------------------------- arredondamento

# Arredondando as coordenadas das duas malhas antes de salvar
malha_municipios <- st_set_geometry(
  malha_municipios,
  arredondar_coordenadas(st_geometry(malha_municipios))
)
malha_ufs <- st_set_geometry(
  malha_ufs,
  arredondar_coordenadas(st_geometry(malha_ufs))
)

# Removendo geometrias vazias que possam ter surgido na simplificação
malha_municipios <- malha_municipios[!st_is_empty(malha_municipios), ]
malha_ufs <- malha_ufs[!st_is_empty(malha_ufs), ]

# ---------------------------------------------------------------- conferências

# Conferindo a cobertura dos códigos de município da base do IBISMA
cat(
  "Cobertura da malha:",
  round(100 * mean(municipios$codmunres %in% malha_municipios$codmunres), 2),
  "% dos códigos\n"
)
cat("Municípios na malha:", nrow(malha_municipios), "\n")
cat("UFs na malha:", nrow(malha_ufs), "\n")

# ---------------------------------------------------------------- salvamento

saveRDS(malha_municipios, "inst/app/data/malha_municipios.rds", compress = "xz")
saveRDS(malha_ufs, "inst/app/data/malha_ufs.rds", compress = "xz")
cat(
  "Malha salva:",
  round(file.size("inst/app/data/malha_municipios.rds") / 1024^2, 2), "MB",
  "(municípios) e",
  round(file.size("inst/app/data/malha_ufs.rds") / 1024^2, 2), "MB (UFs)\n"
)

# ---------------------------------------------------------- desenho do mapa

# Convertendo a geometria para o formato colunar (lng/lat) que o leaflet usa no
# addPolygons: por município, uma lista de polígonos e, em cada um, os anéis
desenho_municipios <- function(geometria) {
  # Convertendo a matriz de coordenadas de um anel em um data frame lng/lat
  para_anel <- function(anel) {
    data.frame(lng = anel[, 1], lat = anel[, 2])
  }
  # Convertendo cada polígono na lista dos seus anéis
  para_poligono <- function(poligono) {
    lapply(unclass(poligono), para_anel)
  }
  lapply(geometria, function(municipio) {
    # POLYGON vira um polígono e MULTIPOLYGON vira uma lista de polígonos
    if (inherits(municipio, "MULTIPOLYGON")) {
      lapply(unclass(municipio), para_poligono)
    } else {
      list(para_poligono(municipio))
    }
  })
}

# Gerando uma única vez o texto JSON que o navegador usa para desenhar o mapa
poligonos <- desenho_municipios(st_geometry(malha_municipios))
pgons <- as.character(jsonlite::toJSON(
  poligonos,
  dataframe = "columns",
  auto_unbox = TRUE,
  digits = 4
))

# Salvando o desenho pronto (texto dos polígonos e identificadores das camadas)
saveRDS(
  list(pgons = pgons, layers = as.character(malha_municipios$codmunres)),
  "inst/app/data/malha_mapa.rds",
  compress = "xz"
)
cat(
  "Desenho do mapa:", round(nchar(pgons) / 1024^2, 2), "MB de JSON |",
  round(file.size("inst/app/data/malha_mapa.rds") / 1024^2, 2), "MB em disco |",
  nrow(malha_municipios), "municípios\n"
)
