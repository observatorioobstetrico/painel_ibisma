# =============================================================================
#   CONSTANTES DO PAINEL IBISMA
#   Reúne o dicionário do índice (blocos, medidas e categorias), os níveis de
#   análise geográfica e as rampas de cores do painel.
#   Manter tudo aqui evita valores espalhados pelo código e facilita a evolução.
# =============================================================================

# -----------------------------------------------------------------------------
#   CORES INSTITUCIONAIS E DE IDENTIFICAÇÃO
# -----------------------------------------------------------------------------

# Definindo a cor institucional azul escura
## Usada em: app_ui.R (tema), fct_cores.R (texto de contraste) e desenhos do mapa, do ranking e dos gráficos (contornos e eixos).
COR_AZUL_ESCURO <- "#0A1E3C"

# Definindo a cor institucional azul clara
## Usada em: PALETAS (bloco3) e app_ui.R (tema).
COR_AZUL_CLARO <- "#32A0FF"

# Definindo a cor de identificação do índice
## Usada em: PALETAS (rampa do índice), app_ui.R (tema) e testes das rampas.
COR_IBISMA <- "#4B1D73"

# Definindo a cor usada para municípios e anos sem dado disponível
## Usada em: fct_cores.R (categoria ausente) e fct_mapa.R (legenda).
COR_SEM_DADOS <- "#D8DCE3"

# Definindo o tom escurecido do amarelo do bloco Social para traços finos
## Usada em: fct_graficos_evolucao.R (linha do Social, que some no branco em amarelo).
COR_LINHA_SOCIAL <- "#D99E00"

# -----------------------------------------------------------------------------
#   CATEGORIAS E RAMPAS DE COR
# -----------------------------------------------------------------------------

# Definindo os rótulos ordenados das cinco categorias de vulnerabilidade
## Usada em: tabelas anuais (níveis do fator), fct_cores.R (nomes dos tons de PALETAS), mod_onde.R (seletor de medida) e legenda do mapa.
CATEGORIAS <- c("Muito baixo", "Baixo", "Médio", "Alto", "Muito alto")

# Definindo as rampas de cinco tons de cada medida, na ordem das categorias
# A cor de identificação fica no tom central dos blocos e no tom mais alto do índice
## Usada em: fct_cores.R (cores de categoria e misturas), mod_onde.R (legenda) e testes das rampas.
PALETAS <- list(
  indice_final = stats::setNames(
    c("#D5C2E8", "#B592D6", "#915EC4", "#6B35A3", COR_IBISMA),
    CATEGORIAS
  ),
  bloco1 = stats::setNames(
    c("#FDEAA4", "#FCD857", "#FAC80F", "#AD921D", "#655F2B"),
    CATEGORIAS
  ),
  bloco2 = stats::setNames(
    c("#B7E6B5", "#7AD276", "#41BE3C", "#2F8B3C", "#1F5B3C"),
    CATEGORIAS
  ),
  bloco3 = stats::setNames(
    c("#B1DBFF", "#70BCFF", COR_AZUL_CLARO, "#2576C1", "#194F86"),
    CATEGORIAS
  ),
  bloco4 = stats::setNames(
    c("#F5BFB0", "#EC896D", "#E4572E", "#9E4532", "#5D3437"),
    CATEGORIAS
  ),
  bloco5 = stats::setNames(
    c("#AAC0DB", "#628CBC", "#1E5AA0", "#184780", "#123562"),
    CATEGORIAS
  ),
  bloco6 = stats::setNames(
    c("#9EDDDD", "#4CC1C1", "#00A6A6", "#037A84", "#065264"),
    CATEGORIAS
  )
)

# -----------------------------------------------------------------------------
#   DICIONÁRIO DAS MEDIDAS
# -----------------------------------------------------------------------------

# Definindo as sete medidas na ordem canônica do painel
# A ordem manda nas colunas das séries, nos sete gráficos e nos seletores
# A coluna cor é a cor de identificação: tom central dos blocos e topo do índice
## Usada em: fct_dados.R (colunas das séries), fct_graficos_evolucao.R (sete cartões e eixos), fct_cores.R (cor_medida) e mod_como.R (laço dos gráficos).
MEDIDAS <- data.frame(
  medida  = c(
    "indice_final",
    "bloco1",
    "bloco2",
    "bloco3",
    "bloco4",
    "bloco5",
    "bloco6"
  ),
  nome    = c(
    "IBISMA",
    "Social",
    "Planejamento reprodutivo",
    "Pré-natal",
    "Parto",
    "Sistema de saúde",
    "Clima"
  ),
  rotulo  = c(
    "IBISMA",
    "Bloco Social",
    "Bloco Planejamento reprodutivo",
    "Bloco Pré-natal",
    "Bloco Parto",
    "Bloco Sistema de saúde",
    "Bloco Clima"
  ),
  cor     = c(
    COR_IBISMA,
    "#FAC80F",
    "#41BE3C",
    COR_AZUL_CLARO,
    "#E4572E",
    "#1E5AA0",
    "#00A6A6"
  ),
  stringsAsFactors = FALSE
)

