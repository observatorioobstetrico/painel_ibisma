# análise novo indicador - centros de hemoterapia

library(tidyr)
library(slider)
library(dplyr)
library(janitor)
library(corrplot)
library(psych)
library(mgcv)
library(mirt)
library(ggplot2)
library(patchwork)
library(gratia)
library(lubridate)
library(sf)
library(forcats)

# analisando banco de dados atualizado enviado ao Elzo
banco_dados_hemo_leitos <-  
  readr::read_csv(
    'banco_final_municipio_macro_leitos_hemo_medtransf.csv') 
  

banco_dados_hemo_geral <-  
  readr::read_csv(
    'banco_final_hemoterapia_medicinatransfus_mun_macro.csv') %>% 
  rename(servicos_hemoterapia = servico_hemoterapia, 
         m_servicos_hemoterapia = macro_servico_hemoterapia, 
         m_medicina_transfusional = macro_medicina_transfusional)
  

dados_pop <- readr::read_csv(
  'Banco_txleitos_txhomicidio_2010_2024.csv') %>% 
  select(codmun, ano, pop)


banco_dados_hemo <- banco_dados_hemo_geral %>% 
  left_join(banco_dados_hemo_leitos %>% 
              select(-c(nome_mun, co_uf:regiao_de_saude, codmun, 
                        regiao_pais)), 
            by = join_by(
              codufmun, ano
            ) , 
            suffix = c('_geral', '_leitos'))

# banco_dados_hemo %>% 
#   select(
#     codmungeral, 
#     ano,
#     starts_with('servico')) %>% 
#   head(20)


# banco_dados_hemo %>% 
#   filter(servico_hemoterapia < servicos_hemoterapia)

banco_dados_final <-  
  readr::read_csv('banco_dados_atualizado_2024_abril.csv') %>% 
  select(ano, codmunres, n_nasc)

banco_dados_hemo <- banco_dados_hemo %>% 
  left_join(
    banco_dados_final, 
    by = join_by(
      codufmun == codmunres, 
      ano == ano 
    )
  ) %>% 
  left_join(
    dados_pop, 
    by = join_by(
      codufmun == codmun, 
      ano == ano 
    )
  ) %>% 
  filter(ano > 2014) %>% 
  filter(ano < 2025)

# checando variáveis disponíveis

banco_dados_hemo %>% names()
  
# checando resposta
banco_dados_hemo %>% 
  select(codufmun, ano, starts_with('servico'), n_nasc, pop)

banco_dados_hemo <- banco_dados_hemo %>% 
  mutate(
    ind_serv_hemo_geral = m_servicos_hemoterapia_geral / pop,
    ind_serv_hemo_obs = m_servicos_hemoterapia_leitos / n_nasc,
    ind_med_transf_geral = m_medicina_transfusional_geral / pop,
    ind_med_transf_obs = m_medicina_transfusional_leitos / pop, 
    indicador5 = m_leitos_obst_medtransfus/m_total_leitos_obst
  )

banco_dados_hemo %>% summary()

banco_dados_hemo %>%
  select(codmun, ano,
         ind_serv_hemo_geral, 
         ind_serv_hemo_obs, 
         ind_med_transf_geral,
         ind_med_transf_obs, 
         indicador5) %>% 
  rename(codmunres = codmun) %>% 
  readr::write_csv(
    'dados_servicos_hemo.csv'
  )

banco_dados_hemo %>% 
  summary()
