library(mgcv)
library(dplyr)
library(janitor)
library(ggplot2)
library(patchwork)
library(stringr)
library(readr)
library(lubridate)
library(sf)
library(gganimate)
library(haven)

setwd("data-raw/databases")

# criando banco de dados atualizado até 2024
dados_atualizados <- readr::read_csv(
  'Banco_txleitos_txhomicidio_2010_2024.csv')

dados_despesas <- readr::read_csv(
  'Banco_despesa_total_hab_corrrigida_2010_2024.csv') %>%
  select(codmun, ano, desp_total_hab_corrigido)


dados_atualizados <- dados_atualizados %>%
  left_join(dados_despesas)


# adicionando população
dados_pop <- readr::read_csv('Base_adicional_Bruno.csv') %>%
  # filter (ano == 2020) %>%
  select(codmunres, ano, populacao_total)

dados_atualizados <- dados_atualizados %>%
  left_join(dados_pop,
            by = join_by(
              ano, codmun == codmunres))


# lendo bases de dados do Observatório
# bases_nomes <- list.files('bases_bruno/')[-c(5, 6, 14)]
bases_nomes <- list.files('bases_bruno_2024/')
bases_observatorio <- lapply(bases_nomes, function(a){
  print(a)
  data_temp <- readr::read_csv(paste0(
    'bases_bruno_2024/', a
  ))
  if (a != bases_nomes[1] &
      any(names(data_temp) == 'total_de_nascidos_vivos')){
    data_temp <- data_temp %>% select(-total_de_nascidos_vivos)
  }
  data_temp
})
lapply(bases_observatorio, dim)

# lendo bases de dados de deslocamento macro UTI
# bases_observatorio[[length(bases_observatorio) + 1]] <-
#   readxl::read_excel(
#     'bases_bruno/indicadores_bloco4_deslocamento_macro_uti_2012_2024.xlsx')
# lapply(bases_observatorio, dim)

# juntando todas bases em somente uma
todas_bases_observatorio <- purrr::reduce(
  bases_observatorio,
  left_join, by = c('codmunres', 'ano'))

todas_bases_observatorio %>% names()


# selecionando as variáveis que utilizamos e criando
# novas variáveis

variaveis_observatorio <- todas_bases_observatorio %>%
  mutate(
    porc_nvm_esc_acima_de_11 =
      nvm_com_escolaridade_acima_de_11 /
      total_de_nascidos_vivos * 100,
    porc_dependentes_sus = 100 * (populacao_feminina_10_a_49.x - pop_fem_10_49_com_plano_saude) /
      populacao_feminina_10_a_49.x,
    porc_menor20 =  1000 *
      nvm_menor_que_20 /
      (populacao_feminina_10_a_14 +
         populacao_feminina_15_a_19),
    prop_tx_cesariana_geral = mulheres_com_parto_cesariana /
      total_de_nascidos_vivos * 100,
    tai_total = (abortos_ans_30_a_39 + abortos_ans_menor_30 +
                   abortos_ans_40_a_49 + abortos_sus_30_a_39 +
                   abortos_sus_menor_30 + abortos_sus_40_a_49) /
      populacao_feminina_10_a_49.x * 1000,
    porc_nvm_cor_pele_negindig = (nvm_com_cor_da_pele_preta +
                                    nvm_com_cor_da_pele_parda +
                                    nvm_indigenas)/
      total_de_nascidos_vivos * 100
  ) %>%
  rename(ESC_11 = porc_nvm_esc_acima_de_11,
         DEP_SUS = porc_dependentes_sus,
         FEC_20 = porc_menor20,
         DIST_RES = km_partos_fora_municipio,
         NASC_CES = prop_tx_cesariana_geral,
         TAI = tai_total,
         NASC_RACA = porc_nvm_cor_pele_negindig) %>%
  select(codmunres,
         ano,
         ESC_11,
         DEP_SUS,
         FEC_20,
         DIST_RES,
         NASC_CES,
         TAI,
         NASC_RACA)

# checando quantidades
todas_bases_observatorio %>%
  group_by(ano) %>%
  summarise(nasc = sum(total_de_nascidos_vivos),
            mmat = sum(obitos_mat_totais),
            mfet = sum(obitos_fetais_todos_todos),
            mneo = sum(obitos_neonatais_todos_todos),
            mperi = sum(obitos_perinatais_todos_todos))