# Definindo os seis blocos como o recorte das medidas sem o índice
## Usada em: mod_como.R (pétalas e eixos), fct_graficos_evolucao.R (grade da evolução) e fct_esqueleto.R (esqueleto da grade).
BLOCOS <- MEDIDAS[MEDIDAS$medida != "indice_final", ]
row.names(BLOCOS) <- NULL

# -----------------------------------------------------------------------------
#   DICIONÁRIO DOS INDICADORES
# -----------------------------------------------------------------------------

# Definindo os dezesseis indicadores brutos que compõem os seis blocos
# A coluna indicador é o nome da coluna nas séries históricas do painel;
# a coluna codigo é o código usado no cálculo do índice (criar_indice_final.R);
# a coluna nome é o nome oficial do indicador, exibido no título do cartão;
# a coluna decimais é o número de casas dos valores no tooltip (3 no IDHM);
# a coluna fator amplia os indicadores guardados como proporção (×100 = %);
# a coluna protetor indica os indicadores em que o aumento reduz a insegurança.
## Usada em: data-raw/cria_rda.R (montagem das séries), fct_dados.R (consultas do dicionário)
## e fct_graficos_evolucao.R (título, unidade e escala dos gráficos).
INDICADORES <- data.frame(
  indicador = c(
    "idhm",
    "ESC_11",
    "DEP_SUS",
    "NASC_RACA",
    "tx_homicidio_100mil",
    "FEC_20",
    "PRE_NATAL",
    "DIST_RES",
    "NASC_CES",
    "cob_hosp_parto",
    "prop_menor_1500",
    "desp_total_hab_corrigido",
    "tx_leitos_hospitalares_totais",
    "tx_leitos_uti_total",
    "leitos_obst_med_transfusional",
    "mean_UTCI_C"
  ),
  codigo = c(
    "B1_1",
    "B1_2",
    "B1_3",
    "B1_4",
    "B1_5",
    "B2",
    "B3",
    "B4_1",
    "B4_2",
    "B4_3",
    "B5_1",
    "B5_2",
    "B5_3",
    "B5_4",
    "B5_5_5",
    "B6"
  ),
  bloco = c(
    "bloco1", "bloco1", "bloco1", "bloco1", "bloco1",
    "bloco2",
    "bloco3",
    "bloco4", "bloco4", "bloco4",
    "bloco5", "bloco5", "bloco5", "bloco5", "bloco5",
    "bloco6"
  ),
  nome = c(
    "IDHM",
    "Porcentagem de nascidos vivos de mães com mais de 11 anos de estudo",
    "Porcentagem de mulheres com 10 a 49 anos usuárias exclusivas do SUS",
    "Porcentagem de nascidos vivos de mães de raça/cor negras (pretas + pardas) + indígenas",
    "Taxa de homicídio por 100.000 habitantes",
    "Taxa específica de fecundidade de mulheres com menos de 20 anos de idade (por mil)",
    "Porcentagem de mulheres com início do pré-natal no primeiro trimestre gestacional e número adequado de consultas para a idade gestacional no parto",
    "Medianas de deslocamento para partos ocorridos fora do município de residência da mulher",
    "Porcentagem de nascidos vivos por cesariana",
    "Porcentagem de partos ocorridos em hospitais",
    "Porcentagem de nascidos com peso <1500g em serviços com UTI neonatal",
    "Despesa total municipal com saúde, per capita, corrigido pelo IPCA de dez. 2024",
    "Taxa de leitos hospitalares por 10.000 habitantes na macrorregião de saúde",
    "Taxa de leito de UTI por 10.000 habitantes na macrorregião de saúde",
    "Porcentagem de leitos obstétricos em hospitais com serviço de medicina transfusional",
    "Média anual do Índice Climático Térmico Universal (°C)"
  ),
  unidade = c(
    "índice",
    "%", "%", "%", "por 100 mil hab.",
    "por mil mulheres de 10 a 19 anos",
    "%",
    "km",
    "%", "%", "%",
    "R$/hab.",
    "por 10 mil hab.", "por 10 mil hab.",
    "%",
    "°C"
  ),
  decimais = c(3, rep(1, 15)),
  fator = c(
    1,
    1, 1, 1, 1,
    1,
    1,
    1, 1, 100,
    100,
    1,
    1, 1,
    100,
    1
  ),
  protetor = c(
    TRUE,
    TRUE, FALSE, FALSE, FALSE,
    FALSE,
    TRUE,
    FALSE, TRUE, TRUE,
    TRUE,
    TRUE,
    TRUE, TRUE,
    TRUE,
    FALSE
  ),
  stringsAsFactors = FALSE
)

# -----------------------------------------------------------------------------
#   NÍVEIS DE ANÁLISE GEOGRÁFICA
# -----------------------------------------------------------------------------

# Definindo o nível de análise geográfica usado pela seção Onde?
# Habilitando novos níveis ao acrescentar linhas com a variável geográfica do nível
## Usada em: mod_onde.R (seletor de nível).
NIVEIS_ANALISE <- data.frame(
  id            = "municipio",
  rotulo        = "municípios",
  singular      = "município",
  variavel_geo  = "codmunres",
  disponivel    = TRUE,
  stringsAsFactors = FALSE
)
