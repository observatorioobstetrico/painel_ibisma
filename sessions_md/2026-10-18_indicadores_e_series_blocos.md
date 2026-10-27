# Sessão 35 — Indicadores brutos dos blocos e séries históricas (18/10/2026)

- **Pacote:** `painel_vidas`.
- **Objetivo:** levar as séries históricas dos dezesseis indicadores brutos que
  compõem os seis blocos para as bases do painel e para a interface, com
  gráficos de evolução próprios na seção Como?.

O painel nasceu com apenas uma base agregada (valor do índice e dos seis blocos
por município e ano). Com a pipeline de indicadores pronta, esta sessão passou a
carregar também o valor de cada indicador bruto, usado nos gráficos de evolução
por bloco.

## 1. Pipeline de indicadores (`data-raw/scripts_bruno`)

- Versionados os três scripts da pipeline: `cria_banco_dados_2024.R`,
  `criar_indice_final.R` e `analise_novo_indicador_hemoterapia.R`.
- `cria_banco_dados_2024.R` passou a baixar o SINASC direto do FTP do DATASUS
  com `curl::multi_download`: **paralelo por UF, sequencial por ano**.
  Justificativa: cada ano vira um CSV pronto assim que fecha (progresso
  incremental e retomada), a memória fica limitada a um ano e as falhas são
  repetidas só por UF.
- Cache por UF em `data-raw/databases/dados/dbc/`: trechos interrompidos ficam
  como `.baixando` e retomam com `resume = TRUE`; até três tentativas por ano e
  parada com a lista de UFs que falharam.
- A base do bloco 3 passou a ser criada no próprio script
  (`dados/dados_bloco3.csv`): porcentagem de mulheres com pré-natal iniciado no
  primeiro trimestre **e** número de consultas adequado à idade gestacional no
  parto (duas sinalizações por nascido, `missing = 0`, agregadas por município).
- Armadilha corrigida: o `read_csv` pode ler as colunas do pré-natal como texto
  quando as primeiras linhas do arquivo são `NA` (caso do AC em 2015); a
  conversão explícita para número evita comparações lexicográficas que zeravam o
  indicador em silêncio.
- Pipeline executada de ponta a ponta: `banco_dados_atualizado_2024_abril.csv`
  (15,3 MB) e `indice_materno_final_2015_2024.csv` (25,5 MB). Conferência do
  bloco 3: 5.593 municípios e média nacional subindo de 58,7% (2015) para 75,3%
  (2024), valores plausíveis.

## 2. Dicionário dos indicadores (`R/constantes.R`)

- Novo `INDICADORES` com os dezesseis indicadores brutos: `indicador` (coluna
  das séries), `codigo` (B1_1...B5_5_5), `bloco`, `nome` (nome oficial do
  `criar_indice_final.R`), `unidade`, `decimais` (3 no IDHM e 1 nos demais),
  `fator` (×100 nas proporções) e `protetor` (lista de protetores do índice).
- Decisões: valores **brutos** (não percentis) nas séries; títulos com os nomes
  oficiais, sem descrições inventadas; `NASC_CES` segue como protetor, conforme
  a lista do cálculo do índice.

## 3. Geração das bases (`data-raw/cria_rda.R`)

- Lê o índice final, a base intermediária e a hemoterapia, junta por município
  e ano, aplica o `fator`, converte `NaN` em `NA` e grava `series` com as sete
  medidas + os dezesseis indicadores.
- A cobertura de cada indicador é impressa na geração (98,2% a 100%; as faltas
  ficam em IDHM e distância).
- `base_exemplo_vidas.csv` deixou de ser lida pelo script e pelos testes
  (candidata a sair do repositório).

## 4. Consultas e gráficos

- `fct_dados.R`: `series_municipio()` e `series_tem_valor()` aceitam recorte de
  colunas; entram `tem_indicadores()`, `indicadores_do_bloco()` e
  `info_indicador()`.
- `fct_cores.R`: `cor_linha_medida()` concentra a cor do traço e o amarelo
  escurecido do Social, usado pelas medidas e pelos indicadores.