dados_clima_conforto <-
  read.csv('Indice_de_Conforto_Termico_UTCI_2000-2024.csv',
           encoding = "latin1",
           sep = ';') %>%
  mutate(codmunres = substr(CD_MUN, 1, 6)) %>%
  mutate(Date = as.Date(Date, format = "%d/%m/%Y")) %>%
  mutate(ano = year(Date))


# Guardando o endereço do DATASUS, os UFs e as variáveis usadas nos cálculos
url_dbc_sinasc <- 'ftp://ftp.datasus.gov.br/dissemin/publicos/SINASC/1996_/Dados/DNRES'
ufs_sinasc <- c('AC', 'AL', 'AP', 'AM', 'BA', 'CE', 'DF', 'ES', 'GO', 'MA',
                'MT', 'MS', 'MG', 'PA', 'PB', 'PR', 'PE', 'PI', 'RJ', 'RN',
                'RS', 'RO', 'RR', 'SC', 'SP', 'SE', 'TO')
variaveis_sinasc <- c('CODMUNRES', 'LOCNASC', 'MESPRENAT', 'SEMAGESTAC', 'CONSPRENAT')

# Definindo uma função que baixa os arquivos .dbc de um ano, em paralelo por UF
# Os .dbc ficam no cache dados/dbc e os trechos interrompidos retomam de onde pararam
# Usada em: baixa_sinasc_ano, logo abaixo
baixa_dbcs_ano <- function(ano, tentativas = 3) {
  destinos <- sprintf('dados/dbc/DN%s%d.dbc', ufs_sinasc, ano)
  parciais <- paste0(destinos, '.baixando')
  baixados <- file.exists(destinos)

  # Tentando algumas vezes, retomando os trechos interrompidos
  for (tentativa in seq_len(tentativas)) {
    pendentes <- which(!baixados)
    if (length(pendentes) == 0) break

    # Baixando todos os UFs pendentes de uma vez, em paralelo
    cat('SINASC', ano, ': baixando', length(pendentes), 'arquivo(s) por UF\n')
    resultado <- curl::multi_download(
      sprintf('%s/DN%s%d.dbc', url_dbc_sinasc, ufs_sinasc[pendentes], ano),
      parciais[pendentes],
      resume = TRUE, progress = FALSE
    )

    # Guardando no cache só os arquivos que baixaram por inteiro
    concluidos <- pendentes[which(resultado$success)]
    file.rename(parciais[concluidos], destinos[concluidos])
    baixados[concluidos] <- TRUE
  }

  # Parando com os UFs que continuaram falhando depois das tentativas
  if (any(!baixados)) {
    stop('Não foi possível baixar o SINASC ', ano, ' de: ',
         paste(ufs_sinasc[!baixados], collapse = ', '))
  }

  destinos
}

# Definindo uma função que baixa e recorta o SINASC de um ano
# Guardando só as variáveis usadas: município, local do parto e pré-natal
# Usada em: este arquivo (cobertura hospitalar e base do bloco 3)
baixa_sinasc_ano <- function(ano) {
  arquivo <- sprintf('dados/sinasc_%d_%d.csv', ano, ano)

  # Reaproveitando o CSV já montado, para não baixar de novo
  if (file.exists(arquivo)) {
    cat('SINASC', ano, ': usando', arquivo, '\n')
    return(arquivo)
  }

  # Baixando os arquivos por UF (em paralelo) e lendo na mesma ordem
  destinos <- baixa_dbcs_ano(ano)
  dados_sinasc <- lapply(destinos, function(dbc) {
    read.dbc::read.dbc(dbc, as.is = TRUE)[, variaveis_sinasc]
  }) %>%
    bind_rows()

  # Salvando o recorte que as etapas seguintes usam
  readr::write_csv(dados_sinasc, arquivo)
  arquivo
}

# Criando as pastas que guardam os microdados baixados
dir.create('dados/dbc', showWarnings = FALSE, recursive = TRUE)

# Baixando (ou reaproveitando) os microdados de cada ano do estudo
invisible(lapply(2015:2024, baixa_sinasc_ano))

