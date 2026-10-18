# ==============================================================================
# Índice final de vulnerabilidade materna (indice_mf_v1)
# Período de referência: 2015–2024
#
# Entrada esperada:
#   banco_dados_atualizado_2024_abril.csv
#   dados_servicos_hemo.csv
#
# Saídas:
#   indice_materno_final_2015_2024.csv
#   objeto R `var_indice`, contendo `indice_mf_v1` (0–1) e
#   `indice_mf_v1_0_100` (0–100).
#
# ==============================================================================

library(dplyr)
library(readr)

# ------------------------------------------------------------------------------
# 1. Arquivos de entrada
# ------------------------------------------------------------------------------

arquivo_base <- "banco_dados_atualizado_2024_abril.csv"
arquivo_hemoterapia <- "dados_servicos_hemo.csv"
arquivo_saida <- "indice_materno_final_2015_2024.csv"

# ------------------------------------------------------------------------------
# 2. Pesos fixos
# ------------------------------------------------------------------------------
# Os pesos são relativos: multiplicar todos os pesos de um mesmo conjunto por
# uma constante não altera o percentil resultante.

pesos_bloco1 <- c(
  B1_1 = 4.42, # IDHM
  B1_2 = 3.47, # Porcentagem de nascidos vivos de mães com mais de 11 anos de estudo
  B1_3 = 3.76, # Porcentagem de mulheres com 10 a 49 anos usuárias exclusivas do SUS
  B1_4 = 3.13, # Porcentagem de nascidos vivos de mães de raça/cor negras (pretas + pardas) + indígenas
  B1_5 = 1.00  # Taxa de homicídio por 100.000 habitantes
)

pesos_bloco4 <- c(
  B4_1 = 1.00, # Medianas de deslocamento para partos ocorridos fora do municipio de residência da mulher
  B4_2 = 2.05, # Porcentagem de nascidos vivos por cesariana
  B4_3 = 2.31  # Porcentagem de partos ocorridos em hospitais
)

pesos_bloco5 <- c(
  B5_1   = 1.00, # Porcentagem de nascidos com peso <1500g em serviços com UTI neonatal
  B5_2   = 1.20, # Despesa total municipal com saúde, per capita, corrigido pelo IPCA de dez. 2024
  B5_3   = 2.72, # Taxa de leitos hospitalares por 10.000 habitantes na macrorregião de saúde
  B5_4   = 3.77, # Taxa de leito de UTI por 10.000 habitantes na macrorregião de saúde
  B5_5_5 = 1.20  # Porcentagem de leitos obstétricos em hospitais com serviço de medicina transfusional
)

pesos_blocos <- c(
  bloco1 = 1.46,
  bloco2 = 1.00,
  bloco3 = 1.08,
  bloco4 = 1.08,
  bloco5 = 1.02,
  bloco6 = 1.15
)

# Indicadores dos demais blocos:
## Bloco 2: Taxa específica de fecundidade de mulheres com menos de 20 anos de idade (por mil)
## Bloco 3: Porcentagem de mulheres com início do pré-natal no primeiro trimestre gestacional e número adequado de consultas para a idade gestacional no parto
## Bloco 6: Média anual do Indice Climático Térmico Universal (°C)

# ------------------------------------------------------------------------------
# 3. Funções auxiliares
# ------------------------------------------------------------------------------

# percent_rank() devolve NaN quando há apenas uma observação não ausente.
percentil_seguro <- function(x) {
  if (sum(!is.na(x)) <= 1L) {
    return(ifelse(is.na(x), NA_real_, 0))
  }
  dplyr::percent_rank(x)
}

# Inverte indicadores protetores depois da transformação em percentil.
inverter_percentil <- function(x) 1 - x

# ------------------------------------------------------------------------------
# 4. Leitura, junção e seleção dos indicadores
# ------------------------------------------------------------------------------

banco_principal <- readr::read_csv(arquivo_base, show_col_types = FALSE)

banco_hemo <- readr::read_csv(arquivo_hemoterapia, show_col_types = FALSE) %>%
  select(codmunres, ano, indicador5)

variaveis_indice <- banco_principal %>%
  left_join(banco_hemo, by = c("codmunres", "ano")) %>%
  transmute(
    ano,
    codmunres = as.character(codmunres),
    B1_1 = idhm,
    B1_2 = ESC_11,
    B1_3 = DEP_SUS,
    B1_4 = NASC_RACA,
    B1_5 = tx_homicidio_100mil,
    B2 = FEC_20,
    B3 = PRE_NATAL,
    B4_1 = DIST_RES,
    B4_2 = NASC_CES,
    B4_3 = cob_hosp_parto,
    B5_1 = prop_menor_1500,
    B5_2 = desp_total_hab_corrigido,
    B5_3 = tx_leitos_hospitalares_totais,
    B5_4 = tx_leitos_uti_total,
    B5_5_5 = indicador5,
    B6 = mean_UTCI_C
  )

# ------------------------------------------------------------------------------
# 5. Transformação dos indicadores em percentis anuais de vulnerabilidade
# ------------------------------------------------------------------------------
# Indicadores protetores são invertidos para que valores maiores sempre indiquem
# maior vulnerabilidade. Segue-se o procedimento do script original, no qual
# valores ausentes, após a transformação, são substituídos por zero.

indicadores_protetores <- c(
  "B1_1", "B1_2", "B3", "B4_2", "B4_3",
  "B5_1", "B5_2", "B5_3", "B5_4", "B5_5_5"
)