- `fct_graficos_evolucao.R`: novo `grafico_evolucao_indicador()` com:
  - **cinco intervalos fixos (seis ticks)** em todos os gráficos — antes o
    número de ticks variava de 2 a 9 entre cartões;
  - passos redondos `1; 1,5; 2; 2,5; 5; 10 × 10^k`, nunca abaixo da precisão do
    indicador (o eixo do SUS não cai mais em duas casas decimais);
  - janela do eixo centrada nos dados e com piso zero (fim dos valores
    negativos no peso abaixo de 1.500 g);
  - casas decimais por indicador (IDHM com três) e sufixos `%`/`°C` no eixo e
    no tooltip;
  - `containLabel` no `e_grid` para a coluna dos números encostar no título —
    a mesma folga de ~3 px dos gráficos dos blocos, sem estimar largura de
    texto;
  - o preenchimento sob as linhas fica no parâmetro `OPACIDADE_AREA_EVOLUCAO`
    (desligado nesta sessão, valendo para as medidas e para os indicadores).

## 5. Seção "Indicadores do bloco" (`mod_como.R`, `fct_esqueleto.R`, CSS)

- Bloco novo na seção Como?, abaixo da evolução: chips com a cor de cada bloco
  (`radioGroupButtons`, no padrão Bootstrap 5 `input.btn-check` + `label.btn`) e
  grade `auto-fit` de cartões.
- Cada cartão mostra o nome oficial, a linha do município principal e a
  comparação tracejada; indicador sem valor no período cai em estado vazio.
- Alinhamento: o gráfico é empurrado para o rodapé (`margin-top: auto`), então
  todos os cartões da linha começam e terminam no mesmo Y, mesmo com títulos de
  uma ou duas linhas.
- O esqueleto reserva os cinco cartões do bloco padrão (Social).
- Alturas finais dos gráficos (ajustadas nesta sessão): VIDAS **240 px**,
  blocos **170 px** e indicadores **160 px**.

## 6. Testes (`tests/testthat/test-funcoes_globais.R`)

- Os quatro testes de dados que pulavam por falta dos CSVs da pipeline passaram
  a rodar e comparam as séries **valor por valor** com o índice, a base
  intermediária e a hemoterapia (incluindo o fator de exibição).
- Correção de contrato: anos preenchidos pelo `complete()` (ex.: 350720/2023)
  ficam `NA` mesmo que a fonte de hemoterapia tenha valor para o município.
- Testes novos: dicionário (nomes oficiais, códigos e contagem por bloco),
  consultas (`info_indicador`, `indicadores_do_bloco`, `tem_indicadores` e
  recorte de colunas), passos e casas do eixo, limites (série zerada, faixa
  estreita e comparação), gráfico do indicador, esqueleto e módulo.
- Suíte completa verde (zero skips com os dados presentes).

## 7. Bases do aplicativo

- `inst/app/data/dados_vidas.rds` reconstruído com dados reais: 55.700 linhas
  (5.570 municípios × 10 anos) e 23 colunas (7 medidas + 16 indicadores);
  tabelas anuais regeradas; malha inalterada.
- Observações da base: o município padrão é Jutaí (AM); o IDHM é fixo no tempo
  (a base usa o valor de 2012); `ESC_11` (~4% para ~1%) e `NASC_RACA` (17% para
  ~100% em 2017) têm padrões que parecem artefato de registro do SINASC — vale
  confirmar com o Bruno.
- `dados_servicos_hemo.csv` tem duas chaves município-ano duplicadas (inofensivo
  para o app, que deduplica, mas vale corrigir no script de hemoterapia).

## 8. Versionamento e ambiente

- Bases **derivadas** e cache ignorados no git (`data-raw/databases/dados/`,
  `dados_cob_nasc_*.csv`, `banco_dados_atualizado_2024_abril.csv` e
  `indice_materno_final_2015_2024.csv`), por serem regeneráveis.
- As bases **de entrada** da pipeline continuam fora do repositório (~125 MB
  somando `bases_bruno_2024/` e os CSVs da raiz de `databases/`) — decidir na
  próxima sessão se entram no git ou em outro armazenamento.