calcula_cobertura <- function(a){
  dados_sinasc <-
    read_csv(paste0('dados/sinasc_', a, '_', a, '.csv')) %>%
    mutate(cob_hospital = ifelse(LOCNASC == 1, 1, 0))

  dados_agrupados <- dados_sinasc %>%
    group_by(CODMUNRES) %>%
    summarise(cob_hosp_parto = mean(cob_hospital,
                                    na.rm = TRUE),
              n_nasc = n())

  readr::write_csv(dados_agrupados,
                   paste0('dados_cob_nasc_', a,'.csv'))
}

lapply(2024:2015, calcula_cobertura)

# Definindo uma função que monta a base do pré-natal adequado (bloco 3)
# Numerador: mulheres com pré-natal iniciado no primeiro trimestre E número de
# consultas adequado à idade gestacional no parto
# Usada em: este arquivo (junção na base do banco de dados)
cria_dados_bloco3 <- function(a) {
  dados_sinasc <- readr::read_csv(
    sprintf('dados/sinasc_%d_%d.csv', a, a),
    show_col_types = FALSE
  ) %>%
    janitor::clean_names() %>%
    # Convertendo as variáveis de pré-natal para número (o CSV pode vir como texto)
    mutate(
      mesprenat = as.numeric(mesprenat),
      semagestac = as.numeric(semagestac),
      consprenat = as.numeric(consprenat)
    )

  dados_sinasc <- dados_sinasc %>%
    mutate(
      # Sinalizando o início do pré-natal no primeiro trimestre (até a 12ª semana)
      nvm_inicio_prenat_12_menos_semanas = if_else(
        mesprenat >= 1 & mesprenat <= 3,
        1, 0, missing = 0
      ),
      # Sinalizando o número de consultas adequado à idade gestacional no parto
      nvm_num_consultas_prenat_adequado = if_else(
        ((semagestac < 20 & consprenat >= 1) |
           (semagestac >= 20 & semagestac < 26 & consprenat >= 2) |
           (semagestac >= 26 & semagestac < 30 & consprenat >= 3) |
           (semagestac >= 30 & semagestac < 34 & consprenat >= 4) |
           (semagestac >= 34 & semagestac < 36 & consprenat >= 5) |
           (semagestac >= 36 & semagestac < 38 & consprenat >= 6) |
           (semagestac >= 38 & semagestac < 40 & consprenat >= 7) |
           (semagestac >= 40 & semagestac < 99 & consprenat >= 8 & consprenat < 99)),
        1, 0, missing = 0
      ),
      # Exigindo as duas condições juntas para o pré-natal ser adequado
      nvm_prenatal_adequado =
        nvm_inicio_prenat_12_menos_semanas * nvm_num_consultas_prenat_adequado
    )

  dados_sinasc %>%
    # Calculando a porcentagem de mulheres com pré-natal adequado no município
    group_by(codmunres) %>%
    summarise(
      adequacao_inicio = 100 * mean(nvm_prenatal_adequado),
      .groups = 'drop'
    ) %>%
    mutate(ano = a) %>%
    select(codmunres, ano, adequacao_inicio)
}

# Montando a base do bloco 3 para todos os anos
dados_bloco3 <- lapply(2015:2024, cria_dados_bloco3) %>%
  bind_rows()

# Salvando a base do bloco 3 para a etapa de junção
readr::write_csv(dados_bloco3, 'dados/dados_bloco3.csv')

# Conferindo a base do bloco 3
cat('dados_bloco3:', nrow(dados_bloco3), 'linhas |',
    n_distinct(dados_bloco3$codmunres), 'municípios\n')