var_indice <- variaveis_indice %>%
  group_by(ano) %>%
  mutate(across(-codmunres, percentil_seguro)) %>%
  # adicionando correção para cobertura hospitalar
  mutate(B4_3 = B4_3 + (1 - max(B4_3))) %>%
  mutate(across(all_of(indicadores_protetores), inverter_percentil)) %>%
  mutate(across(-codmunres, ~ tidyr::replace_na(.x, 0))) %>%
  ungroup()

# ------------------------------------------------------------------------------
# 6. Escores dos blocos
# ------------------------------------------------------------------------------
# Os blocos com vários indicadores são somas ponderadas e, em seguida,
# transformados novamente em percentis dentro de cada ano.

var_indice <- var_indice %>%
  group_by(ano) %>%
  mutate(
    bloco1 = percentil_seguro(
      B1_1 * pesos_bloco1["B1_1"] +
      B1_2 * pesos_bloco1["B1_2"] +
      B1_3 * pesos_bloco1["B1_3"] +
      B1_4 * pesos_bloco1["B1_4"] +
      B1_5 * pesos_bloco1["B1_5"]
    ),
    bloco2 = B2,
    bloco3 = B3,
    bloco4 = percentil_seguro(
      B4_1 * pesos_bloco4["B4_1"] +
      B4_2 * pesos_bloco4["B4_2"] +
      B4_3 * pesos_bloco4["B4_3"]
    ),
    bloco5 = percentil_seguro(
      B5_1   * pesos_bloco5["B5_1"] +
      B5_2   * pesos_bloco5["B5_2"] +
      B5_3   * pesos_bloco5["B5_3"] +
      B5_4   * pesos_bloco5["B5_4"] +
      B5_5_5 * pesos_bloco5["B5_5_5"]
    ),
    bloco6 = B6
  ) %>%
  ungroup()

# ------------------------------------------------------------------------------
# 7. Índice final
# ------------------------------------------------------------------------------

var_indice <- var_indice %>%
  group_by(ano) %>%
  mutate(
    escore_final =
      bloco1 * pesos_blocos["bloco1"] +
      bloco2 * pesos_blocos["bloco2"] +
      bloco3 * pesos_blocos["bloco3"] +
      bloco4 * pesos_blocos["bloco4"] +
      bloco5 * pesos_blocos["bloco5"] +
      bloco6 * pesos_blocos["bloco6"],
    indice_mf_v1 = percentil_seguro(escore_final),
    indice_mf_v1_0_100 = 100 * indice_mf_v1,
    quartil = ntile(indice_mf_v1, 4),
    nivel_vulnerabilidade = factor(
      dplyr::recode(
        quartil,
        `1` = "Baixa",
        `2` = "Média-baixa",
        `3` = "Média-alta",
        `4` = "Alta"
      ),
      levels = c("Baixa", "Média-baixa", "Média-alta", "Alta"),
      ordered = TRUE
    )
  ) %>%
  ungroup() %>%
  arrange(ano, codmunres)

readr::write_csv(var_indice, arquivo_saida)

# ==============================================================================
# 8. REESTIMAÇÃO DOS PESOS POR ANÁLISE FATORIAL (CÓDIGO COMENTADO)
# ==============================================================================
# Descomente esta seção apenas se for necessário atualizar os pesos. Ela requer
# o pacote `psych`. A análise é feita separadamente por ano; as cargas fatoriais
# são alinhadas para terem sinal positivo e depois promediadas entre os anos.
# Recomenda-se inspecionar as soluções anuais antes de substituir os vetores
# fixos acima.
#
# library(psych)
#
# estimar_pesos_af <- function(dados, variaveis) {
#   anos_disponiveis <- sort(unique(dados$ano))
#
#   cargas_anuais <- lapply(anos_disponiveis, function(ano_atual) {
#     matriz <- dados %>%
#       filter(ano == ano_atual) %>%
#       select(all_of(variaveis))
#
#     ajuste <- psych::fa(
#       matriz,
#       nfactors = 1,
#       fm = "ml",
#       rotate = "none",
#       scores = "none"
#     )
#
#     cargas <- as.numeric(ajuste$loadings[, 1])
#     names(cargas) <- rownames(ajuste$loadings)
#
#     # O sinal de um fator é arbitrário. Esta regra mantém a orientação
#     # positiva, compatível com indicadores já codificados como vulnerabilidade.
#     if (mean(cargas, na.rm = TRUE) < 0) cargas <- -cargas
#
#     tibble::tibble(
#       ano = ano_atual,
#       indicador = names(cargas),
#       carga = cargas
#     )
#   }) %>%
#     bind_rows()
#
#   cargas_anuais %>%
#     group_by(indicador) %>%
#     summarise(peso_medio = mean(carga, na.rm = TRUE), .groups = "drop") %>%
#     mutate(peso_relativo = peso_medio / min(peso_medio[peso_medio > 0]))
# }
#
# novos_pesos_bloco1 <- estimar_pesos_af(
#   var_indice, c("B1_1", "B1_2", "B1_3", "B1_4", "B1_5")
# )
#
# novos_pesos_bloco4 <- estimar_pesos_af(
#   var_indice, c("B4_1", "B4_2", "B4_3")
# )
#
# novos_pesos_bloco5 <- estimar_pesos_af(
#   var_indice, c("B5_1", "B5_2", "B5_3", "B5_4", "B5_5_5")
# )
#
# novos_pesos_blocos <- estimar_pesos_af(
#   var_indice, c("bloco1", "bloco2", "bloco3", "bloco4", "bloco5", "bloco6")
# )