- Ambiente: o `ellipsis` 0.3.3 exige `rlang >= 1.1.7` e a máquina tinha 1.1.4;
  a suíte aqui rodou com uma cópia temporária do rlang. Para o
  `devtools::test()` local voltar a funcionar, atualizar o rlang com as sessões
  do RStudio fechadas.

## 9. Próximos passos

- Reiniciar o app e conferir a seção nova com a base real.
- Confirmar os padrões de `ESC_11` e `NASC_RACA` com o Bruno.
- Decidir o destino de `base_exemplo_vidas.csv` e das bases de entrada da
  pipeline.
- Se o mapa ou o ranking passarem a aceitar indicador, incluir os indicadores
  nas tabelas anuais (categorias e rankings por ano); hoje as séries bastam
  para a evolução.

## 10. Ajustes de acabamento da mesma sessão

Depois dos primeiros testes com a base real, uma rodada de ajustes finos:

- **Eixos**: todos os gráficos de evolução (VIDAS, blocos e indicadores) usam
  cinco marcações equiespaçadas, com a faixa adaptativa (`limites_eixo`) no
  lugar do piso/teto fixos de 25 em 25; os passos redondos das medidas são
  sempre inteiros e o topo não passa dos 100 do percentil. Os esqueletos
  desenham as mesmas cinco marcações.
- **Identificações das séries**: o componente `evolucao-identificacao` se
  repete sob o título "Blocos do VIDAS" e sob o seletor de blocos dos
  indicadores; na seção dos indicadores a amostra de traço e bolinha usa a cor
  do bloco escolhido (`--cor-serie`), e não o azul escuro padrão.
- **Seletor de blocos**: virou botões soltos de largura variável, com mais
  respiro, ponto na cor do bloco e preenchimento sutil (`color-mix` de 16%);
  o hover pré-visualiza a cor do bloco em 8%; saíram a caixa de fundo e o
  texto "Bloco". A seção passou a se chamar "Os indicadores por trás de cada
  bloco", com a descrição nova.
- **Nome do bloco**: "Planejamento Reprodutivo" virou "Planejamento
  reprodutivo" em todo o painel (o dicionário `MEDIDAS` é a fonte única).
- **Perfil do município**: o bloco do índice ("VIDAS em {ano}", valor, selo e
  frase) subiu para logo depois das métricas territoriais, acima das pétalas; a
  base do palco passou a mostrar **três rankings** — macrorregião de saúde, UF
  e Brasil, nessa ordem. As tabelas anuais ganharam `pos_macro` e `total_macro`
  (ranking dentro de cada UF + macrorregião) e as bases foram regeradas; o
  esqueleto do palco foi dividido em índice e rankings.
- **Percentil sem trava**: a frase do percentil mostra o valor real (o
  município mais vulnerável chega a "acima de 100,0%") e o nome do município no
  perfil usa o tamanho de destaque das caixas.

## Commits da sessão

- `1e82e19` Versiona a pipeline de indicadores e baixa o SINASC em paralelo
- `bcef1dc` Adiciona o dicionario dos indicadores e as series historicas
- `b4600b2` Desenha a evolucao dos indicadores com eixo proprio
- `a3525d0` Adiciona a seção de indicadores do bloco na seção Como?
- `46b8737` Cobre as bases e os gráficos dos indicadores nos testes
- `79b2eae` Reconstrói as bases do aplicativo com os indicadores
- `6a8111e` Ignora as bases derivadas e o cache da pipeline de indicadores
- `ede5a40` Registra o bundle do deploy mais recente do shinyapps
- `3ffef48` Documenta a sessão dos indicadores e das séries históricas
- `12b5b45` Desliga as áreas sombreadas e ajusta os textos do perfil
- `7d743b5` Uniformiza os eixos em cinco marcações e repete as identificações
- `3c1bcfb` Ranqueia os municípios por macrorregião nas tabelas anuais
- `f2ebbf5` Reformula o perfil do município e o seletor de blocos
- `483e21b` Atualiza os testes dos eixos, das identificações e do perfil
- `(este commit)` Documenta os ajustes de acabamento da sessão