cria_banco <- function(a){
  dados_sinasc <-
    read_csv(paste0('dados_cob_nasc_', a, '.csv'))

  dados_clima_conforto_ano <- filter(
    dados_clima_conforto, ano == a) %>%
    select(-c(Date)) %>%
    select(
      codmunres,
      mean_UTCI_C,
      count.days_extreme_heat_yearly_extreme,
      count.days_strong_heat_yearly_strong,
      count.days_very_strong_heat_yearly_very_strong,
      count.days_moderate_heat_yearly_moderate) %>%
    rename(
      cd_extreme = count.days_extreme_heat_yearly_extreme,
      cd_strong = count.days_strong_heat_yearly_strong,
      cd_verystrong = count.days_very_strong_heat_yearly_very_strong,
      cd_moderate = count.days_moderate_heat_yearly_moderate
    ) %>%
    mutate(
      cd_nostress = 365 - (cd_extreme +
                             cd_strong +
                             cd_verystrong +
                             cd_moderate)
    )

  dados_indicadores_ano <- variaveis_observatorio %>%
    mutate(codmunres = as.character(codmunres)) %>%
    filter(ano == a) %>%
    select(-ano)

  dados_prenatal <- readr::read_csv('dados/dados_bloco3.csv') %>%
    mutate(codmunres = as.character(codmunres)) %>%
    filter(ano == a) %>%
    select(-ano) %>%
    rename(PRE_NATAL = adequacao_inicio)

  dados_pop_ano  <-
    read_csv('Base_Adicional_Bruno.csv') %>%
    filter(ano == 2012) %>%
    select(codmunres,
           idhm) %>%
    mutate(codmunres = as.character(codmunres))

  mortes_sim_mun <- todas_bases_observatorio %>%
    filter(ano == a) %>%
    select(-ano) %>%
    select(codmunres,
           obitos_mat_totais,
           obitos_mat_hemorragia,
           obitos_fetais_todos_todos,
           obitos_neonatais_todos_todos,
           obitos_perinatais_todos_todos,
           partos_na_macro_com_4mais_uti,
           total_de_nascidos_vivos) %>%
    mutate(codmunres = as.character(codmunres)) %>%
    mutate(prop_menor_1500 = partos_na_macro_com_4mais_uti /
             total_de_nascidos_vivos) %>%
    rename(n_mortes = obitos_mat_totais,
           n_mortes_hem = obitos_mat_hemorragia,
           n_mortes_fet = obitos_fetais_todos_todos,
           n_mortes_neonatais = obitos_neonatais_todos_todos,
           n_mortes_perinatais = obitos_perinatais_todos_todos)

  # dados_novos_ano <- haven::read_dta(
  #   'banco_municipios_corrigido_22112025_ reduzido para Bruno.dta') %>%
  dados_novos_ano <- dados_atualizados %>%
    filter(ano == a) %>%
    mutate(codmunres = as.character(codmun)) %>%
    select(-c(ano, codmun, nome_mun,
              regiao_pais, co_uf,
              sg_uf,
              uf, cod_macrorregiao_de_saude,
              cod_regiao_de_saude,
              regiao_de_saude))

  dados_agrupados <- dados_sinasc %>%
    mutate(ano = a) %>%
    mutate(CODMUNRES = as.character(CODMUNRES)) %>%
    rename(codmunres = CODMUNRES) %>%
    mutate(log_nasc = log(n_nasc)) %>%
    left_join(dados_indicadores_ano) %>%
    left_join(dados_prenatal) %>%
    left_join(dados_pop_ano) %>%
    left_join(dados_clima_conforto_ano) %>%
    left_join(dados_novos_ano) %>%
    left_join(mortes_sim_mun)

  dados_agrupados
}

banco_total <- lapply(2015:2024, cria_banco) %>%
  bind_rows()

banco_dados_final <- banco_total %>%
  left_join(
    read_csv('Base_adicional_Bruno.csv') %>%
      mutate(codmunres = as.character(codmunres)) %>%
      filter (ano == 2020) %>%
      select(codmunres,
             uf, nome_uf, regiao_pais, nome)
  ) %>%
  filter(!substr(codmunres, 3, 6) == '0000') %>%
  select(ano, codmunres, nome, uf, nome_uf, regiao_pais,
         idhm,
         ESC_11:NASC_RACA,
         PRE_NATAL,
         tx_homicidio_100mil,
         cob_hosp_parto,
         mean_UTCI_C:cd_nostress,
         tx_leitos_hospitalares_totais,
         tx_leitos_uti_total,
         desp_total_hab_corrigido,
         prop_menor_1500,
         n_nasc,
         n_mortes,
         n_mortes_fet,
         n_mortes_neonatais,
         n_mortes_perinatais) %>%
  arrange(ano, codmunres)


banco_dados_final %>%
  readr::write_csv('banco_dados_atualizado_2024_abril.csv')

