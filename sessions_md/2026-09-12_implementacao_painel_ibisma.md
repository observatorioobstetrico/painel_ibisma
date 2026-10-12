# Sessão — Implementação do painel IBISMA

- **Data:** 12/09/2026
- **Pacote:** `painel_ibisma`
- **Objetivo:** construir a primeira versão do painel do IBISMA — Índice Brasileiro de
  Insegurança em Saúde Materna — em R/Shiny + golem + bslib, de forma modular,
  responsiva e validada com smoke tests visuais/headless.

---

## 1. Reconhecimento inicial

### 1.1 Documentação do projeto

`AGENTS.md` foi lido integralmente. Pontos que guiaram a implementação:

- Cores do OOBr (azul escuro `#0A1E3C`, azul claro `#32A0FF`, amarelo, verde etc.).
- Tamanhos de fonte apenas via classes/variáveis de
  `inst/app/www/global/custom.css`.
- Inputs de seleção devem usar `shinyWidgets::slimSelectInput` sempre que possível.
- Comentários em português, em gerúndio, de preferência uma linha por comentário.
- Código simples, sem over-engineering, comentado de forma extensiva.
- `devtools::test()` para testes; `dev/headless_smoke.R` para smoke visual/headless.

### 1.2 Estrutura existente

O projeto continha apenas o esqueleto golem:

```
R/            app_config.R, app_server.R, app_ui.R, run_app.R
inst/app/www/ global/custom.css (só variáveis de fonte), funcoes_javascript.js (vazio), logos/
data/         df_ibisma.rda
data-raw/     cria_rda.R, databases/base_exemplo_ibisma.csv, tabela_aux_municipios.csv
dev/          01_start.R, 02_dev.R, 03_deploy.R, run_dev.R
```

Descobertas que exigiram cuidado:

- `inst/app/www/logos/global/` guardava cópias antigas e gigantes de CSS/JS
  (~311 KB + ~659 KB) que o `golem::bundle_resources()` carregaria automaticamente,
  quebrando o layout. **Solução:** deixar de usar `bundle_resources()` e carregar
  explicitamente apenas `www/global/custom.css` e `www/global/funcoes_javascript.js`.
  Os arquivos antigos não foram apagados.

### 1.3 Dados (`data/df_ibisma.rda`)

| Característica | Valor |
| --- | --- |
| Linhas | 55.699 |
| Municípios | 5.570 |
| Anos | 2015 a 2024 |
| Colunas | `ano`, `codmunres` (6 dígitos — padrão DATASUS), `bloco1..bloco6`, `indice_final`, `municipio`, `uf`, `sigla_uf`, `regiao`, `cod_r_saude`, `r_saude`, `cod_macro_r_saude`, `macro_r_saude` |
| Valores | Percentis em 0–1 (uniformes por ano); exibidos em 0–100 |
| Ausências | Nenhum `NA`; apenas **Borá/SP não tem 2023** (5569 municípios no ano) |
| Extras | Colunas para níveis futuros já disponíveis: `regiao`, `r_saude`, `macro_r_saude` |

O código municipal tem 6 dígitos (equivalente ao código IBGE de 7 dígitos sem o
dígito verificador). A malha do `geobr` foi ligada por
`substr(code_muni, 1, 6)` — cobertura de **100%**.

### 1.4 Ambiente

R 4.4.3 (Windows). Pacotes relevantes disponíveis: `shiny` 1.13, `golem` 0.5.1,
`bslib` 0.10, `shinyWidgets` 0.9.1, `leaflet` 2.2.2, `sf` 1.0.20, `geobr` 2.0.1,
`echarts4r` 0.4.5, `reactable` 0.4.4, `highcharter` 0.12.2, `waiter` 0.2.5,
`fontawesome` 0.5.3, `chromote` 0.5.1, `callr` 3.7.6, `devtools` 2.4.5,
`roxygen2` 7.3.2, `testthat` 3.2.3.

### 1.5 Referências de UX estudadas

- **US MVI (Surgo)** — mapa com filtro por tema em "pills", legenda de 5 classes
  ("Very High" a "Very Low"), dica de hover, comparação por clique e rodapé com
  fontes. Inspirou o Panorama.
- **Índice de Transparência Covid-19 (OKBR)** — mapa à esquerda e ranking à
  direita, alternância Estados/Capitais, medalhas de nível e trilha de leitura.
  Inspirou a integração mapa + ranking.
- **IMAPI** — perfil do município com nome em destaque, métricas de contexto,
  flor de domínios e rankings Brasil/estadual. Inspirou o Perfil.

Nenhum painel anterior do IBISMA foi consultado — a construção partiu das
instruções e das referências acima, por decisão explícita do usuário.

---

## 2. Avaliação e decisões tomadas

1. **Visão geral + Ranking integrados** na seção "Panorama". Motivos: controles
   únicos (nível, ano, medida), menos sincronização de estado, mapa e ranking se
   destacam mutuamente, página mais curta. No desktop ficam lado a lado (6/6); no
   mobile empilham.
2. **Navbar com 2 âncoras** (`Panorama`, `Perfil dos municípios`), scroll suave,
   item ativo via JS (scrollspy) e menu colapsável no mobile.
3. **Cores:** IBISMA em 5 tons de roxo; cada bloco com cor própria; "Sem dados"
   em cinza. Medidas de bloco usam rampa própria no mapa (clareia → escurece a
   partir da cor do bloco); o IBISMA usa a rampa roxa.
4. **Flor do perfil:** pétalas proporcionais (0–100) com os nomes reais dos
   blocos e pontos da **mediana Brasil** como referência (em vez de réplica
   decorativa sem escala).
5. **Comparação entre municípios:** barras de diferença (cor por direção) +
   tabela com valores e Δ, em vez de duas flores sobrepostas (ilegível).
6. **Bibliotecas por componente:** `leaflet` (mapa, canvas e sem tiles externos),
   `reactable` (ranking), `echarts4r` (flor, evolução e diferenças).
7. **`highcharter` foi descartado** durante a sessão: o Highcharts não é gratuito
   para uso governamental (Fiocruz se enquadra) e o aviso aparece no carregamento
   do pacote. Toda a visualização foi unificada em ECharts (Apache-2.0).
8. **Nível de análise** implementado como configuração (`NIVEIS_ANALISE`) com
   apenas "Município" habilitado; UF/região entram depois acrescentando linhas.

---

## 3. Malha geográfica (data-raw/prepara_malha.R)

- `geobr::read_municipality(year = 2020)` e `read_state(year = 2020)`; a malha
  do geobr já vem simplificada (`simplified = TRUE`).
- **Descoberta importante:** o CRS é EPSG:4674 (geodésico), então
  `sf::st_simplify(dTolerance = ...)` interpreta a tolerância em **metros**.
- Simplificação com tolerância **2.000 m** e recuperação dos 3 municípios que
  desapareceriam usando a malha de 1.000 m.
- Conversão para **EPSG:4326** (exigência do leaflet).
- Chave `codmunres` de 6 dígitos criada a partir de `substr(code_muni, 1, 6)`.
- Saídas salvas em `inst/app/data/`:
  - `malha_municipios.rds` — 1,0 MB (5.570 municípios)
  - `malha_ufs.rds` — 0,09 MB (27 UFs)
- Validação de cobertura: 100% dos códigos da base encontrados na malha.

Arquivos gerados (não versionados como data de pacote, servidos como recurso do app).

---

## 4. Arquitetura entregue

```
R/
├── app_config.R              (existente) caminhos e config golem
├── app_ui.R                  shell: tema bslib, navbar por âncoras, seções, recursos com cache-busting
├── app_server.R              cache da base, estado compartilhado do município, waiter, módulos
├── run_app.R                 (existente)
├── fct_config.R              BLOCOS, MEDIDAS, PALETA_IBISMA, CATEGORIAS, NIVEIS_ANALISE, textos
├── fct_cores.R               cor_medida, paleta_categorias, cor_categoria, paleta_mapa, contraste
├── fct_dados.R               preparar_dados, tabela_ano, valores_ano, resumo_municipio, séries,
│                             comparações, opções de seletores, formatadores pt-BR
├── fct_mapa.R                malha em cache, dados_mapa, malha_do_ano, tooltip, leaflet base,
│                             desenho de municípios/UF e mensagem customizada de atualização
├── fct_graficos.R            estilo e tooltips ECharts, flor polar, evolução, diferenças, gráfico vazio
├── utils_ui.R                tema_ibisma, navbar, título de seção, controle em frase, selos,
│                             legenda, métrica, estado vazio, rodapé, atualizar_seletor
├── mod_panorama.R            controles, mapa, legenda, ranking reactable e sincronizações
├── mod_perfil_municipio.R    hero, flor, índice, evolução, comparação e estados sem dado
└── painel_ibisma-package.R doc do pacote (import shiny, sf)

inst/app/www/global/
├── custom.css               identidade visual completa (~25 KB)
└── funcoes_javascript.js    handler do mapa + scrollspy/menu (~3,5 KB)

tests/testthat/
├── test-funcoes_globais.R   61 testes das funções globais
└── (tests/testthat.R)

dev/headless_smoke.R         smoke test visual/headless parametrizável
```

### 4.1 Configuração central (`fct_config.R`)

- `BLOCOS`: bloco1=Social, bloco2=Planejamento Reprodutivo, bloco3=Pré-natal,
  bloco4=Parto, bloco5=Sistema de saúde, bloco6=Clima — **ordem confirmada pelo
  usuário** (o arquivo de dados não traz dicionário).
- Cores dos blocos: Social `#FAC80F`, Planejamento `#41BE3C`, Pré-natal
  `#32A0FF`, Parto `#E4572E`, Sistema `#1E5AA0`, Clima `#00A6A6`.
- `PALETA_IBISMA` (5 classes): `#EFE6F7`, `#C9A8E4`, `#9F6FD0`, `#7239A8`, `#4B1D73`.
- `PROBS_CORTES = c(.2, .4, .6, .8)` — categorias por quintis da distribuição de
  cada ano e medida.

### 4.2 Dados (`fct_dados.R`)

- `dados_ibisma()` prepara a base **uma vez por processo** (cache em ambiente).
- Formato longo com as 7 medidas, valores em 0–100.
- `tabela_ano()` (com cache por ano) calcula, para cada medida: cortes, categoria,
  rank nacional e rank na UF (posição 1 = mais vulnerável).
- `resumo_municipio()`, `serie_municipio()`, `comparar_series()`, `comparar_ano()`.
- `municipio_padrao()`: abre o painel no município mais vulnerável do último ano
  (Jutaí/AM em 2024).
- `frase_percentil()` limita o texto a "acima de 99%" para não dizer 100%.
- Formatadores pt-BR (`12,3`, `5.570`, `1.234º de 5.570`).

### 4.3 Mapa (`fct_mapa.R`)

- Malha carregada em cache de processo.
- `malha_do_ano()` junta geometria + cor + tooltip e cria `codmunres_txt`
  (o leaflet só indexa `layerId` do tipo string).
- Tooltip em HTML próprio (município/UF, medida, valor e selo de categoria),
  incluindo "Sem dados" em cinza.
- Sem tiles externos (estética editorial), `preferCanvas = TRUE`, contornos de UF
  por cima e reenquadramento do Brasil após `invalidateSize()`.

### 4.4 Gráficos (`fct_graficos.R`)

- Tema ECharts com fonte Source Sans Pro e tooltips padronizados.
- **Flor polar** (`grafico_flor`): `e_polar` + barras com `coord_system = "polar"`,
  `e_angle_axis(serie = nome)` para os rótulos dos blocos, pontos da mediana
  Brasil e legenda própria.
- **Evolução** (`grafico_evolucao`): até 2 séries (linha cheia e tracejada),
  eixo X de anos como eixo de valor (2015–2024) e marcador do ano selecionado.
- **Diferenças** (`grafico_diferencas`): barras horizontais centradas no zero,
  cor coral (mais insegurança) / verde (menos insegurança) e tooltip com valores.
- `grafico_vazio()` sempre com título (ver seção de correções).

### 4.5 UI/UX

- Controles em frase natural com `slimSelectInput` sublinhado ("Mostrar IBISMA
  dos municípios em 2024"; "Ver Jutaí (AM) em 2024 e comparar com Nenhum").
- Blocos com fundo claro, sem "cara de dashboard"; muito espaço em branco.
- Ranking com busca sem acentos (`normalize('NFD')`), paginação, seleção única e
  selos de categoria pré-renderizados em HTML vetorizado.
- Estados vazios ilustrados (ícone + texto) para município sem dado no ano.
- `waiter` cobria o primeiro carregamento (removido na Sessão 2 — ver adiante).
- Acessibilidade: foco visível, `aria-*` na navbar/mapa, descrições nos gráficos
  (quando suportado) e contraste calculado para selos (`cor_texto_sobre`).

### 4.6 Navegação e responsividade

- Navbar sticky com blur, âncoras e item ativo por JS; menu hambúrguer no mobile.
- Tipografia com breakpoints adicionais em 768 px; controles empilham; mapa com
  altura por `clamp()`/`vh`; rodapé reorganizado.
- `prefers-reduced-motion` respeitado no scroll suave.

---

## 5. Problemas encontrados e correções (aprendizados)

1. **`bundle_resources()` carregava CSS/JS legados** de `www/logos/global/`.
   Solução: carregamento explícito dos dois arquivos do painel.
2. **Cache do navegador servia JS antigo** durante o desenvolvimento.
   Solução: versão por `mtime` do arquivo nas URLs (`?v=AAAAMMDDHHMMSS`).
3. **`reactable::searchMethod`** recebe `(rows, columnIds, searchValue)` e deve
   **retornar o array filtrado**, não um booleano. Corrigido para busca sem acento.
4. **Funções `cell` em R no reactable são aplicadas linha a linha** — 4,3 s para
   5.570 linhas. Solução: selos pré-computados vetorizados e formatadores em JS
   (`cellInfo.value.toFixed(1)`); montagem caiu para milissegundos.
5. **`echarts4r` usa `coord_system`, não `coordinateSystem`** — o argumento
   inválido criava uma chave duplicada e quebrava o gráfico polar.
6. **Gráfico ECharts sem título e sem série derruba o render**
   (`Cannot read properties of undefined (reading 'coordinateSystem')`).
   Solução: `grafico_vazio()` sempre com título.
7. **Trocar a estrutura de opções do mesmo ECharts** (flor → gráfico vazio)
   reusa a instância e quebra. Solução: o gráfico só é inserido dinamicamente
   via `renderUI` quando há dados; caso contrário, aparece um estado vazio.
8. **Um widget com erro JS interrompe a fila de renderização do cliente**: o
   `values` do Shiny é processado em sequência e um erro em um output impede os
   seguintes. Isso explicou telas parcialmente vazias e títulos "presos".
9. **`leaflet` só indexa `layerId` string**; e `layerManager._byLayerId` guarda a
   própria camada (não um objeto com `.layer`), com chave `"categoria\nid"` —
   o handler JS foi escrito a partir dessa estrutura.
10. **`HTMLWidgets.getInstance(el)` pode estar indefinido** dependendo do ciclo
    de vida; `HTMLWidgets.find("#id")` se mostrou confiável no handler.
11. **`fontawesome::fa()` não aceita `class`** e não passa por
    `tagAppendAttributes`; a classe foi aplicada em um `<span>` externo.
12. **`st_simplify` em CRS geodésico usa metros** — a primeira tentativa com
    tolerâncias em graus não simplificava nada.
13. **Licença do Highcharts** — pacote `highcharter` removido das dependências.

---

## 6. Testes e validação

### 6.1 Testes unitários — `tests/testthat/test-funcoes_globais.R`

- 61 asserções, todas passando, cobrindo:
  - preparação da base (formato longo, escala 0–100, anos);
  - cortes por quintis e categorização (incluindo `NA` e cortes repetidos);
  - rankings nacional e por UF (posição 1 = mais vulnerável);
  - `resumo_municipio`, séries e comparações;
  - formatadores pt-BR e frase de percentil;
  - paletas/cores e contraste;
  - opções de medida, ano e escopo;
  - selos, cores de mapa e `municipio_padrao`.

Comando: `devtools::test()` (ou `devtools::test(filter = "funcoes_globais")`).

### 6.2 Smoke test visual/headless — `dev/headless_smoke.R`

Interface conforme AGENTS.md (porta, outdir, wait-for, shot, eval, width, height)
e extensões: `--full` (página inteira), `--scroll`, `--mobile`, `--espera`,
`--eval-file`. Registra erros de JS e erros do servidor no fim da execução.

Fluxos verificados por headless (chromote):

- carregamento inicial (mapa, ranking, flor, evolução sem erros);
- hover no mapa com tooltip ("Primavera do Leste (MT) — IBISMA 44,0 — Médio");
- clique no mapa seleciona o município e atualiza o perfil;
- clique em linha do ranking atualiza o perfil e destaca no mapa;
- troca de medida (mapa recolorido na rampa do bloco e legenda atualizada);
- ranking por UF (645 municípios de SP) e busca sem acento ("sao paulo", "iporanga");
- comparação entre municípios (barras coloridas + tabela com Δ);
- cenário sem dados (Borá/2023) com estados vazios e retorno correto;
- navbar: âncora rola para a seção e o item ativo acompanha;
- desktop (1600×950) e mobile (390×844).

Evidências salvas em `dev/smoke/` (`final_completo.png`, `final_mobile.png`,
`mapa_tooltip.png`, `interacao_comparacao.png`, `sem_dados.png` etc.).

---

## 7. Estado final do repositório

- `R/` com 2.701 linhas distribuídas em 13 arquivos (fatores, módulos e utilitários).
- `tests/testthat/test-funcoes_globais.R` com 142 linhas e 61 testes verdes.
- `inst/app/data/` com as duas malhas (~1,1 MB no total).
- `inst/app/www/global/` com o CSS do painel (~25 KB) e o JS (~3,5 KB).
- `DESCRIPTION` com as dependências reais (`bslib`, `shinyWidgets`, `leaflet`,
  `sf`, `tidyr`, `reactable`, `echarts4r`, `waiter`, `fontawesome`, `htmltools`,
  `htmlwidgets`, `jsonlite` etc.), `Suggests` com `testthat`, `chromote` e
  `callr`, e `Config/testthat/edition: 3`.
- `.gitignore` com `.Rproj.user`, `.Rhistory` e `dev/smoke/`.
- `NAMESPACE` gerado por `devtools::document()`.

---

## 8. Como rodar e validar

```r
# carregar e rodar
pkgload::load_all()
run_app()                    # ou dev/run_dev.R

# testes
devtools::test()
devtools::test(filter = "funcoes_globais")

# smoke visual (na raiz do pacote)
Rscript dev/headless_smoke.R --wait-for="#panorama-mapa" --full --shot=painel.png
Rscript dev/headless_smoke.R --mobile --width=390 --height=844 --shot=mobile.png \
  --eval="document.querySelectorAll('.leaflet-container').length"
```

---

## 9. Limitações conhecidas e próximos passos

1. **Níveis de análise:** apenas município habilitado. UF e região já existem nos
   dados; basta acrescentar linhas em `NIVEIS_ANALISE` e tratar agregação.
2. **Seletores grandes:** a sincronização do perfil usava
   `session$sendInputMessage()`. Na Sessão 2 foi corrigida para a função oficial
   `shinyWidgets::updateSlimSelect()` (que existe no pacote).
3. **Primeiro carregamento do mapa** leva ~3–5 s por causa da serialização da
   geometria. Alternativas: TopoJSON, mais simplificação ou clustering.
4. **Sem exportação** de dados/figuras e sem compartilhamento por URL.
5. **Tooltips comparativos dentro do mapa** (ex.: diferença entre municípios)
   ficaram fora do escopo desta primeira versão.
6. **Descrições de acessibilidade** existem no código, mas o módulo de
   acessibilidade do ECharts não está disponível na versão atual do pacote.
7. **Base de exemplo:** o rodapé deixa claro que os dados são um exemplo de
   desenvolvimento e que o IBISMA é um índice relativo (percentil).

---

## 10. Decisões pendentes de confirmação

- O mapeamento `bloco1..6` → nomes foi feito na ordem do AGENTS.md
  (Social → Clima). Se a ordem real for outra, basta ajustar `BLOCOS` em
  `R/fct_config.R`.
- A seção única "Panorama" substitui as entradas separadas "Visão geral" e
  "Ranking" do pedido original, por decisão de UX documentada na seção 2.

---

# Sessão 2 — Correções e refinamentos (12/09/2026)

- **Pacote:** `painel_ibisma` (esta base seguiu adiante; uma versão anterior
  foi consultada apenas como referência visual dos componentes corrigidos).
- **Objetivo:** corrigir problemas específicos e aproximar navbar, mapa e
  gráfico de pétalas do que já havia sido melhor resolvido na versão anterior,
  sem regredir o restante.

## 1. SlimSelect

- `updateSlimSelect()` **existe** no shinyWidgets 0.9.1 — a limitação registrada
  na Sessão 1 estava incorreta. `atualizar_seletor()` passou a usá-la no lugar
  do `session$sendInputMessage()`.
- A largura das opções passou a ser tratada apenas no dropdown aberto
  (`width: max-content` com teto de `min(92vw, 30rem)`), sem alterar o input
  fechado; um observador no JS reposiciona a lista quando ela ultrapassaria a
  borda da janela.
- O roxo foi removido dos seletores: valor exibido, foco e opção destacada usam
  o azul médio `#1E5AA0` (hover continua no azul claro `#32A0FF`).

## 2. Navbar

- **Causa de desaparecer no scroll:** o `page_fillable()` criava
  `.bslib-page-fill { height:100% }`, o que limitava o `position: sticky` à
  viewport. O CSS libera a altura natural do documento (`height: auto` +
  `min-height: 100vh`).
- Visual: fundo `#0A1E3C`, IBISMA + descrição do índice (visível a partir de
  `lg`), itens brancos. O indicador inferior do painel foi mantido (sublinhado
  azul claro) e, no menu colapsado, acompanha a largura do texto.

## 3. Mapa

- O zoom-out parou de encolher o mapa indefinidamente: `setMaxBounds` +
  `maxBoundsViscosity = 1` (como na versão anterior) e zoom mínimo calculado
  dinamicamente
  para o enquadramento do Brasil conforme o contêiner (4 no desktop, 3 no
  mobile), recalculado em resize.
- A entrada "Sem dados" saiu da legenda (`com_sem_dados = FALSE`); cores e
  tooltip de municípios sem dado seguem iguais.

## 4. Busca do ranking

- **Causa:** o `searchMethod` do reactable recebe objetos de linha e os valores
  ficam em `linha.values`; o código lia `linha.municipio`, então nada casava.
- Corrigido para `linha.values.municipio` / `linha.values.sigla_uf`, mantendo a
  normalização de acentos e maiúsculas.

## 5. Gráfico de pétalas

- A flor polar do echarts4r foi substituída pelo leque SVG da versão anterior
  (`R/fct_petalas.R`), com guias, marcas de 25/50/75, círculo de valor e ponto
  da mediana do Brasil.
- Tooltip própria (Bootstrap 5, inicializada no JS) no padrão do painel, com
  bloco, valor, ranking e selo de categoria; é reinicializada por
  `MutationObserver` a cada redesenho.
- `grafico_flor()` (echarts) removido e corrigido o `estilo_echarts()`, que
  quebrava a legenda com duas séries por causa do casamento parcial
  `icon` → `icons` do echarts4r.

## 6. Remoção do waiter

- `waiter` foi removido do app e das dependências por não funcionar bem.

## 7. Testes e validação

- `devtools::test()`: 74 asserções verdes (novos testes de limites do mapa,
  legenda e pétalas).
- O smoke headless foi ampliado (`--mouse`, `--click`, promises e captura por
  viewport) e validou: navbar sticky/scrollspy, zoom mínimo em desktop e mobile,
  busca (termo exato, parcial, com acento, troca de ano/indicador e ordenação),
  tooltip real nas seis pétalas, dropdowns em 1600/720/390 px, cenário sem
  dados (Borá/2023) e comparação entre municípios.
- Evidências em `dev/smoke/sessao_correcoes/` (ignorado pelo git).

> Observação de ambiente: o `rlang` 1.1.4 instalado ficou abaixo do exigido
> pelo `testthat` 3.3.2; a suíte foi rodada com `rlang` 1.2.0 vindo de uma
> biblioteca temporária. Recomenda-se atualizar o pacote com o R fechado.

---

# Sessão 3 — UI/UX, cores e hierarquia (12/09/2026)

- **Pacote:** `painel_ibisma`.
- **Objetivo:** corrigir cinco problemas de UI/UX e comportamento, centralizar
  a lógica de cores por dimensão e validar tudo com smoke tests headless.

## 1. Posicionamento das seções ao clicar na navbar

- **Causa raiz:** `html { scroll-padding-top: ... }` **e** `section[id] {
  scroll-margin-top: ... }` eram aplicados juntos; o navegador soma os dois,
  parando a seção ~176 px abaixo do topo (navbar + sobra da seção anterior).
  A altura ainda era um chute fixo (`--altura-navbar: 4.75rem`) e não
  acompanhava breakpoints.
- **Correção estrutural:** o CSS passou a compensar só com `scroll-margin-top:
  var(--altura-navbar)`; o JavaScript mede a altura real da navbar
  (`ResizeObserver` + `resize`) e grava em `--altura-navbar`. Os cliques nas
  âncoras são interceptados: o menu móvel fecha primeiro, a altura é remedida
  e a rolagem usa `section.top - altura_navbar` (com respeito a
  `prefers-reduced-motion`). Deep link com hash na URL também é reposicionado
  no `load`.
- **Validação:** offset seção↔navbar de 0,0–0,4 px em desktop, após `resize`
  e no mobile (menu abrindo e fechando), com o item ativo do scrollspy correto.

## 2. Paleta central por medida (uma fonte de verdade)

- `fct_cores.R` ganhou `paleta_bloco()` e `paleta_medida(medida)`; `paleta_mapa`
  e `paleta_categorias` passaram a delegar para ela.
- `cor_categoria(categoria, medida = "indice_final")` e
  `montar_selos(categorias, medida)` agora aceitam a medida.
- Tooltip do mapa (`tooltip_municipio`) recebe a paleta da medida: a chip da
  categoria deixa de ser sempre roxa e passa a usar a rampa do IBISMA ou do
  bloco exibido, com cor de texto por contraste.
- Tooltip das pétalas ganhou marcador ao lado do título e selo de categoria na
  rampa do bloco (`--cor-medida` + `cor_categoria(categoria, medida)`).
- **Descoberta:** o Bootstrap sanitiza o HTML do tooltip e remove `style` em
  linha; as cores dinâmicas eram descartadas. As tooltips das pétalas passaram
  a ser inicializadas com `sanitize: false` (o conteúdo é gerado pelo servidor).
- Ranking, legenda do mapa, evolução temporal e pétalas consomem as mesmas
  funções; o tema do reactable deriva os tons de destaque de `COR_IBISMA` com
  `misturar_cores()` em vez de hexadecimais soltos.
- O campo de busca dos `slimSelectInput` passou a exibir "Buscar..." no lugar
  do "Search" padrão do plugin.

## 3. Rebalanceamento das cinco categorias

- IBISMA: `#D5C2E8`, `#B592D6`, `#915EC4`, `#6B35A3`, `#4B1D73`.
- Blocos: rampa derivada com pesos 0,62 e 0,30 para o branco e 0,32 e 0,62 para
  o azul escuro (antes 0,88/0,55 no branco), mantendo a cor do bloco na
  categoria central. "Muito baixo" deixou de se confundir com o fundo do mapa e
  com as bordas brancas, e as cinco categorias seguem progressivas e distintas.
- `grafico_petalas()` ganhou uma legenda de nomes (sem valores, que continuam
  só nas pétalas) para identificar os blocos sem hover.

## 4. Ranking com 12 linhas fixas

- Removidos `pageSizeOptions` e `showPageSizeOptions`; a tabela continua
  paginada, com `defaultPageSize = 12` e a última página com o resto.

## 5. Perfil dos municípios — palco único

- A tabela de valores dos blocos foi removida.
- A primeira versão da sessão empilhou o resumo e as pétalas em coluna única,
  mas o resultado desperdiçava a largura. O perfil foi refeito como um palco
  único inspirado no IMAPI: nome do município e métricas territoriais no topo,
  leque de pétalas grande e centralizado e, na base, um placar com o ranking
  Brasil à esquerda, o valor do IBISMA nomeado ao centro ("IBISMA em \<ano\>",
  "de 100", selo e frase de percentil) e o ranking estadual à direita.
- No mobile o placar empilha com o valor primeiro e os rankings abaixo.
- O leque ganhou `viewBox` recortado (`45 60 410 236`) e limite de altura
  `min(56vh, 520px)`, crescendo dentro do palco sem esticar o desenho.
- Ajustes finais pedidos a partir da referência: nome e UF em um único
  destaque (`Jutaí, AM`, sem elemento separado para a sigla); a descrição das
  pétalas passou para logo abaixo das métricas, antes do leque; a lembrança
  textual "Mediana Brasil" saiu da legenda (os pontos escuros continuam no
  desenho, explicados pelo texto).
- O ranking estadual passou a ser rotulado "Ranking na UF (Amazonas)".
- Todos os valores exibidos no painel usam uma casa decimal, incluindo o
  número dentro de cada pétala e o valor em destaque do IBISMA.
- A frase de percentil passou a usar uma casa decimal e teto de 99,9% (antes
  99%), para não subestimar o município mais vulnerável do ranking.
- Ordem da seção: identificação (controles + palco) → evolução → comparação.

## 6. Testes e validação

- `devtools::test()`: 115 asserções verdes (novos testes de `paleta_medida`,
  `cor_categoria`/`montar_selos` por medida, chip do tooltip do mapa e da
  pétala, arredondamento em uma casa e frase de percentil em 99,9%).
- Smoke headless: navbar (cliques, resize, hash, mobile), mapa com as 7 medidas
  (preenchimentos e legenda idênticos às paletas), tooltips com chip correta,
  ranking (12 linhas, sem seletor, chips por medida, busca), perfil (palco
  ocupando a largura útil, valor centralizado entre os rankings, ausência da
  tabela antiga, pétalas com tooltip, evolução com comparação, tabela de
  diferenças), cenário sem dados (Borá/2023, com o placar desaparecendo e
  voltando ao trocar o ano) e responsivo em 1600/1024/390 px sem estouro
  horizontal.
- `dev/headless_smoke.R` ganhou `--pre-eval`/`--pre-eval-file` para preparar um
  estado (trocar medida, abrir tooltip) antes do screenshot.

## 7. Limitações remanescentes

- O eixo de anos da evolução ainda mostra separador de milhar ("2.015").
- O `sanitize: false` das tooltips das pétalas é seguro porque o HTML é gerado
  pelo servidor a partir da base; não usar essa opção para conteúdo de usuário.
- Os rótulos numéricos das barras de comparação não aparecem no gráfico (os
  valores seguem na tooltip e na tabela); comportamento pré-existente.

---

# Sessão 4 — Evolução temporal e comparação lado a lado (13/09/2026)

- **Pacote:** `painel_ibisma`.
- **Objetivo:** corrigir dois problemas do gráfico de evolução temporal
  (formatação do eixo X e sete séries simultâneas) e reformular completamente a
  comparação entre municípios, que passou a acontecer nos próprios elementos do
  perfil (palcos e gráficos lado a lado), sem seção independente.

## 1. Eixo X do gráfico temporal

- **Causa:** o eixo de valor do ECharts formata números com quatro dígitos com
  separador de milhar por padrão (`2.015`). Não era problema de dado: os anos
  sempre foram inteiros.
- **Correção:** `grafico_evolucao()` passou a definir o formatter do eixo
  (`e_x_axis(formatter = JS("Math.round(...)"))`), mantendo `min`, `max` e
  `interval = 1`. Funciona em qualquer município e com a comparação ativa
  (o formatter é reaplicado a cada re-render).
- **Teste:** o objeto do gráfico é inspecionado quanto ao formatter
  (`JS_EVAL` com `Math.round`) na suíte.

## 2. Sete séries no gráfico de evolução

- `series_municipio()` (em `fct_dados.R`) monta um data frame com `ano` e uma
  coluna por medida, preenchendo anos ausentes com `NA`; `series_tem_valor()`
  decide quando há algo para desenhar.
- O gráfico desenha **IBISMA + seis blocos** de uma vez, com os nomes e as cores
  reais de `MEDIDAS`; o IBISMA é a linha mais espessa e todas as séries mostram
  o ponto de cada ano como círculo (`symbolSize = 6`, borda branca).
- O seletor "Evolução do" foi removido — a leitura é sempre conjunta.
- As cores continuam representando **dimensões**, nunca municípios.

## 3. Legenda nativa compartilhada (reformulada em duas etapas)

- A legenda HTML foi descartada. A pedido, passou a ser a legenda **nativa do
  ECharts**, primeiro embutida no gráfico principal; na revisão final, foi
  movida para **um widget ECharts próprio, abaixo dos gráficos e centralizado
  entre os dois**, com os eixos e a grade escondidos (`grafico_legenda()`).
- `estilo_echarts()` centraliza a legenda (`left = "center"`), usa os ícones
  padrão das séries, `itemGap = 16` e altura responsiva por media query.
- O widget de legenda entra no **mesmo grupo** dos dois gráficos
  (`e_group` + `e_connect_group`): clicar em um item oculta/mostra a série nos
  **dois** gráficos. A sincronização também faz as **tooltips** aparecerem no
  mesmo ano nos dois gráficos — leitura comparativa direta.
- **Persistência da seleção:** a echarts4r publica a seleção da legenda em
  `input$legenda_evolucao_legend_selected`; os gráficos a reaplicam com
  `shiny::isolate()`, de modo que esconder uma série sobrevive à troca de ano,
  à troca do município principal e à troca/remoção da comparação, sem
  re-renderizar os gráficos a cada clique na legenda.

## 4. Comparação reformulada, sem seção própria

- A seção "Comparação entre municípios" foi removida por completo (interface,
  gráfico de diferenças, tabela e linha pontilhada), junto das funções
  `comparar_series()`, `comparar_ano()`, `grafico_diferencas()`,
  `eh_tooltip_diferencas()` e `grafico_vazio()`, e `jsonlite` saiu das
  dependências.
- **Palcos reutilizáveis:** `perfil_palco()` (novo `R/fct_perfil.R`) monta
  identificação, métricas territoriais, pétalas e placar para qualquer
  município; `perfil_placar()` concentra o placar. O mesmo componente serve
  principal e comparado, mudando apenas os argumentos.
- **Evolução reutilizável:** o mesmo `grafico_evolucao()` desenha cada
  município; cada um tem seu próprio gráfico (não compartilham o mesmo canvas).
- **Estados controlados:** sem comparação há um palco e um gráfico; com
  comparação, dois de cada; ao remover, a coluna comparada é suspensa (`req`)
  e o layout volta suavemente. Trocar o principal mantém a comparação ativa e
  atualiza apenas o lado esquerdo.
- **Hierarquia:** rótulos "Município principal"/"Município comparado" e títulos
  com o nome de cada município acima dos gráficos.

## 5. Transições e espaçamento

- **Causa da animação invisível:** a transição usava
  `grid-template-columns` (não interpola em engines mais antigas) e era
  desligada por `prefers-reduced-motion: reduce` — que é o padrão do Chrome
  headless e pode estar ativo no sistema do usuário.
- **Correção:** a `.dupla` passou a ser um **flex** com transição em
  `flex-basis`/`max-width`/`margin-left`/`opacity` (interpola em qualquer
  navegador) e o desligamento por `prefers-reduced-motion` foi removido para
  essa transição.
- **Verificação de verdade:** o smoke ganhou `--motion` e `--reduce`, que emulam
  a preferência via CDP, e a largura das colunas passou a ser amostrada a cada
  80 ms. Resultado real: `1376x0 → 1340x35 → 1112x256 → 890x470 → 763x592 →
  664x688` (com `no-preference` e com `reduce`).
- **Espaçamento palco ↔ evolução:** o card do palco tem `height: 100%`; dentro
  da coluna com `overflow: hidden`, a `margin-bottom` era clipada e a evolução
  encostava no palco. A margem dos cards dentro da `.dupla` foi zerada e o
  respiro (`1.5rem`) passou a vir da `.dupla--palcos` — medido em 24 px.

## 6. Tooltip da evolução

- Mostra `Município (UF) — ano` e as sete linhas, com marcadores nas cores das
  dimensões e valores ausentes omitidos; nomes com apóstrofo são escapados
  (`encodeString`) antes de entrar no JavaScript.
- Com a comparação ativa, as tooltips dos dois gráficos aparecem sincronizadas
  no mesmo ano.

## 7. Testes e validação

- `devtools::test()`: **146 asserções verdes**, cobrindo `series_municipio` /
  `series_tem_valor`, o formato do gráfico de evolução (séries, cores, símbolos,
  eixo, tooltip), `grafico_legenda` (itens, eixos ocultos, grupo, `itemGap`) e
  `perfil_palco` (identificação, pétalas, placar e estado vazio).
- Smoke headless (evidências nas pastas da sessão de comparação):
  estados A/B/C/D, troca de comparação, troca de ano, Borá/2023, animação
  amostrada, legenda compartilhada (clique sincroniza e sobrevive a re-render),
  ausência da seção antiga e da linha pontilhada, legenda abaixo/centralizada e
  responsivo em 1600/1024/390 px sem estouro horizontal.

## 8. Decisões e limitações remanescentes

- A legenda compartilhada é um widget ECharts dedicado; o custo é um canvas
  vazio de ~64 px (96 px no mobile) abaixo dos gráficos.
- O sincronismo via grupo do ECharts também sincroniza tooltips — avaliado como
  positivo para a comparação, mas pode ser desligado trocando o mecanismo por
  um espelho só da legenda, se o uso indicar.
- No empilhamento (≤1100 px) a entrada do comparado é animada; a saída é
  instantânea (o `display: none` da coluna vazia).
- Em telas muito estreitas a legenda quebra em até três linhas; a altura do
  canvas acompanha por media query.

---

# Sessão 5 — Métricas territoriais, tooltips de corte e placar (13/09/2026)

- **Pacote:** `painel_ibisma`.
- **Objetivo:** refinar o cabeçalho territorial do perfil (ordem, cortes e
  tooltips condicionais), estabilizar o placar e igualar as colunas do modo
  comparação.

## 1. Métricas territoriais em grid

- `.perfil-metricas` deixou de ser um `flex` com quebra e virou um grid de
  quatro colunas `minmax(3rem/7rem, max-content)`, com `justify-content: start`
  e respiro de 2,5 rem entre colunas.
- Cada coluna tem limite máximo próprio (8/10/18/22 rem; 7,5/8/15/19 rem até
  1280 px) e os campos ficam sempre em uma linha, com reticências quando o
  texto passa do limite — sem quebrar a linha nem mudar a altura.
- Até 768 px as informações passam a duas colunas por linha.
- **Ordem corrigida:** Região, UF, Macrorregião de saúde e Região de saúde
  (antes macrorregião e região de saúde estavam trocadas). O rótulo "Unidade
  da federação" foi encurtado para "UF".
- Os limites acompanham o conteúdo: "Região de saúde" (nomes de até ~50
  caracteres na base) ficou com o maior limite e "Macrorregião de saúde" com o
  menor, na base e na media query.
- **Modo comparação:** `justify-content: space-between` distribui as quatro
  colunas pela largura do palco quando a comparação está ativa; sem comparação
  o alinhamento segue à esquerda.

## 2. Tooltip condicional dos campos territoriais

- `metrica_hero()` ganhou o argumento `tooltip`; quando ligado, rótulo e valor
  expõem o texto completo em `data-tooltip-texto` e recebem a classe
  `metrica-tooltip`.
- No JavaScript a inicialização foi refatorada em `criarTooltip()` (rica, para
  as pétalas, e simples, para os campos). A tooltip do campo territorial só é
  criada quando o texto está de fato cortado (`scrollWidth > clientWidth`),
  com `tabindex` para leitura por teclado; quando deixa de estar cortado, a
  instância é destruída (`dispose`) e o `tabindex` removido.
- A avaliação de corte é refeita em `resize` (agendada por
  `requestAnimationFrame`), quando as fontes terminam de carregar
  (`document.fonts.ready`) e a cada novo elemento inserido pelo Shiny
  (`MutationObserver`).
- O CSS do cartão da tooltip foi simplificado: fundo branco via
  `--bs-tooltip-bg` (a seta herda a cor), opacidade 1 no `.show` e
  `font-size` na medida padrão do painel; as regras manuais de seta por
  posição foram removidas. O foco por teclado ganhou contorno visível.

## 3. Placar do IBISMA

- As laterais do placar usam `minmax(7.5rem, 1fr)`, reservando o mesmo espaço
  para os rankings nacional e estadual mesmo quando posições e totais têm
  quantidades de dígitos diferentes — o valor central não se desloca.
- Rótulo e valor de cada ranking ficam em uma única linha, com reticências.
- O ranking estadual deixou de repetir a UF no título: "Ranking na UF", sem
  "(Amazonas)".

## 4. Igualdade das colunas na comparação

- Principal e comparado usam `flex-basis: calc(50% - 0.75rem)`, descontando
  metade do respiro de 1,5 rem; antes a coluna comparada ficava com 50% e a
  principal absorvia a diferença, deixando as duas com larguras diferentes.

## 5. Testes e validação

- `devtools::test()`: **150 asserções verdes** (novas: "Ranking na UF" sem a
  UF e campos territoriais com `metrica-tooltip` / `data-tooltip-texto`).
- Smoke headless com a comparação ativa (1600×950): nos dois palcos o
  `justify-content` computado foi `space-between`, a ordem dos rótulos foi
  `Região > UF > Macrorregião de saúde > Região de saúde` e as colunas
  ocuparam a largura total (folga 0/0 nas bordas).
- Nota de ambiente: a suíte rodou com `rlang` 1.2.0 de uma biblioteca
  temporária, porque o `rlang` 1.1.4 instalado está abaixo do exigido pelo
  `testthat` 3.3.2.

---

# Sessão 6 — Pétalas com disco fixo, escala alinhada à guia (13/09/2026)

- **Pacote:** `painel_ibisma`.
- **Objetivo:** redesenhar o gráfico de pétalas (disco de valor no topo, sem
  ticks e sem mediana, escala alinhada à guia), trocar o texto do percentil e
  refinar espaçamentos do perfil.

## 1. Disco de valor e limpeza do desenho

- O disco com o valor passou a ficar sempre no fim da guia, na posição que
  indica 100, independentemente do valor do bloco; guia, disco e texto usam a
  mesma ponta (`ponta_x`/`ponta_y`).
- Removidos os ticks de 25/50/75 e o ponto da mediana do Brasil.
- Removida a infraestrutura de suporte: `distancia_petala()` (ficou sem uso),
  o argumento `medianas` de `petala_svg()`, `grafico_petalas()` e
  `perfil_palco()`, o reativo `medianas_blocos` no módulo e a função
  `mediana_referencia()` em `fct_dados.R`, que ficou sem chamadas.
- A legenda textual (`TEXTO_PETALAS`) perdeu a menção à mediana.

## 2. Escala da pétala

- Removidos os pisos de tamanho: antes o comprimento era `0,22 + 0,78v` e a
  largura `0,65 + 0,35v`; a pétala passou a escalar apenas com o valor.
- **Desalinhamento corrigido:** o caminho base da pétala tem 170 unidades de
  comprimento e a guia vai até 185; com isso, uma pétala de 49,1 terminava em
  45,1% da guia e o meio não representava 50%.
- Criada a constante `PETALAS_COMPRIMENTO <- 170`, usada no próprio `d` do
  caminho, e a escala passou a `(valor / 100) × (PETALAS_RAIO /
  PETALAS_COMPRIMENTO)`, com uma escala única para comprimento e largura: o
  meio da guia é 50% e a ponta em 100% encosta no disco.
- Valor ausente (`NA`) continua virando 0; sem mínimo, a pétala deixa de ser
  desenhada e apenas o disco aparece.

## 3. Texto do percentil

- `frase_percentil()` deixou "acima de x% dos municípios brasileiros em
  insegurança" e passou a "acima de x% dos municípios em insegurança em saúde
  materna".

## 4. Ajustes visuais do perfil (CSS)

- Placar sem a borda superior e com espaçamentos internos reduzidos de
  1,25 rem para 1 rem.
- Título "Evolução ao longo do tempo" passou a usar
  `--fonte-muito-grande-size`.

## 5. Testes e validação

- `devtools::test()`: **152 asserções verdes** — o teste das pétalas confere os
  seis discos à distância de 185 do centro, a ausência de `ponto-mediana` no
  HTML e a escala de cada pétala igual a `valor/100 × 185/170`.
- Smoke headless com Abadia de Goiás/2024: pétala Clima com razão 0,491 da
  guia (49,1%) e 2,5 px de distância do meio — coerente com a leitura
  "meio = 50%".

---

# Sessão 7 — Seções e módulos "Onde?" e "Como?" (13/09/2026)

- **Pacote:** `painel_ibisma`.
- **Objetivo:** renomear as duas seções do painel e seus módulos para
  "Onde?" (antigo Panorama/Visão geral) e "Como?" (antigo Perfil dos
  municípios), mantendo a coerência entre rótulos, âncoras e código.

## 1. Rótulos das seções

- Na navbar e no eyebrow de cada seção: "Panorama" e "Visão geral" passaram a
  "Onde?"; "Perfil dos municípios" passou a "Como?".

## 2. Módulos e âncoras

- Arquivos renomeados com `git mv` (histórico preservado):
  `R/mod_panorama.R` → `R/mod_onde.R` e `R/mod_perfil_municipio.R` →
  `R/mod_como.R`.
- Funções renomeadas: `mod_panorama_ui/server` → `mod_onde_ui/server` e
  `mod_perfil_municipio_ui/server` → `mod_como_ui/server`, com os chamados
  atualizados em `app_ui.R` e `app_server.R`.
- Ids dos módulos e âncoras das seções: `"panorama"` → `"onde"` e
  `"perfil"` → `"como"`; os outputs com namespace passam a ser `#onde-mapa` e
  `#como-palcos`.
- Classe da seção de perfil: `secao-perfil` → `secao-como`, com as duas
  regras correspondentes do CSS atualizadas.
- Mantido o termo "perfil" nos componentes de conteúdo (`fct_perfil.R`,
  `perfil_palco()`, `perfil_placar()` e classes `perfil-*`), que descrevem o
  perfil do município e não o módulo.

## 3. Testes e validação

- `devtools::test()`: **152 asserções verdes** — a suíte não referencia ids
  ou rótulos das seções.
- Smoke headless: navbar com `Onde?->#onde` e `Como?->#como`, seções `#onde`
  e `#como` presentes e módulos `#onde-mapa` e `#como-palcos` renderizando,
  sem erros de JavaScript ou de servidor.

---

# Sessão 8 — Esqueletos de carregamento (13/09/2026)

- **Pacote:** `painel_ibisma`.
- **Objetivo:** adicionar esqueletos de carregamento a todos os outputs,
  preservando o espaço do conteúdo, com o visual do painel hospitalar e sem
  mudanças bruscas de layout.

## 1. Arquitetura em slots empilhados

- `R/fct_esqueleto.R` passou a montar os esqueletos e o helper
  `esqueleto_slot(output, esqueleto)`, que cria `div.esqueleto-slot` com
  `display: grid` e os dois na mesma célula (`grid-area: stack`).
- O CSS exibe o esqueleto apenas enquanto o output está `:empty`
  (``.esqueleto-slot > :not(.esqueleto):empty + .esqueleto``) e o esconde
  assim que o conteúdo renderiza; como os dois ocupam a mesma célula, a
  altura é sempre `max(esqueleto, conteúdo)`.
- Os wrappers de `uiOutput` (que o Shiny deixa `display: contents`) viram
  blocos dentro dos slots para permitir a sobreposição.
- A primeira versão usava templates clonados por JavaScript; a versão final
  adotou a arquitetura de slot do painel hospitalar e **removeu o controlador
  JavaScript** (o arquivo `funcoes_javascript.js` só recebeu o marcador de
  carga inicial).

## 2. Cores e animação iguais às do painel hospitalar

- Gradiente e animação copiados literalmente do
  `painel_hospitalar_copilot`: `linear-gradient(90deg, rgb(224 233 242 / 68%)
  24%, rgb(246 249 252 / 82%) 50%, rgb(224 233 242 / 68%) 76%)`,
  `background-size: 210% 100%` e `animation: loading-shimmer 1.7s infinite
  ease` (`background-position: 200% → -200%`).
- O hospitalar não tem guarda de `prefers-reduced-motion` para o shimmer; a
  primeira versão do painel desligava a animação nesse caso e o brilho
  parecia parado (o Windows do usuário está com os efeitos de animação
  desligados). A guarda foi removida para manter a paridade.
- Mapas, pétalas e curvas (SVG) não aceitam `background` animado; receberam
  uma camada `::after` com as mesmas cores e o mesmo `loading-shimmer` sobre
  o desenho.

## 3. Esqueleto do mapa

- Saíram as formas circulares abstratas; entrou a **silhueta do Brasil**
  gerada a partir da malha real: `st_union` das UFs, `st_simplify` de 20 km
  (184 pontos) e normalização para um viewBox `0 0 100 100`.
- O caminho foi embutido como constante `ESQUELETO_MAPA_BRASIL` e o SVG usa
  `preserveAspectRatio="xMidYMid meet"`, com o controle de zoom reservado.

## 4. Esqueletos apenas no carregamento inicial

- `funcoes_javascript.js`: no primeiro `shiny:idle` (que fecha a primeira
  fila de recálculos), espera 700 ms, confirma que não há `.recalculating` e
  adiciona `pagina-carregada` ao `<html>`; se houver recálculo atrasado,
  tenta de novo a cada 250 ms.
- O CSS `html.pagina-carregada .esqueleto-slot > .esqueleto` esconde os
  esqueletos definitivamente, inclusive em elementos recriados (gráficos de
  evolução na troca de município) e no palco comparado.

## 5. Diagnóstico do flash de rodapé

- Um gravador por `requestAnimationFrame` mediu a altura da página durante a
  carga: ela caía de **2819 px para 1777 px por ~150 ms** quando os
  esqueletos eram removidos (o controlador JavaScript os removia no início
  do flush, antes de os valores renderizarem).
- Com os slots empilhados, a janela vazia deixou de existir: a altura fica
  estável (`quedas: []`) e a troca de filtro com a página rolada não gera
  quedas nem saltos de scroll (`min = max = 2819`).

## 6. Ajustes do esqueleto da tabela do ranking

- Busca alinhada à direita (`margin-left: auto`), na mesma posição do
  `.rt-search` real (`x1287 w170`).
- Cabeçalho com uma barra por coluna, na largura e no alinhamento dos
  rótulos reais (Pos. e Valor à direita), com 7 px de altura.
- Paginação com a sequência real: Anterior, botões de página unificados,
  reticências, última página e Próxima — quebrando linha no mobile como o
  reactable (o "Próxima" desce para a segunda linha, à esquerda).
- Barra do resumo (`onde-ranking_resumo`) passou de `0.65em` para `0.85em`.

## 7. Testes e validação

- `devtools::test()`: **172 asserções verdes**, incluindo a estrutura dos
  esqueletos e do slot.
- Geometria real × esqueleto com delta 0 em 1600×900 (com e sem comparação)
  e em 390×844: mapa 540/490, ranking 476/506, palco 610/609, evolução
  357/354; altura da página idêntica antes/durante/depois da carga.
- Ciclo CSS verificado nas trocas de ano, medida, escopo e comparação:
  nenhum esqueleto aparece depois de `pagina-carregada` (`maxEsq = 0`) e
  nenhum fica preso.
- `prefers-reduced-motion`: o shimmer permanece ativo, como no hospitalar.

## 8. Limitações

- O esqueleto da tabela reserva sempre as 12 linhas da página padrão, mesmo
  quando o escopo tem menos municípios (só o DF tem 1 linha).
- Elementos recriados depois da carga (gráfico de evolução na troca de
  município) ficam com o espaço reservado vazio por ~80 ms, sem esqueleto,
  por decisão de exibi-los apenas no carregamento inicial.
- O esqueleto do palco reserva a altura cheia; em anos sem dado (Borá/2023)
  o palco vira estado vazio depois da carga inicial, como antes.

---

# Sessão 9 — Rodapé institucional com logos negativos (13/09/2026)

- **Pacote:** `painel_ibisma`.
- **Objetivo:** refazer o rodapé de realizadores e financiadores, que estava
  com "cara de adesivos" (cada logo dentro de uma caixa branca), aproximando-o
  da referência institucional: logos negativos direto no fundo azul, títulos
  sem linha e nota final com separador de largura total.

## 1. Da plaquinha branca ao logo negativo

- A primeira tentativa manteve os logos coloridos em caixas brancas de
  tamanho fixo (`7rem × 2,875rem`, `object-fit: contain`): o ritmo melhorou,
  mas o efeito de adesivos colados permaneceu e não correspondia à
  referência.
- Com as versões negativas enviadas pelo usuário, o rodapé passou a exibir
  os logos brancos direto sobre o `#0A1E3C`, sem fundo, borda ou padding.
- Ficaram de fora, por enquanto, os logos do Ministério da Saúde e da
  Medicina USP (sem versão negativa); os arquivos continuam na pasta.
- Os blocos ganharam a divisória vertical de referência (borda esquerda no
  segundo bloco), removida quando eles empilham (≤ 992 px).

## 2. Títulos, separador e nota

- As linhas sob "Realização" e "Financiamento" foram removidas; os títulos
  ficaram apenas com o texto em caixa-alta espaçada.
- A linha acima da nota deixou de pertencer ao parágrafo: o contêiner
  `rodape-base` cobre toda a largura útil do `painel-container` (a mesma das
  logos), com o texto limitado a `70rem` dentro dele.
- A primeira frase da nota passou a "Este painel está em desenvolvimento.",
  mantendo o aviso de que o IBISMA é um índice relativo.
- Os `img` do rodapé ganharam `loading="lazy"` e `decoding="async"`.

## 3. Otimização dos arquivos de logo

- Novo `data-raw/otimiza_logos.R`, executável na raiz do pacote: recorta a
  moldura transparente, aplica margem uniforme de 8 px e reduz cada PNG das
  pastas de realização e financiadores para no máximo 480×200 px.
- O script detecta logos negativos que vierem com o desenho escuro e os
  converte para branco (`image_colorize`), preservando o recorte — foi o
  caso do primeiro arquivo da Fiocruz, depois substituído pela versão
  vertical correta.
- O rodapé caiu de ~1,4 MB para ~170 KB de PNG no total, sem perda visível
  nas alturas exibidas (36 px no desktop e 28 px no mobile).
- Os recursos legados de `inst/app/www/logos/global/` (CSS e JS antigos, já
  fora do carregamento desde a primeira sessão) foram removidos.

## 4. Testes e validação

- `devtools::test()`: **172 asserções verdes**.
- Smoke headless em 1600×900 e 390×844: rodapé sem estouro horizontal, com a
  divisória sumindo no empilhamento, títulos sem borda inferior e a linha da
  nota com a largura do container (1376 px e 358 px).
- Evidências em `dev/smoke/rodape/` (ignorado pelo git).

---

# Sessão 10 — Seletores refinados e fendas da malha do mapa (13/09/2026)

- **Pacote:** `painel_ibisma`.
- **Objetivo:** refinar o comportamento e o visual dos seletores slimSelect e
  eliminar os espaços em branco do mapa, causados por fendas internas da malha
  municipal.

## 1. Seletores slimSelect

- `seletor_inline()` ganhou o argumento `busca`: medida e nível (poucas opções)
  passam a abrir sem campo de busca; ano e escopo continuam com busca. Os
  textos do plugin foram traduzidos (`searchText = "Nenhum resultado"`) e o
  realce do trecho encontrado foi ligado (`searchHighlight = TRUE`).
- `atualizar_seletor()` remove nomes do valor com `unname()`, evitando que o
  vetor nomeado viaje na mensagem JSON.
- O dropdown virou um cartão próprio: raio de 14 px, duas camadas de sombra,
  entrada animada com `opacity` + `visibility` + `pointer-events` (sem caixa
  invisível clicável), busca integrada com lupa desenhada por máscara SVG e
  botão de limpar no mesmo traço, lista com opções arredondadas, seleção em
  azul médio cheio, realce do trecho buscado em amarelo suave e fichas em
  pílula para a seleção múltipla.
- O posicionamento do dropdown foi reescrito no JavaScript: a posição do
  plugin não é mais sobrescrita (o `translate` faz o ajuste), com margem de
  10 px e respiro de 6 px (invertido quando abre acima), centralização quando
  o cartão é maior que a janela e reavaliação em `resize`, após digitar na
  busca e a cada mutação relevante (agendada por `requestAnimationFrame`).

## 2. Mensagem de atualização do mapa

- `atualizar_municipios()` passou a enviar `cores` e `labels` como **listas
  nomeadas** (`as.list(setNames(...))`), no lugar de vetores nomeados — o
  `jsonlite` emitia aviso ao serializar. Um teste captura a mensagem em uma
  sessão simulada e confirma que o `toJSON` do Shiny não gera aviso.

## 3. Diagnóstico das fendas

- O mapa abria "buracos" brancos entre municípios porque a malha era
  simplificada **polígono a polígono** (`st_simplify(dTolerance = 2000)`, em
  metros por causa do CRS geodésico). A mesma divisa era simplificada de
  formas diferentes dos dois lados: onde ambos recuavam abria fenda; onde
  ambos avançavam, sobreposição.
- Medições na malha antiga: **15.901 fendas**, **144.494 km² (1,70% do
  território)**, maior fenda de 713 km², além de 67.482 km² de sobreposições.
- Concentração por UF (% da área do estado em fendas): PB 5,41%, SP 4,77%,
  SC 4,57%, PR 3,80%, SE 3,61%, AL 3,43%, RS 3,34%, RN 3,22%, MG 3,03%,
  RJ 2,89% — contra 0,37% no AM: onde os municípios são pequenos, a tolerância
  de 2 km consome uma fração muito maior da área.
- `st_simplify(preserveTopology = TRUE)` foi testado e **não resolveu**: ele
  preserva a topologia dentro de cada polígono, não entre vizinhos
  (resultado idêntico).
- No zoom afastado, dois fatores agravavam o esbranquiçado: o traço branco de
  0,25 px sobre 5.570 polígonos minúsculos e o `fillOpacity = 0.88`, que
  deixava o fundo claro atravessar as cores.

## 4. Malha regenerada com topologia compartilhada

- `data-raw/prepara_malha.R` passou a usar `rmapshaper::ms_simplify(keep =
  0.01, keep_shapes = TRUE)`: cada divisa é simplificada **uma única vez** e
  reaproveitada pelos dois municípios vizinhos, sem abrir fendas. As colunas
  (`codmunres`, `sigla_uf`, `geometry`) e a conversão para EPSG:4326 foram
  mantidas; a malha de UFs (apenas contornos) não mudou.
- Resultado: 5.570 municípios, cobertura de 100% dos códigos da base,
  **8.283 fendas / 8.201 km² (0,10% do território)** e maior fenda de
  60,5 km² — melhora de ~18× na área total. Custo: 383 mil pontos e RDS de
  1,50 MB (antes: 190 mil pontos e 1,04 MB), com primeiro carregamento um
  pouco maior.
- O script exige o `rmapshaper` (V8; a instalação pode atualizar o `Rcpp`
  para >= 1.1.0). A geração foi feita com o V8 já instalado.

## 5. Estilo dos municípios

- Primeiro o traço passou a usar a **própria cor do município**
  (`color = ~cor`, `weight = 0.5`), para fechar as fendas residuais sem o
  esbranquiçado do traço branco. Na revisão, a preferência foi por manter as
  divisas municipais visíveis: o **traço branco fino voltou**, bem leve
  (`color = "#FFFFFF"`, `weight = 0.25`, `opacity = 0.65`), agora sem as fendas
  que causavam os espaços brancos originais.
- `fillOpacity` subiu de 0,88 para 0,95 e o `smoothFactor` caiu de 1 para 0
  (a malha já chega simplificada; o cliente não simplifica de novo).
- O handler JavaScript da mensagem repinta apenas `fillColor` e
  `fillOpacity`, já que a divisa branca é fixa.
- Os contornos brancos das UFs continuam por cima, suavizados para
  `weight = 0.8` e `opacity = 0.85`, garantindo a leitura política do mapa.
- O realce de hover e o contorno de seleção (ambos em azul escuro) também
  ficaram mais leves: `weight = 1.6 → 1.2` no hover (`fct_mapa.R:192`) e
  `weight = 2.4 → 1.8` no selecionado (`mod_onde.R:184`), preservando a
  hierarquia base < hover < selecionado.

## 6. Testes e validação

- `devtools::test()`: **182 asserções verdes** (incluindo os testes novos de
  `seletor_inline` e da serialização da mensagem do mapa). A suíte rodou com
  `rlang` 1.2.0 de uma biblioteca temporária, porque o `rlang` 1.1.4 instalado
  está abaixo do exigido pelo testthat.
- Smoke headless em 1600×950: zoom-out inicial com as cores saturadas e sem o
  pontilhado branco no NE/SE/S; zoom-in no Nordeste (zoom 8) sem fendas
  internas — os contornos visíveis são os das UFs.
- Evidências em `dev/smoke/` (ignorado pelo git).

## 7. Limitações

- Restam 8.283 fendas de 8.201 km² no total (0,10% do território); a maior
  (60,5 km²) só aparece em zoom muito aproximado.
- O RDS da malha cresceu ~45% (1,04 MB → 1,50 MB), o que deixa o primeiro
  carregamento do mapa um pouco mais lento.

---

# Sessão 11 — Evolução temporal: hierarquia, eixo Y e nitidez (14/09/2026)

- **Pacote:** `painel_ibisma`.
- **Objetivo:** fazer o IBISMA se destacar no gráfico de evolução temporal,
  adaptar o eixo Y à faixa dos dados (compartilhado na comparação) e corrigir
  o borrão dos gráficos ECharts em telas com escala fracionária ou sob zoom.

## 1. Hierarquia visual do IBISMA

- O IBISMA passou a ser desenhado **por cima** dos blocos (`z = 10`) — antes
  era a primeira série e os blocos ficavam sobre ele —, com linha de 3,5 px e
  bolinha de 8. Os blocos ficaram com 1,8 px, símbolo 5 e opacidade 0,7.
- Ao passar o mouse, a série focada volta à opacidade 1 (`emphasis` com
  `lineStyle`/`itemStyle`), preservando o `focus = "series"` que apaga as
  demais linhas.
- `grafico_legenda()` alinhou as larguras ao gráfico (3,5 no IBISMA, 1,5 nos
  blocos).

## 2. Bolinha apenas no IBISMA

- A série do índice mantém o ponto de cada ano sempre visível; nos blocos o
  ponto só aparece no hover (`showSymbol` condicional em `grafico_evolucao()`),
  o que limpa o desenho sem perder a leitura da tooltip.
- A legenda nativa continua exibindo o ícone com bolinha em todos os itens: o
  ECharts desenha o ícone da legenda por conta própria e ignora
  `symbol`/`showSymbol` da série (tentativa com `symbol = "none"` revertida).
  Alinhar a legenda exigiria `legend.data` com `icon` por item.

## 3. Eixo Y adaptativo

- Nova `piso_eixo_y()`: arredonda o menor valor das sete séries para **baixo
  na dezena** (limite entre 0 e 90, para não degenerar quando tudo é 100).
- `grafico_evolucao()` ganhou o argumento `minimo_y`; sem ele, o piso vem das
  próprias séries. Jutaí/AM, por exemplo, passou a exibir o eixo 70–100 em vez
  de 0–100, aproveitando a área do gráfico.

## 4. Eixo Y compartilhado na comparação

- O reativo `piso_y` do módulo Como? calcula o **menor piso entre principal e
  comparado** e o repassa aos dois gráficos; séries sem dado são ignoradas
  (com o principal vazio, o eixo segue apenas o comparado; sem valor algum,
  volta a 0).
- Validação: Jutaí × Inhapi/AL resultou em `50|50` nos dois gráficos; ao
  remover a comparação, o eixo volta ao piso do principal.

## 5. Nitidez dos gráficos (renderizador SVG)

- **Causa:** no ECharts 6.0.0 embutido, `painter.dpr` é definido apenas na
  construção do gráfico e nunca recalculado — nem no `resize()` — de modo que
  qualquer mudança de DPR (zoom do navegador, janela movida para um monitor com
  escala diferente) deixa o canvas na resolução antiga. O htmlwidgets 1.6.4
  também não observa mudanças de tamanho do contêiner (sem `ResizeObserver`).
  Além disso, o canvas é naturalmente mais macio em escalas fracionárias
  (125%/150%), comuns no Windows.
- **Correção:** os três widgets ECharts (gráficos principal/comparado e legenda
  compartilhada) passaram a usar `renderer = "svg"`, que independe de
  `devicePixelRatio` e permanece nítido sob zoom ou escala fracionária.
- A legenda compartilhada continua sincronizando os dois gráficos com SVG
  (clique em "Social" esconde a série em ambos).

## 6. Smoke test

- `dev/headless_smoke.R` ganhou `--dpr=<número>`, que emula a escala de tela
  via `Emulation.setDeviceMetricsOverride` para checagens de nitidez.
- Evidências: `dev/smoke/evolucao_eixo/` (hierarquia e eixos iguais),
  `dev/smoke/dpr/` (SVG nítido em 1,25 e 1,5) e `dev/smoke/simbolos/`
  (bolinha apenas no IBISMA), todas ignoradas pelo git.

## 7. Testes

- `devtools::test()`: **203 asserções verdes**, cobrindo `piso_eixo_y`, o eixo
  compartilhado entre os dois gráficos (via `testServer`, com o JSON do widget
  decodificado por `jsonlite`), a hierarquia das séries, o símbolo condicional
  e o renderizador SVG.
- `jsonlite` entrou em `Suggests` apenas para os testes; a suíte rodou com
  `rlang` 1.2.0 de uma biblioteca temporária (o 1.1.4 instalado está abaixo do
  exigido pelo testthat).

## 8. Limitações

- Os ícones da legenda seguem com bolinha em todos os itens (ver seção 2).
- O piso do eixo é calculado com as sete séries; esconder uma série pela
  legenda não recalcula o eixo (por desenho, para não re-renderizar a cada
  clique).
- O eixo adaptativo não começa em 0; o recorte fica visível apenas nos rótulos
  do próprio eixo (a frase que explicava o ajuste foi retirada da descrição).

---

# Sessão 12 — Evolução temporal em pequenos múltiplos (14/09/2026)

- **Pacote:** `painel_ibisma`.
- **Objetivo:** reformular a visualização "Evolução ao longo do tempo" — que
  concentrava IBISMA e seis blocos em um único gráfico por município — em uma
  grade com um gráfico para o índice e seis para os blocos, com identificação
  direta das localidades e comparação dentro de cada gráfico.

## 1. Estrutura

- A seção passou a ter um cartão de largura total para o **IBISMA** e o título
  intermediário **"Blocos do IBISMA"** (mantendo a linguagem de "blocos" usada
  pelas pétalas e pelos seletores) sobre seis cartões em pequenos múltiplos.
- A grade usa CSS Grid: 3 colunas em telas largas (3 × 2), 2 colunas até
  1100 px (alinhado ao breakpoint da comparação de palcos) e 1 coluna até
  768 px. O cartão do IBISMA ocupa a largura toda em qualquer largura.
- Alturas fixas: 270 px para o IBISMA e 160 px para os blocos, evitando que os
  cartões fiquem estreitos demais sem depender de recálculo de tamanho.
- `grade_evolucao_ui()` (em `fct_graficos.R`) monta os sete cartões; o servidor
  registra os sete outputs em um laço sobre `MEDIDAS`, sem repetição de código.
- O grid do ECharts usa `left = 28` (sem `containLabel`), de modo que os
  números do eixo Y começam junto da borda esquerda do cartão, alinhados ao
  título (medido em 3,6 px de folga).
- O esqueleto da seção (`esqueleto_grade_evolucao()`) reproduz a mesma grade e
  as mesmas alturas, com a coluna de 28 px dos números do eixo Y
  (`.esqueleto__grafico` em grid): `esqueleto_grafico_margem()` desenha barras
  claras e de tamanho único (16 × 4 px, início em 4 px, como o "100" real em
  3,6 px) na posição exata em que os números aparecem, e
  `esqueleto_grafico_svg(altura)` traça a grade e os
  traços nas margens do ECharts (topo 16 px, base `altura - 28 px`), sem a
  linha vertical de eixo Y que o gráfico real não tem.

## 2. Uma medida por gráfico, até duas localidades

- `grafico_evolucao()` passou a desenhar **uma única medida** ("indice_final"
  ou um bloco) com uma ou duas séries: principal (linha cheia) e comparada
  (linha **pontilhada**, mesma cor e opacidade 0,55, desenhada abaixo).
- Os pisos do eixo Y passaram a ser calculados por grupo com
  `piso_eixo_y(series, medidas)`: o IBISMA usa o piso da própria série e os
  seis blocos **compartilham** o piso da menor série de bloco entre os dois
  municípios, para os cartões serem comparáveis entre si. O topo segue em 100.
- A legenda foi eliminada: cada série leva o nome da localidade no fim da
  linha (`endLabel` nativo do ECharts, formatter `{a}`), com `align: "right"` e
  halo branco (`textBorderColor`) para leitura sobre as linhas.
- `lados_rotulos()` decide o lado e o afastamento de cada nome: acima por
  padrão, abaixo perto do topo do eixo, e em lados opostos (ou com
  afastamentos diferentes) quando os dois fins estão próximos — evitando
  rótulos sobrepostos sem truncar nomes, inclusive nos mais longos da base
  ("Vila Bela da Santíssima Trindade (MT)", 178 px).
- A legenda nativa não é mais usada em lugar nenhum da seção: saíram o widget
  compartilhado (`grafico_legenda()`), o `estilo_echarts()` e o sincronismo de
  grupo do ECharts; o `e_legend(show = FALSE)` é explícito porque o echarts4r
  cria uma legenda padrão quando as séries têm nome.
- O hover não apaga a série vizinha: nenhuma das linhas usa `focus` no
  `emphasis`, então as duas permanecem visíveis enquanto o mouse está sobre o
  gráfico; a comparação mantém o traço pontilhado mais claro mesmo sob o
  cursor. O retorno visual do hover fica com o realce padrão do ECharts e com
  a tooltip.
- Hierarquia dos títulos dentro dos cartões: "IBISMA" em
  `--fonte-muito-grande-size` e os seis blocos em `--fonte-grande-size`
  (`.evolucao-card--ibisma .evolucao-card__titulo`).

## 3. Tooltip

- Trigger por eixo, uma tooltip por gráfico (a sincronização entre gráficos
  deixou de existir porque as duas localidades convivem no mesmo gráfico).
- Cabeçalho apenas com o ano (`2024`); cada linha traz o nome da localidade à
  esquerda e o valor à direita (`display:flex; align-items:center;
  justify-content:space-between`) e uma marca própria no lugar do `p.marker`:
  um traço curto na cor do bloco com um ponto pequeno no centro, contínuo na
  série principal e pontilhado na comparação; na comparação a cor é clareada em
  direção ao branco (mistura opaca de 55%, e não rgba) para o pontilhado não
  aparecer dentro da bolinha. A cor identifica a dimensão e o tipo de traço
  identifica a localidade.

## 4. Módulo e JavaScript

- `mod_como.R` perdeu a dupla de colunas da evolução e a legenda inferior; a
  seção virou um único slot (`uiOutput(ns("evolucoes"))`) que mostra a grade ou
  um estado vazio quando não há série temporal.
- O piso compartilhado `piso_y` foi substituído por `piso_ibisma` e
  `piso_blocos`; a comparação é desenhada apenas quando o comparado tem série.
- O handler `ibisma_comparacao` deixou de tratar a antiga coluna de evolução e
  de disparar `resize` (os gráficos da grade não mudam de largura com a
  comparação); continua aplicando `dupla--comparando` nos palcos.

## 5. Testes e validação

- `devtools::test()`: **222 asserções verdes** — testes reescritos de
  `grafico_evolucao` (uma medida, cores, traço pontilhado, rótulos, tooltip e
  ausência de `focus` no hover), `lados_rotulos` (separação dos rótulos e
  bordas do eixo), `piso_eixo_y` por grupo, pisos por grupo no `testServer` e
  esqueleto da grade com sete cartões, coluna de margem e 28 barras de número.
- Smoke headless em 1600, 1024 e 390 px, com e sem comparação, hover real
  (tooltip `Social — 2019 / Jutaí (AM) 99,7`), alternância liga/desliga da
  comparação (2 → 1 séries), cenário Borá/2023 (lacuna no ano ausente), nome
  longo (rótulos dentro dos cartões), palcos ainda lado a lado na comparação e
  esqueleto da grade com a mesma geometria final (936 px). Sem erros de
  JavaScript e sem estouro horizontal.
- Alinhamento e esqueleto conferidos por medição: número real em 3,6 px e
  grade em 28/16/`altura - 28`; esqueleto com barras de 16 × 4 px em 4,0 px,
  grade idêntica e sem a linha vertical que o gráfico não tem.
- Evidências nas pastas da sessão de evolução (ignoradas pelo git): as
  primeiras registram as alturas menores e o novo tooltip; as seguintes, o
  alinhamento do eixo e as barras uniformes do esqueleto.

---

# Sessão 13 — Ranking por medida e identificação da evolução (14/09/2026)

- **Pacote:** `painel_ibisma`.
- **Objetivo:** adaptar o ranking à medida exibida (cores, buscas, seleção e
  cabeçalho) e identificar os municípios e o período no card de evolução,
  com esqueleto e bolinhas de dimensão nos títulos.

## 1. Cores do ranking por medida e prefixo "Bloco"

- `tema_reactable(medida)` deriva hover, linha selecionada, barra lateral e
  botões de página da cor da medida (`cor_medida()`); o botão ativo usa
  `cor_texto_sobre()` para contraste (ex.: amarelo do Social pede texto
  azul escuro). Para o IBISMA, os valores são idênticos aos anteriores.
- `nome_medida(medida, prefixo_bloco = TRUE)` prefixa os blocos: o resumo do
  ranking virou "5.570 municípios do Brasil em 2024 · Bloco Planejamento
  Reprodutivo", mantendo "· IBISMA" para o índice.
- **Achado:** como a coluna Pos. é `sticky`, as linhas usam a classe
  `rt-tr-highlight-sticky` e o `highlightColor` do tema nunca casava (o
  hover ficava no cinza padrão). O tema agora expõe `--cor-hover-ranking` e
  `--cor-selecao-ranking`, consumidas por duas regras em `custom.css`
  (hover e seleção sob o mouse).

## 2. Buscas insensíveis a acentos e sinais

- A busca do ranking (`busca_sem_acento`) normaliza em NFD, remove
  diacríticos e sinais não alfanuméricos e ignora caixa: "olho d agua"
  encontra os sete municípios "Olho d'Água".
- As buscas dos slimSelect (que só ignoravam caixa) ganharam o mesmo
  filtro via `funcoes_javascript.js` (`events.searchFilter` normalizado),
  com nova tentativa por até 5 s até o Shiny criar as instâncias e reforço
  no `load`. Validado com "sao" → "São Paulo (SP)" e "olho d agua" →
  resultados "Olho-d'Água"/"Olho D'Água".

## 3. Visual da busca da tabela

- `searchInputStyle` saiu do tema; o campo `.rt-search` passou a repetir a
  busca dos dropdowns (fundo suave, borda transparente e raio 10 px, altura
  2.4 rem, lupa por SVG com cor própria no foco, anel azul no foco).
- Esqueleto da busca ajustado à nova geometria (196 × 38 no desktop,
  173 × 38 até 768 px), sem estouro horizontal no mobile (390/390).
- Medição: campo da tabela e campo do dropdown com 196×38, mesmo raio,
  fonte, padding e estado de foco; digitação continua filtrando.

## 4. Seleção e página do ranking sincronizadas

- A tabela já nasce com o município padrão selecionado: `defaultSelected`
  no `renderReactable` marca a linha na própria montagem.
- Na troca de dimensão/escopo, o foco é mantido se o município segue no
  ranking e reseta para o 1º colocado quando sai dele
  (`observeEvent(list(input$medida, input$escopo))`). Trocas de fora da
  tabela (mapa, seletor do perfil) usam `updateReactable(selected=...)`.
- O salto de página reage ao eco da seleção publicado pelo cliente
  (`updateReactable(page=...)` apenas), que chega depois da montagem do
  widget — elimina a corrida em que um índice de outro contexto era
  aplicado à tabela recém-renderizada (observada como seleção errada em
  trocas rápidas medida→escopo).
- Ao limpar a busca, o servidor reposiciona a tabela na página do
  município em foco (o reset nativo do reactable voltava à página 1).

## 5. Cabeçalho do ranking

- Havia um `<p></p>` vazio abaixo do resumo por HTML inválido (o `div` do
  slot do esqueleto dentro do `<p>` faz o navegador fechar o parágrafo).
  O resumo ficou no próprio slot e a dica virou parágrafo próprio.
- A pedido, a dica saiu do cabeçalho para logo acima da tabela, com a
  classe `bloco-descricao` e margem própria
  (`.bloco-descricao--tabela { margin-bottom: 0.6rem }`, folga medida de
  10 px). O resumo segue sem a classe.

## 6. Identificação da evolução, esqueleto e bolinhas

- Novo `uiOutput("evolucao_identificacao")` no cabeçalho do card:
  `Jutaí (AM) | 2015 – 2024`, e na comparação
  `Jutaí (AM) e Inhapi (AL) | 2015 – 2024` (só quando o comparado tem
  série; some quando o principal não tem série, como o restante da grade).
  Nomes em `--fonte-muito-grande-size`/700 e separador em
  `var(--cor-texto-suave)`.
- Esqueleto dedicado (`esqueleto_identificacao()` + slot): a primeira
  versão centralizava a barra e ela ficava ~4 px acima do texto; a correção
  alinha com a margem do parágrafo (topo 9 px nos dois estados).
- Títulos dos sete cartões ganharam bolinha (`evolucao-card__ponto`,
  0.5 em) na cor da dimensão via `cor_medida()`.

## 7. Testes e validação

- `devtools::test()`: **263 asserções verdes** — `nome_medida` com
  prefixo, tema por medida e variáveis CSS, seleção inicial/`defaultSelected`,
  manter/resetar foco, salto de página, dica do cabeçalho, identificação da
  evolução, esqueleto e bolinhas. (A suíte rodou com `rlang` 1.3.0 de
  biblioteca temporária, pois o 1.1.4 instalado fica abaixo do exigido pelo
  testthat.)
- Smoke headless (evidências nos temporários, fora do git): resumo com
  "Bloco", hover/seleção/página nas cores do bloco (bloco2 verde, Social
  amarelo, IBISMA roxo inalterado), manter Jutaí (rank 22/página 2 →
  rank 6/página 1 no AM), reset para Campos Novos Paulista em SP,
  clique na linha sincronizando o perfil, buscas sem acento/sinais e
  geometria de esqueletos/desktop/mobile.

## 8. Commits da sessão

- `9af4b33` Refina o ranking: cores por medida, buscas, seleção e cabeçalho
- `882fcb6` Identifica os municípios e o período na evolução
- `c149286` Marca os títulos da evolução com a cor da dimensão

---

# Sessão 14 — Teto adaptativo do eixo Y, rótulos de ano no mobile e placar (14/09/2026)

- **Pacote:** `painel_ibisma`.
- **Objetivo:** tornar o teto do eixo Y adaptativo (espelhando o piso), dar
  respiro aos anos do eixo X no mobile com rótulos inclinados e colocar os
  rankings do placar lado a lado em telas pequenas.

## 1. Teto adaptativo do eixo Y

- Nova `teto_eixo_y(series, medidas)`: arredonda o maior valor das séries para
  **cima na dezena** e limita a faixa em `[10, 100]` (o 10 evita eixo degenerado
  quando tudo é zero; 100 é o teto do índice). Série sem valor algum devolve 100.
- `grafico_evolucao()` ganhou `maximo_y` e o repassa ao `e_y_axis`; quando NULL,
  o teto vem das próprias séries. Se piso e teto caírem na mesma dezena, o teto
  sobe 10 (até 100) para o eixo não degenerar.
- `lados_rotulos()` passou a receber piso e teto e calcula a posição relativa dos
  nomes no fim das linhas com a faixa real (`maximo_y - minimo_y`), o que também
  ajusta o corte de "perto do topo" quando o teto encolhe.
- `mod_como.R`: `piso_do_grupo()` virou `limites_do_grupo()` e devolve
  `list(min, max)`. Na comparação a faixa é **aberta ao máximo** (menor piso e
  maior teto entre principal e comparado) para nenhuma das séries ser cortada.
  O IBISMA mantém escala própria e os seis blocos seguem compartilhando uma
  única escala, agora com piso e teto iguais.
- Efeito nos testes: Dois (RO) passou a ter eixo 80–90 no índice (antes 80–100)
  e, na comparação com Quatro (SP), 10–90 no índice e 20–100 nos blocos.
- O piso máximo foi avaliado (90 → 95), mas ficou **mantido em 90**: a mudança
  literal só afetaria o caso de menor valor igual a 100 (um município em 2022).

## 2. Rótulos de ano no mobile

- A primeira tentativa foi mostrar os anos de dois em dois (`interval = 2`) via
  hook no cliente; a preferência passou a ser manter todos os anos visíveis com
  inclinação de 45°.
- Novo `rotulos_anos_js()`, aplicado com `htmlwidgets::onRender()` no fim de
  `grafico_evolucao()`: em cartões com largura < 340 px
  (`LARGURA_ROTULOS_ANOS`), inclina os rótulos em 45° e sobe a margem inferior
  do ECharts de 28 para 40 px; acima disso, tudo segue horizontal. O ajuste roda
  no cliente, reage a `resize` com um listener único por elemento
  (`data-rotulos-anos`) e não passa pelo servidor.
- Medições: cartões de bloco com 395 px no desktop e 276–310 px no mobile, o
  que separa bem o limiar; a 1024 px os cartões seguem horizontais.
- Limitação: o esqueleto da grade reserva a margem inferior de 28 px, então no
  mobile há um ajuste de ~12 px na troca esqueleto → gráfico, visível só no
  carregamento inicial.

## 3. Placar em duas colunas no mobile

- No `@media (max-width: 768px)`, o `.perfil-placar` passou de três linhas
  empilhadas para duas colunas: o índice ocupa a primeira linha inteira e
  "Ranking Brasil" e "Ranking na UF" ficam lado a lado abaixo, mantendo o
  alinhamento do desktop (Brasil à esquerda, UF à direita). A regra que forçava
  os dois rankings à esquerda no empilhamento foi removida.

## 4. Testes e validação

- `devtools::test()`: **281 asserções verdes** — novos testes de `teto_eixo_y`
  (arredondamento para cima, limites, série vazia), dos limites por grupo no
  `testServer` (min e max), do caso degenerado e do hook de rotação.
- Smoke headless: mobile 390 px com os 10 anos rotacionados e sem corte;
  desktop 1600 px e 1024 px horizontais; placar mobile com os rankings lado a
  lado; sem erros de JavaScript.
- Evidências em `dev/smoke/` e em temporários fora do git.

## 5. Commits da sessão

- `fa7bfb0` Torna o teto do eixo Y adaptativo na evolucao temporal
- `53df2dd` Rotaciona os rotulos de ano no mobile
- `b74bba9` Coloca os rankings do placar lado a lado no mobile

---

# Sessão 15 — Otimização da inicialização (15/09/2026)

- **Pacote:** `painel_ibisma`.
- **Objetivo:** tirar do app as contas determinísticas (preparação da base,
  categorias, rankings e séries), consumir arquivos prontos em `inst/app/data/`,
  aliviar o payload da primeira carga do mapa e consertar a junção da malha.

## 1. Diagnóstico (medições na base real)

| Tratamento (antes) | Custo medido |
| --- | --- |
| `preparar_dados()` (55.699 → 389.893 linhas) | 0,48 s por processo |
| `tabela_ano()` (quintis, rank, ave) | 0,06 s por ano visitado |
| `merge()` da malha + reordenação | 0,39 s por sessão |
| `series_municipio()` (pivot) | 0,02 s por seleção |
| `nome_uf()` (unique em 55.699 linhas) | 0,03 s por render |
| Payload da primeira render | 7,51 MB (só a geometria, 9 casas) + 1,85 MB de tooltips |

## 2. Arquivos prontos em `inst/app/data/`

- `data-raw/calculos_painel.R` (novo): funções de cálculo (`preparar_dados`,
  `cortes_categorias`, `categorizar`, `calcular_tabela_ano`,
  `calcular_series_municipio`) que saíram de `R/fct_dados.R` e agora servem
  apenas à geração dos arquivos e aos testes.
- `data-raw/prepara_painel.R` (novo): gera `dados_ibisma.rds` (cadastro, anos e
  55.700 linhas de séries) e `tabela_ano_2015.rds` … `tabela_ano_2024.rds`.
- `R/fct_dados.R`: passou a só ler; `dados_ibisma()` guarda o arquivo na memória
  do processo, `tabela_ano()` lê um arquivo por ano (com erro claro se faltar) e
  `series_municipio()`, `opcoes_*()`, `nome_uf()` e `anos_disponiveis()` usam os
  campos prontos, sem tocar em `df_ibisma`.
- `tidyr` saiu de Imports (foi para Suggests), pois só o data-raw usa.

## 3. Junção da malha

- `malha_do_ano()` deixou o `merge()` + reordenação e passou a ligar cor e
  tooltip por `match()`: 0,39 s → ~0 ms.

## 4. Fase 2 — payload do mapa

- `desenhar_municipios()` não envia mais os tooltips na carga inicial; a mesma
  mensagem `ibisma_mapa_atualiza` (disparada quando o mapa fica pronto) liga os
  tooltips com `bindTooltip` quando a camada ainda não tem um.
- `data-raw/prepara_malha.R` passou a arredondar as coordenadas para 5 casas
  (cerca de 1 m, invisível no zoom máximo 10) e as malhas existentes foram
  arredondadas sem novo download: 1,50 → 0,94 MB (municípios) e 0,09 → 0,06 MB
  (UFs), sem geometrias inválidas.
- Payload do `addPolygons` comparado na mesma malha: 8,10 MB com tooltips vs
  6,25 MB sem tooltips; somando o arredondamento (7,51 → 6,15 MB só na
  geometria), a primeira carga cai de ~9,4 MB para 6,25 MB (−33%).

## 5. Testes e validação

- `devtools::test()`: **300 asserções verdes** (era 281), incluindo o novo teste
  que compara os arquivos prontos com o recálculo da base, ano a ano, e as
  séries (inclusive o município com ano faltante).
- Os testes que usam a base de brinquedo passaram a montar as tabelas numa pasta
  temporária com as funções de `data-raw/calculos_painel.R` (pulados quando o
  arquivo não está disponível, como no `R CMD check`, que ignora `data-raw`).
- Smoke headless: mapa com 5.570 tooltips ligados após a carga
  (`RESULTADO: 5570|5598`), sem erros de JavaScript; evidência em
  `dev/smoke/otimizacao.png`.
- `dev/bench_inicializacao.R` (novo) mede o roteiro de abertura a cada execução.
  Depois: `dados_ibisma()` 0,04 s, tabela anual 0,06 s, `malha_do_ano` 0,07 s,
  `series_municipio`/`opcoes_*`/`nome_uf` ~0 s.

## 6. Como regenerar os dados

```r
Rscript data-raw/cria_rda.R   # base bruta e arquivos prontos (ver Sessão 16)
```

> Nota de ambiente: a suíte rodou com `rlang` 1.3.0 de uma biblioteca
> temporária, pois o `rlang` 1.1.4 instalado está abaixo do exigido pelo
> testthat.

---

# Sessão 16 — Roteiro de dados unificado e legível no cria_rda.R (15/09/2026)

- **Pacote:** `painel_ibisma`.
- **Objetivo:** concentrar todo o roteiro de geração em um único arquivo
  linear, em R comum, que possa ser lido e rodado passo a passo por uma
  pessoa — sem funções empacotadas, atalhos nem carregamento do pacote.

## 1. Estrutura final de data-raw

```
data-raw/
├── cria_rda.R        roteiro linear, em seis etapas
└── databases/        CSVs de entrada
```

- `cria_rda.R` está em ordem de execução, com uma conferência impressa a cada
  etapa (cabeçalhos, contagens, duplicatas, amostras e faixas de valores):
  1. base bruta (`data/df_ibisma.rda`);
  2. constantes do índice (`medidas`, `categorias`, `cortes_percentis`);
  3. base longa (uma linha por município, ano e medida);
  4. tabelas por ano (`inst/app/data/tabela_ano_*.rds`);
  5. cadastro, anos e séries (`inst/app/data/dados_ibisma.rds`);
  6. malha geográfica, sob a chave `gerar_malha <- FALSE` (baixa do geobr e
     demora, então só roda quando a geografia muda).
- O script não depende do pacote carregado (sem `pkgload::load_all()`) e pode
  ser rodado com o botão Source do RStudio, `source()` ou Rscript.
- O roteiro passou a usar dplyr/tidyr direto (base longa, quintis e rankings
  em `mutate` por grupo), no lugar dos laços e funções auxiliares.

## 2. Testes reescritos

- Como o roteiro virou um script linear, os testes deixaram de carregá-lo e
  passaram a conferir os **arquivos gerados** contra a base bruta e a
  configuração do app:
  - as séries batem valor a valor com `df_ibisma` (100×), inclusive o ano
    faltante de Borá;
  - as tabelas usam as medidas e as categorias de `R/fct_config.R`;
  - as categorias conferem com os quintis do ano e os rankings nacional/UF
    conferem com `rank(-valor, ties.method = "min")`;
  - `resumo_municipio`, `series_municipio` e `municipio_padrao` conferidos com
    os dados reais;
  - os testes dos gráficos e eixos usam uma série pequena montada no próprio
    teste (antes vinha de uma base sintética).
- `R/fct_dados.R` e `AGENTS.md` apontam para o comando único do `cria_rda.R`.
- `pkgload` e `tidyr` saíram de Imports (foram para Suggests), já que só o
  roteiro de dados os usa.

## 3. Arquivos removidos

- `calculos_painel.R`, `prepara_painel.R` e `prepara_malha.R`: conteúdo
  absorvido pelo `cria_rda.R`.
- `otimiza_logos.R`: a otimização dos logos já está aplicada aos PNGs do
  repositório e não fazia parte da geração de dados.

## 4. Validação

- `source("data-raw/cria_rda.R")` sem o pacote carregado: 13 arquivos /
  4,72 MB, 55.700 linhas de séries, 38.990 linhas por ano (38.983 em 2023,
  sem Borá), sem avisos.
- `devtools::test()`: **363 asserções verdes**.
- Smoke headless: mapa com as 5.570 tooltips ligadas após a carga, sem erros
  de JavaScript.

## 5. Remoção do df_ibisma.rda

- O app não usava mais o dado de pacote e o roteiro nunca lia o `.rda` (só
  escrevia): saíram o `usethis::use_data()` do `cria_rda.R`, o arquivo
  `data/df_ibisma.rda` e o `LazyData: true` do DESCRIPTION.
- Os testes que usavam `df_ibisma` como referência passaram a ler direto o CSV
  `data-raw/databases/base_exemplo_ibisma.csv` (com `skip_if_not` para o
  `R CMD check`, que ignora `data-raw`).
- A única cópia da base bruta passa a ser o CSV em `data-raw/databases/`.

## 6. Commits da sessão

- `aaf1e2b` Pré-computa os dados do painel e remove a base bruta do pacote
- `ddda749` Alivia a primeira carga do mapa

---

# Sessão 17 — Refatoração para leitura: definições, componentes e paletas (15/09/2026)

- **Pacote:** `painel_ibisma`.
- **Objetivo:** facilitar a leitura do código do painel — ao abrir um módulo, saber de onde vem cada função auxiliar e
  onde ela é usada —, reduzindo os auxiliares com funções de um só dono.

## 1. Diagnóstico e princípio

- O mapa de definições × usos mostrou que `fct_mapa`, `fct_perfil`, `fct_petalas` e `fct_graficos` serviam a uma única
  seção, e que o `utils_ui` misturava componentes da casca, compartilhados e de um só módulo.
- Princípio adotado: cada arquivo é dono do que só ele usa; função usada por um único módulo mora nele (ou no auxiliar
  da sua seção); só sobe para arquivo compartilhado o que tem mais de um usuário.
- A refatoração foi feita por partes (`fct_config`, componentes da casca, `utils_ui`, paletas), com a suíte verde e
  smoke headless a cada etapa.

## 2. fct_config: fusão com o fct_cores e simplificações

- O `fct_cores.R` foi absorvido pelo `fct_config.R`, que passou a reunir o dicionário e as funções de cor.
- Ficou uma única função de rampa: `paleta_categorias()` e `paleta_mapa()` (apelidos) saíram.
- O cache `.paleta_cache` foi removido: `paleta_medida()` virou consulta pura.
- O prefixo "Bloco" ganhou um dono só: nova coluna `rotulo` no dicionário; `opcoes_medidas()` perdeu o parâmetro e a
  lógica, e `nome_medida()` virou consulta direta.
- Saíram os fallbacks silenciosos de `cor_medida()` e `nome_medida()`, a `PROBS_CORTES` (usada só em teste) e a
  `TEXTO_CATEGORIAS` (morta).

## 3. Cada componente no seu dono

- `NIVEIS_ANALISE` foi para o `mod_onde.R` e o `TEXTO_ESCALA` virou o próprio texto do cabeçalho da seção, sem variável.
- `tema_ibisma()`, `navbar_ibisma()` e `rodape_ibisma()` saíram do `utils_ui` para o `app_ui.R`, junto de seus textos;
  `TITULO_PAINEL` e `SUBTITULO_PAINEL` deixaram de existir como variáveis (texto direto no título, na meta e na navbar).
- O `utils_ui.R` ficou com os componentes das seções: `titulo_secao()`, `seletor_inline()`, `badge_categoria()`,
  `badge_categoria_html()` (ex-`montar_selos()`) e `estado_vazio()`.
- Saíram as indireções de uma linha: `atualizar_seletor()` virou `shinyWidgets::updateSlimSelect()` direto e
  `frase_controles()` virou `htmltools::tags$div(class = "controles-inline", ...)` nos três usos.
- `legenda_categorias()` foi para o `fct_mapa.R` e `metrica_hero()` para o `fct_perfil.R`, ao lado do palco.

## 4. Convenções de comentários (AGENTS.md)

- O `AGENTS.md` ganhou três regras, aplicadas ao longo do painel:
  1. comentário de função auxiliar começa com "Definindo uma função que...";
  2. funções de `fct_*.R` e `utils_ui.R` trazem a linha `Usada em: {arquivos e contextos}`;
  3. cada bloco de um módulo registra de quais arquivos auxiliares depende, no formato
     `## Obs.: este bloco usa funções auxiliares de {arquivos}.`
- Foram ajustadas 73 funções (começo do comentário), 70 linhas de uso e 12 blocos (5 no `mod_onde.R`, 5 no
  `mod_como.R` e 2 no `fct_perfil.R`).

## 5. Paletas construídas juntas

- As rampas das 7 medidas passaram a viver numa lista única, `PALETAS`, com os 5 tons nomeados pelas `CATEGORIAS`; a cor
  de identificação fica no tom central dos blocos e no tom mais alto do índice.
- A cor de identificação passou a ser derivada da rampa (`MEDIDAS$cor`); a `PALETA_IBISMA` foi absorvida por
  `PALETAS$indice_final`, e a `paleta_bloco()` e a `paleta_medida()` deixaram de existir.
- Os tons foram conferidos um a um contra a geração anterior: idênticos, sem mudança visual.
- A `cor_categoria()` concentrou a regra "categoria → tom, ausente → cinza": o `dados_mapa()` e o `tooltip_municipio()`
  passaram a usá-la (o tooltip recebe a medida em vez da paleta) e o `fct_mapa` deixou de carregar a rampa inteira.
- Sobraram quatro funções de cor, todas com uso real: `cor_medida()`, `cor_categoria()`, `cor_texto_sobre()` e
  `misturar_cores()` (tema do ranking).

## 6. Testes e validação

- `devtools::test()`: **363 asserções verdes** ao fim de cada etapa.
- Smoke headless: controles, selos do ranking, legenda, evolução e mapa com as 5.570 tooltips ligadas; a sincronização
  do seletor de município (com o `updateSlimSelect` direto) foi conferida clicando na 2ª linha do ranking.

## 7. Próximos passos

- Os demais arquivos auxiliares ainda têm funções usadas por um só módulo (`fct_dados`, `fct_esqueleto`, `fct_graficos`,
  `fct_mapa`, `fct_perfil` e `fct_petalas`); a continuidade da refatoração fica para a próxima sessão.
- Usos entre arquivos auxiliares (ex.: `fct_mapa` chamando funções do `fct_dados`) ainda não recebem observação de bloco.

## 8. Commits da sessão

- `a657e4e` Reorganiza os auxiliares e centraliza as definições de medidas e cores
- `e85e625` Documenta as convenções de comentários das funções auxiliares

---

# Sessão 18 — Refatoração do fct_dados (15/09/2026)

- **Pacote:** `painel_ibisma`.
- **Objetivo:** continuar a refatoração para leitura aplicada na Sessão 17, agora focada no
  `fct_dados`: explicar o papel de cada auxiliar, localizar seus usos e mover para cada dono o
  que tem um único consumidor.

## 1. Diagnóstico e princípio

- Levantando definições × usos: das 17 funções do `fct_dados`, 9 eram usadas por um único dono
  (módulo ou auxiliar de seção) e 8 eram compartilhadas.
- Princípio mantido (Sessão 17): cada arquivo é dono do que só ele usa; só sobe para arquivo
  compartilhado o que tem mais de um usuário. As funções foram ajustadas uma a uma, com a suíte
  verde entre as etapas.

## 2. O que mudou de lugar

- `resumo_municipio` virou função local do `mod_como_server`, logo antes do bloco de palcos que a
  consome; como `dados` está no escopo do server, a assinatura passou a `(codmunres, ano)`.
- `opcoes_municipios` foi inlinada na `mod_como_ui` (ordenação + `setNames` no próprio bloco).
- `opcoes_medidas`, `anos_disponiveis` e `opcoes_escopo_ranking` deixaram de existir: as montagens
  viraram três linhas diretas no bloco de controles do `mod_onde`.
- `frase_percentil` foi para o `fct_perfil.R`, ao lado do placar que a usa.
- `TEXTO_PETALAS` deixou de existir; o texto está inline no `petalas-caption` do `mod_como`.
- `NIVEIS_ANALISE` saiu do `mod_onde` para o `fct_config`, junto do dicionário (é configuração,
  não componente).

## 3. Constantes de geração com fonte única

- `CORTES_PERCENTIS` entrou no `fct_config` e o `data-raw/cria_rda.R` passou a ler `MEDIDAS`,
  `CATEGORIAS` e `CORTES_PERCENTIS` dali — o script não depende mais de cópias manuais.
- Leitura via `sys.source("R/fct_config.R", envir = config)`, em ambiente próprio, sem mexer no
  global e sem exigir o pacote carregado; as funções de cor exigem o caminho do `grDevices`
  (suprido no ambiente de leitura). O script continua linear e rodável passo a passo.
- Um teste novo confere que as medidas da config cobrem exatamente as colunas do CSV de entrada —
  o passo que garante o alinhamento entre config e geração.

## 4. Correção de rota no meio da sessão

- A geometria das pétalas (`ANGULOS_PETALAS`, `PETALAS_CX/CY/RAIO/COMPRIMENTO/VIEWBOX`) chegou a
  ser movida para o `fct_config` sem pedido explícito e foi **revertida** para o `fct_petalas.R`,
  com os demais ajustes da sessão mantidos. A lição fica como o princípio da Sessão 17: sem dois
  usuários reais, não sobe.

## 5. Testes reescritos

- Os testes que chamavam `resumo_municipio` diretamente passaram a exercitá-la pelo caminho
  público: renderizando o palco no `testServer` e conferindo, contra as tabelas anuais, valor,
  categoria, rankings, os seis blocos e o estado vazio (Borá/2023).
- O teste do palco comparado foi incluído e **pegou um bug real**: a chamada ainda passava `dados`
  como primeiro argumento depois de a função virar local do server. O caminho de comparação não
  tinha cobertura antes.
- O teste das opções passou a ler o JSON que o próprio `mod_onde_ui` serve ao slimSelect
  (Brasil + 27 UFs = 28 opções); `nome_uf` ganhou teste próprio depois de ter sido removida por
  engano num edit e restaurada.
- `dev/bench_inicializacao.R` foi ajustado para medir os blocos inline equivalentes.

## 6. Testes e validação

- `devtools::test()`: **374 asserções verdes** no estado final.
- `cria_rda.R` rodado de ponta a ponta em cópia isolada do repositório: 13 arquivos / 4,72 MB,
  55.700 linhas de séries, cobertura de 100% da malha.
- Smoke headless: `#onde-mapa` renderizou sem erros de JavaScript com o app completo.

## 7. Próximos passos

- Continuar a refatoração nos demais auxiliares (`fct_esqueleto`, `fct_graficos`, `fct_mapa`,
  `fct_perfil` e `fct_petalas`), aplicando a mesma régua de um dono por função.
- Decisão registrada: constantes globais **não** vão para RDA; permanecem no `fct_config`, com o
  `cria_rda` lendo de lá.

## 8. Commits da sessão

- `22e79ff` Centraliza as constantes da geração no fct_config
- `02b2d24` Leva o resumo do município para dentro do módulo Como
- `081158a` Remove os auxiliares de um só dono do fct_dados
- `9ef4126` Inlina as opções dos controles nos módulos
- `680be48` Atualiza o cabeçalho do fct_config

---

# Sessão 19 — `constantes.R` só com constantes (15/09/2026)

- **Pacote:** `painel_ibisma`.
- **Objetivo:** fechar a separação de responsabilidades do arquivo de configuração:
  ele deixa de ter funções auxiliares e passa a ser um repositório puro de constantes,
  com o uso de cada valor documentado no próprio comentário.

## 1. Renomeação e limpeza

- `R/fct_config.R` virou `R/constantes.R` (sem o prefixo `fct_`, reservado aos arquivos
  de funções auxiliares): dicionário (`MEDIDAS`, `BLOCOS`, `CATEGORIAS`), cores
  (`COR_*`, `PALETAS`), limiares (`CORTES_PERCENTIS`) e níveis (`NIVEIS_ANALISE`).
- As 4 funções de cor (`cor_medida`, `cor_categoria`, `cor_texto_sobre`,
  `misturar_cores`) foram para o novo `R/fct_cores.R`, que deriva tudo das constantes.
- `nome_medida` foi para o `R/fct_dados.R`, junto de `nome_municipio` e `nome_uf`
  (consulta de nomes de exibição é leitura do dicionário, não estilo).
- O `cria_rda.R` passou a ler `R/constantes.R`; o desvio de `grDevices` no
  ambiente de leitura deixou de ser necessário (só há valores agora).

## 2. Comentário de uso em cada constante

- Todas as constantes de `constantes.R` ganharam a linha de uso (arquivos/contextos
  que as consomem), no mesmo espírito do `Usada em:` das funções auxiliares.
- As cores que entram apenas na construção das rampas (`COR_AZUL_CLARO`,
  `COR_AZUL_MEDIO`, `COR_AMARELO`, `COR_VERDE`, `COR_CORAL`, `COR_TEAL`) foram
  agrupadas sob um comentário único, e `MEDIDAS$cor` (derivada) ganhou o seu.

## 3. Referências atualizadas

- `data-raw/cria_rda.R`, teste das medidas × CSV e os `## Obs.` de `mod_onde`
  passaram a citar `constantes`/`fct_cores`.
- O `manifest.json` do deploy mantém o caminho antigo até o próximo redeploy
  (é regenerado pelo processo de publicação).

## 4. Testes e validação

- `devtools::test()`: **374 asserções verdes**.
- `cria_rda.R` rodado de ponta a ponta em cópia isolada: 13 arquivos / 4,72 MB,
  cobertura de 100% da malha.
- Smoke headless: app completo com o mapa renderizado, sem erros de JavaScript.

## 5. Commits da sessão

- `b20fd58` Renomeia o fct_config para constantes e ajusta as referências
- `097eff5` Extrai as funções de cor para o fct_cores
- `e5dce67` Leva o nome_medida para o fct_dados

---

# Sessão 20 — Simplificação das constantes (15/09/2026)

- **Pacote:** `painel_ibisma`.
- **Objetivo:** deixar o `constantes.R` com o mínimo necessário — só os valores que têm
  mais de um usuário — e corrigir a duplicação do nível de análise que restou da sessão
  anterior.

## 1. Cores direto nas rampas

- `COR_AMARELO`, `COR_VERDE`, `COR_AZUL_MEDIO`, `COR_CORAL` e `COR_TEAL` deixaram de
  existir: cada hexadecimal entrou direto na posição correspondente de `PALETAS`.
- **Achado:** `COR_AZUL_CLARO` parecia ter o mesmo destino, mas é usada também no
  `app_ui.R` (tema bslib, `secondary`) — permaneceu como constante, com o comentário
  atualizado.

## 2. `MEDIDAS$cor` explícita

- A derivação por `vapply` (tom central dos blocos e topo do índice) saiu; a coluna
  `cor` passou a ser preenchida explicitamente na criação da `data.frame`, com os
  mesmos valores da geração anterior.

## 3. `CORTES_PERCENTIS` para o cria_rda

- A constante saiu do `constantes.R` e virou um objeto local do `cria_rda.R`
  (`cortes_percentis <- c(0.2, 0.4, 0.6, 0.8)`), já que só a geração usa. O
  `usar("CORTES_PERCENTIS")` foi removido: o script lê apenas `MEDIDAS` e `CATEGORIAS`.

## 4. `NIVEIS_ANALISE` centralizado (correção)

- A definição voltou para o `constantes.R`, numa seção própria de níveis de análise.
- A cópia que restava em `mod_onde.R` foi removida: como a carga do pacote segue a
  ordem alfabética dos arquivos, a versão do módulo sobrescrevia a central (o app
  funcionava, mas com duas fontes). O cabeçalho do módulo aponta para o novo dono.

## 5. Comentários de uso refinados

- A linha de uso de cada constante virou `## Usada em: ...` (um `#` a mais que o
  comentário de definição) e foi comprimida em uma linha por constante, para leitura
  direta ao lado do valor.

## 6. Testes e validação

- `devtools::test()`: **374 asserções verdes**.
- `cria_rda.R` rodado de ponta a ponta em cópia isolada: 13 arquivos / 4,72 MB,
  config lendo só `MEDIDAS` e `CATEGORIAS`, cobertura de 100% da malha.
- Smoke headless: app completo com o mapa renderizado, sem erros de JavaScript.

## 7. Commits da sessão

- `fe30862` Simplifica as constantes do painel
- `b1e6da9` Centraliza o NIVEIS_ANALISE no constantes

---

# Sessão 21 — Renomeação dos auxiliares e paleta de cores no CSS (16/09/2026)

- **Pacote:** `painel_ibisma`.
- **Objetivo:** alinhar os arquivos auxiliares à convenção `fct_*` do projeto e
  centralizar as cores do painel em variáveis no `custom.css`, sem mudança
  visual.

## 1. Renomeação dos arquivos auxiliares

- `R/utils_ui.R` → `R/fct_ui.R` e `R/fct_graficos.R` →
  `R/fct_graficos_evolucao.R`, com `git mv` (histórico preservado).
- O `fct_graficos_evolucao` teve o cabeçalho ajustado, já que o arquivo cobre
  apenas a evolução temporal (o leque de pétalas segue em `fct_petalas.R`).
- Referências atualizadas em `fct_cores.R`, `constantes.R`, `fct_dados.R`,
  `fct_perfil.R`, `mod_onde.R`, `mod_como.R` e no `AGENTS.md` (a convenção de
  comentários deixa de citar `utils_ui.R` à parte: todo auxiliar é `fct_*.R`).
- Ficaram intencionalmente sem tocar: o `manifest.json` (regenerado no
  redeploy), o log das sessões anteriores e o `dev/01_start.R`, cuja chamada
  `golem::use_utils_ui()` é a função de scaffolding do golem, não o arquivo do
  projeto.

## 2. Paleta de cores no custom.css

- O arquivo ganhou um bloco único **"Paleta de cores do painel"** (`:root`) com
  as cores de identificação, os tons neutros, os fundos e as cores dos
  esqueletos; mais de 100 usos de cor literais passaram a consumir variáveis.
- Padrão adotado: variável em hexadecimal para usos sólidos e variável `-rgb`
  com os canais para transparências, no formato `rgb(var(--cor-x-rgb) / alfa)`
  (ex.: `--cor-azul-escuro: #0A1E3C` e `--cor-azul-escuro-rgb: 10 30 60`).
- O `:root` próprio dos esqueletos foi absorvido pela paleta
  (`--cor-esqueleto-rgb/base/forte/guia/brilho` mais `cabecalho/linha/grade`) e
  os gradientes de brilho passaram a derivar dos mesmos canais.
- Exceções documentadas no bloco: as cores embutidas nos data URIs de máscara
  (lupa e X da busca) não aceitam `var()` e seguem literais; os fallbacks
  `#F2F2F2` e `#EDE8F1` do ranking continuam dentro do `var(--cor-*,
  fallback)`, porque são sobrescritos pelo R a cada medida.
- Os nomes não colidem com as variáveis injetadas pelo R (`--cor-medida`,
  `--cor-fundo`, `--cor-cat`, `--cor-hover-ranking` e `--cor-selecao-ranking`).

## 3. Testes e validação

- `devtools::test()`: **374 asserções verdes** (rodada com `rlang` 1.3.0 da
  biblioteca temporária, como nas sessões anteriores).
- Smoke headless: cores computadas idênticas às anteriores (navbar
  `rgb(10, 30, 60)`, mapa `rgb(237, 241, 247)`, blocos `rgb(250, 251, 253)`,
  controles `rgb(244, 248, 255)`, índice roxo `rgb(75, 29, 115)` e esqueleto
  `rgb(224 233 242 / 68%)`), sem erros de JavaScript ou de servidor.

## 4. Próximos passos

- Continuar a refatoração dos auxiliares restantes (`fct_esqueleto`,
  `fct_graficos_evolucao`, `fct_mapa`, `fct_perfil` e `fct_petalas`), aplicando
  a régua de um dono por função das Sessões 17 e 18.

## 5. Commits da sessão

- `b36217d` Renomeia utils_ui e fct_graficos para fct_ui e fct_graficos_evolucao
- `5ef359c` Centraliza as cores do painel em variáveis no custom.css

---

# Sessão 22 — Otimização da inicialização do mapa (16/09/2026)

- **Pacote:** `painel_ibisma`.
- **Objetivo:** implementar as alternativas A + D + E do diagnóstico da
  inicialização do mapa: pré-serializar a geometria no ETL, enxugar a mensagem
  de dados e arredondar as coordenadas para 4 casas.

## 1. Diagnóstico (medido antes)

| Etapa (por sessão) | Custo |
| --- | --- |
| `desenhar_municipios()` (sf → listas do leaflet) | 1,14–1,17 s |
| Serialização do widget com a geometria | 4,04–4,10 s / 4,00 MB |
| Serialização de cores + tooltips | 0,36 s / 1,99 MB |
| Cliente até o mapa com tooltips | ~5–8 s |
| Abertura completa (parede) | ~15–16 s |

O gargalo era a conversão da geometria e a serialização do widget a cada
sessão, repetidas para cada usuário.

## 2. A — geometria pronta no ETL

- `data-raw/cria_rda.R` passou a gerar `inst/app/data/malha_mapa.rds` com o
  texto JSON dos polígonos no formato colunar do `addPolygons` e os códigos das
  camadas (5.570 municípios).
- `carregar_desenho_municipios()` lê o arquivo uma vez por processo (0,03 s).
- `enviar_desenho_municipios()` manda a geometria como **texto já pronto** na
  mensagem `ibisma_mapa_desenha`; o JavaScript faz `JSON.parse` e cria as
  camadas com `window.LeafletWidget.methods.addPolygons.call(mapa, ...)`, o
  mesmo caminho de dispatch do widget.
- A serialização da mensagem inicial caiu para 0,01–0,04 s (3,54 MB).

## 3. D — dados compactos e tooltip montada no cliente

- `dados_mapa()` devolve as colunas alinhadas à ordem da malha (nome, UF, valor
  em texto e código da categoria), sem HTML.
- `mensagem_mapa()` envia paleta, rótulos e cores de texto uma vez; a mensagem
  de atualização caiu de 1,99 MB para **0,15 MB** (0,000 s).
- O JavaScript monta o HTML do tooltip (`montarTooltip`) e repinta as camadas
  (`aplicarDados`), amarrando o tooltip na primeira passagem.
- Efeito colateral positivo: municípios sem valor no ano (Borá/2023) passaram a
  exibir "Sem dados" em cinza, porque os dados agora partem da malha.

## 4. E — 4 casas decimais

- `arredondar_coordenadas()` passou de 5 para 4 casas (cerca de 11 m), abaixo de
  um pixel no zoom máximo do painel.
- Malha municipal: 0,94 → 0,86 MB; texto do desenho: 3,32 MB (nenhuma
  coordenada com mais de 4 casas no JSON).

## 5. Testes e validação

- `devtools::test()`: **392 asserções verdes** (eram 374). Os testes do mapa
  foram reescritos e ganharam um que compara o desenho gerado com a conversão
  do próprio `leaflet::addPolygons`.
- `dev/bench_inicializacao.R` foi ajustado para medir o desenho pronto, os
  dados compactos e a mensagem.
- Smoke headless: mapa com 5.570 camadas e 5.570 tooltips, hover real
  ("Novo Santo Antônio (MT) — IBISMA 83,6 — Muito alto"), clique destacando o
  município no perfil, Borá/2023 em "Sem dados" e cinza, troca de medida
  repintando na rampa do bloco, nenhum erro de JavaScript.
- Linha do tempo na página: container do mapa em 5,9 s, mapa completo em 6,4 s
  (janela de mapa vazio de 473 ms). Abertura completa: **16,3 s → 6,1 s**.

## 6. Linhas das UFs de volta aos contornos

- Com a geometria dos municípios chegando depois, as camadas passaram a cobrir
  os contornos das UFs, que antes eram desenhados por cima.
- `mapa_base()` ganhou dois painéis (`addMapPane`): `ufs` (zIndex 450) e
  `destaque` (zIndex 460); `desenhar_ufs()` e o contorno do selecionado passaram
  a usar `pathOptions(pane = ...)`, preservando a hierarquia
  municípios < UFs < município selecionado.
- A pedido, os contornos ficaram mais leves: `weight` e `opacity` em 0,75
  (antes 0,8 e 0,85).
- Validação: 27 caminhos SVG no painel `ufs`, ordem dos painéis conferida e
  alinhamento verificado em zoom 7.

## 7. Limitações e próximos passos

- A janela de 473 ms entre o container e as camadas fica coberta pelo esqueleto
  na maior parte dos casos; se incomodar, dá para manter o esqueleto do mapa até
  a mensagem do desenho.
- Ainda restam os ~2 s de ligação de 5.570 tooltips no cliente; a tooltip única
  (um `mouseover` no mapa) ficou como próximo passo.
- O `manifest.json` do deploy segue desatualizado (arquivos de dados
  regenerados e o novo `malha_mapa.rds`); é regenerado no redeploy.
- A refatoração dos auxiliares restantes (`fct_esqueleto`,
  `fct_graficos_evolucao`, `fct_mapa`, `fct_perfil` e `fct_petalas`) continua na
  próxima sessão, com a régua de um dono por função das Sessões 17 e 18.

## 8. Commits da sessão

- `50532f4` Gera o desenho pronto do mapa e arredonda a malha para 4 casas
- `9882020` Envia a geometria do mapa por mensagem e compacta os dados dos tooltips
- `34d36a2` Restaura os contornos das UFs em painel acima dos municípios

---

# Sessão 23 — Tooltip única e dinâmica no mapa (16/09/2026)

- **Pacote:** `painel_ibisma`.
- **Objetivo:** substituir as 5.570 tooltips individuais dos municípios por um
  único tooltip dinâmico, atualizado pelo hover, para testar empiricamente o
  ganho de desempenho e de usabilidade sem mexer em mais nada no painel.

## 1. Diagnóstico da implementação anterior

- As tooltips nasciam no JavaScript (`aplicarDados`): na primeira passagem,
  `bindTooltip` com `sticky: true`; nas atualizações, `setTooltipContent`
  camada a camada.
- O `sticky` registra cerca de 5 listeners por camada no leaflet
  (`mouseover`, `mouseout`, `mousemove`, `move` e `remove`) — ~27,8 mil
  registros —, além de guardar 5.570 objetos `Tooltip` com o HTML de cada
  município (a "ligação" de ~2 s medida na Sessão 22).
- Cada troca de ano ou de medida chamava `setTooltipContent` 5.570 vezes, só
  para trocar o texto de tooltips que estavam ocultas.

## 2. Tooltip única

- `prepararTooltip()` cria **um único `L.tooltip` por mapa** e registra três
  listeners no mapa: `mouseover` (monta o HTML do município e mostra),
  `mousemove` (acompanha o cursor) e `mouseout` (esconde).
- Os dados continuam vindo da mensagem compacta (Sessão 22); ela passou a
  ficar guardada em `dadosPorMapa[id]` e o HTML do tooltip é montado sob
  demanda, sem duplicar conteúdo por camada.
- `aplicarDados()` só repinta `fillColor`, anota `camada._ibisma_indice`
  (acesso O(1) ao índice do município na mensagem) e chama
  `camada.addEventParent(mapa)`.
- **Achado:** neste leaflet, os eventos de hover do canvas chegam ao mapa
  **sem** `e.layer` (o `mouseover` do mapa é disparado pelo próprio mapa; a
  camada não propaga os eventos). O `addEventParent(mapa)` — o mesmo
  mecanismo do `FeatureGroup` — faz os eventos da camada subirem ao mapa com
  `e.layer`, sem listener por camada e de forma idempotente (cada camada
  segue com um único pai depois das trocas de medida).
- `montarTooltip()` e o CSS `.leaflet-tooltip.tooltip-ibisma` foram mantidos:
  sem mudança visual. O `sticky` saiu das opções (era do binding antigo), sem
  alterar o posicionamento (`direction: "auto"`).
- A mensagem do servidor, o ETL e todo o lado R continuaram iguais.

## 3. Preservado

- Realce de hover e contorno de seleção, clique no mapa (`shape_click`),
  contornos das UFs, painéis do mapa, esqueleto, filtros e sincronizações do
  painel — tudo intacto; o clique continua levando o município ao perfil.

## 4. Testes e validação

- `devtools::test()`: **392 asserções verdes** (nenhuma mudança no R).
- Smoke headless com hover real e sintético: `camadas=5570 | comTooltip=0`
  (nenhuma tooltip individual), tooltip mostra `Altamira (PA) | 91,6 |
  Muito alto` no município correto, some ao sair, reaparece reaproveitando o
  mesmo nó do DOM e segue o cursor; troca de medida pelo servidor reflete no
  rótulo ("Pré-natal"); clique mantém a seleção (`Altamira, PA` e um contorno
  no painel de destaque); sem erros de JavaScript.
- Evidências em temporários fora do git (`smoke_tooltip/`).

## 5. Limitações e observações

- Touch: a tooltip depende de hover; o toque segue selecionando o município
  normalmente, mas a tooltip pode não aparecer como antes — observar no uso.
- Efeito colateral do bubbling: eventos de camada agora sobem ao mapa, então
  inputs não usados pelo painel (`onde-mapa_click` etc.) podem ser enviados em
  duplicidade; os usados (`shape_click`, `shape_mouseover`) seguem únicos.
- Com o mouse parado sobre o município, a tooltip visível só reflete troca de
  ano/medida no próximo hover.
- A medição empírica do ganho fica com o usuário; a mudança foi isolada de
  propósito para permitir o antes/depois.

## 6. Commits da sessão

- `ab0b932` Troca as 5.570 tooltips do mapa por um tooltip único dinâmico

---

# Sessão 24 — Repositório oficial: nome sem versão (16/09/2026)

- **Pacote:** `painel_ibisma` (antes `painel_ibisma_v4`).
- **Objetivo:** transformar este repositório no repositório oficial do painel do
  IBISMA, removendo todas as referências a versão (v4) e ao caráter de testes.

## 1. Renomeação do pacote

- `DESCRIPTION`, `R/app_config.R` (`app_sys`), `app.R`, `tests/testthat.R`,
  `inst/golem-config.yml` (`golem_name`) e os scripts de `dev/` passaram a usar
  `painel_ibisma`.
- `R/painel_ibisma_v4-package.R` → `R/painel_ibisma-package.R` e
  `painel_ibisma_v4.Rproj` → `painel_ibisma.Rproj`, com `git mv` (histórico
  preservado).
- Documentação regenerada (`devtools::document()`): sai
  `man/painel_ibisma_v4-package.Rd`, entra `man/painel_ibisma-package.Rd`; o
  `NAMESPACE` passou ao formato do roxygen2 8.1.0 instalado.
- `manifest.json` regenerado (`rsconnect::writeManifest()`): além do caminho
  novo do pacote, o arquivo deixou de listar itens que já não existem
  (`utils_ui.R`, `fct_config.R`, `fct_graficos.R` e `data/df_ibisma.rda`) e
  passou a listar os arquivos prontos de `inst/app/data/`.

## 2. Notas das sessões e repositório

- `sessions_md/2026-09-12_implementacao_painel_ibisma_v1.md` virou
  `sessions_md/2026-09-12_implementacao_painel_ibisma.md`; título e menções a
  números de versão foram neutralizados ("versão anterior", "pastas da sessão").
- O repositório remoto `RafaHerzog/painel_ibisma_testes` foi renomeado para
  `RafaHerzog/painel_ibisma` (o GitHub mantém redirecionamento do nome antigo).
- A pasta local do projeto (`.../painel_ibisma_v4`) pode ser renomeada para
  `painel_ibisma` com o R/RStudio fechados.

## 3. Testes e validação

- `devtools::test()`: **392 asserções verdes** já sob o nome `painel_ibisma`.
- Smoke headless: app sobe com `painel_ibisma::run_app()`, mapa com 5.570
  camadas, tooltip única funcionando e dados lidos por `app_sys` sem aviso.
- Busca final por referências a `v4`/`painel_ibisma_testes` nos arquivos
  versionados: nenhuma restante (só o `V8`, motor do `rmapshaper`, que não é
  versão do painel).

## 4. Commits da sessão

- `ec28fb5` Renomeia o pacote para painel_ibisma e remove as referências de versão

---

# Sessão 25 — Caracteres literais no lugar de escapes unicode (16/09/2026)

- **Pacote:** `painel_ibisma`.
- **Objetivo:** retirar do código os escapes unicode (`\u00e7`, `\u00e3`, etc.) que geram
  caracteres especiais e escrever os caracteres literais (`ç`, `ã`, `í`, `º`, travessões),
  para que qualquer texto do painel possa ser encontrado por busca manual.

## 1. Substituição nos arquivos

- 33 linhas em 7 arquivos: `R/fct_dados.R`, `R/fct_mapa.R`,
  `R/fct_graficos_evolucao.R`, `R/mod_onde.R`, `R/mod_como.R`,
  `dev/headless_smoke.R` e `tests/testthat/test-funcoes_globais.R`.
- Conversões: `\u00e3` → ã, `\u00e7` → ç, `\u00ed` → í, `\u00e1` → á, `\u00f3` → ó,
  `\u00f5` → õ, `\u00ba` → º, `\u00b7` → ·, `\u2013` → – e `\u2014` → —.
- Ficaram intencionalmente como escapes os intervalos de expressões regulares que
  dependem do código unicode (`[\\u0300-\\u036f]` na busca sem acento da tabela e
  `[\u0300-\u036f]` na busca dos seletores): são código de normalização, não texto de
  exibição.
- O `manifest.json` não foi tocado: além de ser regenerado no redeploy, os escapes
  vêm dos metadados dos pacotes de terceiros.

## 2. Convenção no AGENTS.md

- A seção de convenções ganhou a regra de nunca usar escapes unicode para representar
  acentos, ç ou outros caracteres especiais, com a exceção dos intervalos de regex que
  dependem do código unicode.

## 3. Testes e validação

- `devtools::test()`: **392 asserções verdes** (suíte rodada com `rlang` 1.3.0 da
  biblioteca temporária, como nas sessões anteriores).
- `parse("dev/headless_smoke.R")` sem erros (o script não é coberto pela suíte).
- Busca final por `\uXXXX` em todo o repositório: restam apenas os dois intervalos de
  regex e os metadados do `manifest.json`.

## 4. Commits da sessão

- `72b91a8` Substitui os escapes unicode por caracteres literais no painel
- `d8b114c` Proíbe os escapes unicode nas convenções do AGENTS.md

---

# Sessão 26 — Realce da busca sem acento nos seletores (16/09/2026)

- **Pacote:** `painel_ibisma`.
- **Objetivo:** fazer o realce do trecho buscado acompanhar a busca sem acento dos
  seletores, ligada na Sessão 13: digitar "sao" filtra "São Paulo", mas o "São" não
  ficava aceso.

## 1. Causa

- O filtro normalizado (Sessão 13) troca só o `events.searchFilter`; o realce continua
  sendo o `highlightText` do próprio slimSelect, que monta um regex com o termo cru
  (`(sao)`) sobre o texto original ("São"), então nunca casa.
- A tabela do ranking não tem realce de busca (o reactable só filtra as linhas), então
  a correção ficou restrita aos seletores.
- **Achado:** no slimSelect 2.x embutido no shinyWidgets, o renderizador fica em
  `instancia.render` (`render.content.search.input`, `render.highlightText`); a
  instância não tem mais o `content` da versão 1.x.

## 2. Correção

- Novo `normalizarComMapa()` normaliza o texto letra a letra e guarda de qual caractere
  original cada letra veio; `destacar()` localiza o trecho normalizado e volta às
  posições originais para envolvê-lo em `<mark class="ss-search-highlight">`.
- `ajustar()` passou a substituir `render.highlightText`, preservando o realce original
  para opções com HTML; quando a busca não casa, o texto fica sem realce (como antes).
- O realce vale para todos os seletores; os que não têm busca nunca chamam o método.

## 3. Testes e validação

- Smoke headless no seletor de município digitando "sao": 367 opções filtradas, todas
  realçadas, com `São Paulo (SP)` em
  `<mark class="ss-search-highlight">São</mark> Paulo (SP)`.
- Nenhuma mudança em R; a suíte não cobre JavaScript.

## 4. Commits da sessão

- `99185ec` Corrige o realce da busca sem acento nos seletores

---

# Sessão 27 — Tooltip do mapa por toque (17/09/2026)

- **Pacote:** `painel_ibisma`.
- **Objetivo:** fazer a tooltip do mapa responder ao toque no mobile, sem
  regredir o hover no desktop, e validar com toques reais no smoke headless.

## 1. Diagnóstico

- A tooltip única (Sessão 23) escutava apenas `mouseover`, `mousemove` e
  `mouseout`: no toque o município era selecionado, mas o valor e a categoria
  não apareciam.
- **Achado:** o `Tooltip.getEvents` do Leaflet registra o `preclick` para
  fechar tooltips quando `Browser.touch` é verdadeiro; o Chrome do Windows
  reporta touch mesmo com mouse, então clicar em um município já escondia a
  tooltip no desktop até o próximo hover (comportamento pré-existente).

## 2. Comportamento no cliente

- Novo `PODE_HOVER` (`matchMedia("(hover: hover) and (pointer: fine)")`)
  separa mouse de toque; nos dispositivos de toque os handlers de hover ficam
  inertes.
- `mostrar()`/`esconder()` centralizam o balão; o `click` do mapa reexibe a
  tooltip do município tocado (o mesmo caminho conserta o clique no desktop,
  fechado pelo `preclick`) e o clique sem município fecha o balão (o evento
  propagado da camada é distinguido pelo `propagatedFrom`).
- Arrastar o mapa no toque (`movestart`) fecha a tooltip fixada; no mouse o
  comportamento de hover segue igual.
- No toque o lado do balão (`top`/`bottom`) segue a metade visível da janela: o
  mapa continua abaixo da dobra e o `direction: "auto"` do Leaflet, que olha o
  contêiner, nascia abaixo do ponto e cortava o balão.

## 3. Ferramenta de smoke

- `dev/headless_smoke.R` ganhou `--tap=x,y` e `--tap2=x,y`: toque real via
  `Input.dispatchTouchEvent` (touchStart e touchEnd com o mesmo ponto — a lista
  vazia no fim do toque é rejeitada pelo CDP com `-32602` e sem o ponto o
  navegador não gera o clique de compatibilidade).
- `AGENTS.md` documenta as duas opções.
- **Armadilha de ambiente:** chamando o smoke por `Start-Job`/PowerShell, o
  argumento `--tap=x,y` precisa estar entre aspas — fora delas a vírgula
  divide o argumento e o `y` chega como `NA`.

## 4. Testes e validação

- `devtools::test()`: **392 asserções verdes** (rodada com `rlang` 1.3.0 de
  biblioteca temporária, como nas sessões anteriores).
- Smoke desktop (1600×900, `hover=true`): o hover mostra a tooltip e o clique
  em um município não a esconde mais.
- Smoke mobile (390×844, `hover=false`): o toque em Vila Boa (GO) mostrou
  "Vila Boa (GO) | IBISMA 85,1 | Muito alto" acima do ponto; o segundo toque
  no oceano fechou o balão.
- Evidências em temporários fora do git (`smoke_touch/`).

## 5. Commits da sessão

- `a9df2d7` Adiciona tooltip por toque no mapa
- `df9482c` Testa o toque do mapa no smoke headless

---

# Sessão 28 — Canvas em alta resolução e emendas do mapa (17/09/2026)

- **Pacote:** `painel_ibisma`.
- **Objetivo:** corrigir o borrão do mapa em telas de alta densidade e
  investigar as linhas retas brancas que aparecem com o mapa aproximado.

## 1. Nitidez do mapa (canvas no DPR real)

- **Causa:** o `L.Canvas._update` do Leaflet 1.1.1 (embutido no pacote
  `leaflet`) usa um fator fixo de 2 quando detecta `Browser.retina`, sem olhar o
  `devicePixelRatio` real; em telas com DPR maior (celulares 3x) o desenho é
  ampliado e fica borrado. O valor é decidido no carregamento e não se atualiza
  se o DPR mudar depois — o mesmo padrão que levou os gráficos ECharts ao
  renderizador SVG (Sessão 11).
- **Medições antes:** DPR 3 → backing de 1508 px para 754 px CSS (ampliação de
  1,5×); DPR 1,5 → 1508 px (redução de 2×).
- **Correção (commit `3bb99c7`):** em `funcoes_javascript.js`, um
  `L.Canvas.include` reescreve o `_update` com o `devicePixelRatio` real
  (backing `round(dpr × tamanho)`, escala pelas razões arredondadas), mantendo
  o canvas e a fluidez. As mudanças reais de DPR (zoom do navegador, troca de
  monitor) alteram o tamanho CSS e o Leaflet refaz o canvas no `resize` —
  validado com emulação: `backing = 2,5 × CSS` após a troca.
- **Alternativa testada e descartada:** `preferCanvas = FALSE` (SVG) para os
  municípios. Em 1600×950 com 5.570 municípios: +23% de nós no DOM, +2-5 MB de
  heap, ~+120 ms no desenho inicial, hover equivalente e repintura igual ou
  melhor; ficou no canvas para não perder a fluidez percebida.
- **Resíduos:** durante a animação de zoom o canvas é escalado por transform
  (borrão transitório, como antes) e a rasterização cresce com o DPR².
- **Validação:** DPR 3 com backing 2262 = 3 × 754 (nítido); DPR 1,5 com 1131;
  hover, clique, tooltip, toque no mobile e repintura por medida funcionando;
  `devtools::test()` com 392 asserções verdes.

## 2. As linhas retas brancas (diagnóstico)

- **Reprodução:** zoom 8 sobre Ulianópolis (PA). As linhas aparecem **sem**
  hover nenhum e também existem no código anterior ao ajuste de DPR (bisect com
  `git stash` mostrou capturas idênticas).
- **Não são as divisas:** pintando todos os municípios de vermelho e deixando as
  divisas transparentes, com limpeza total do canvas e redesenho do zero, as
  linhas continuam — não são traço, nem pixel velho, nem falha de limpeza.
- **São emendas do mosaico:** a contagem de pixels do canvas mostra ~2.100
  pixels com alfa baixo (o fundo claro aparecendo) nas bordas entre
  preenchimentos vizinhos — antialiasing das bordas (com o preenchimento a 0,95)
  somado a fendas reais da malha. Onde os limites municipais são retos (a malha
  do PA tem limites retilíneos — conferido ao plotar a malha do IBGE), a emenda
  fica reta e aparece como um fio claro sobre áreas da mesma cor.
- **Tentativa de correção (revertida):** preenchimento opaco (`fillOpacity: 1`)
  e divisa de `weight 0.5`/`opacity 0.8` para cobrir a emenda; a medição caiu de
  ~2.081 para ~729 pixels de emenda, mas a avaliação do usuário foi de que o
  problema não ficou resolvido. A mudança foi revertida e o tema fica em aberto.

## 3. Caminhos possíveis para a próxima sessão

- Corrigir as fendas na geração da malha (topologia/arredondamento no
  `cria_rda.R`) e remedir as frestas.
- Desenhar o contorno na própria cor do município (mosaico sem divisas) ou
  manter as divisas em uma segunda camada por cima, cobrindo as emendas.
- Investigar o `setStyle`/redesenho parcial do Leaflet 1.1.1 no hover: o
  `_clear` sem limites limpa `clearRect(0, 0, width, height)` com a
  transformação aplicada (sem `setTransform` de identidade, como nas versões
  novas), o que merece uma checagem em redesenho completo.
- Evidências dos testes em temporários fora do git (`smoke_touch/`), incluindo
  as capturas do zoom sobre Ulianópolis antes e depois.

## 4. Commits da sessão

- `3bb99c7` Desenha o canvas do mapa na resolução real da tela

---

# Sessão 29 — Linhas claras no hover do mapa (17/09/2026)

- **Pacote:** `painel_ibisma`.
- **Objetivo:** corrigir as linhas retas claras que apareciam ao redor dos
  municípios em hover (e se acumulavam a cada município visitado), surgidas
  depois do canvas na resolução real da tela (Sessão 28).

## 1. Diagnóstico

- **Sintoma:** cada município visitado pelo mouse deixava linhas ou retângulos
  claros no mapa, que se acumulavam; ocorria no Chrome e no Firefox, mas não na
  janela do VS Code (diferença compatível com DPR fracionário numa janela e
  inteiro na outra).
- **Caminho do código:** o binding do leaflet aplica o `highlightOptions` no
  hover (`setStyle` + `bringToFront`), o que dispara o redesenho **parcial** do
  canvas: `_clear` faz `clearRect` e `_draw` recorta (`clip`) o retângulo do
  bounding box do município (`Path._pxBounds` estendido por `weight + 1`).
- **Causa:** as bordas desse retângulo são antialiasadas. Com o canvas na DPR
  real (commit `3bb99c7`), em escalas fracionárias (125%/150% do Windows e zoom
  do navegador) as bordas caem no meio de um pixel: a limpeza e o recorte
  deixam uma linha clara de 1 px no perímetro, e o `fillOpacity` de 0,95 deixa
  o fundo atravessar. Em DPR inteiro (1 ou 2 — o VS Code e o código anterior,
  que usava fator fixo 2) as bordas caem em pixels inteiros e nada aparece.
- **Reprodução:** smoke headless com hovers reais em grade sobre Ulianópolis
  (PA, zoom 8): em DPR 1,25 e 1,5 as linhas aparecem e se acumulam; em DPR 1
  não aparecem.
- **Caso-limite encontrado:** com escala menor que 1 (zoom out do navegador), a
  limpeza **total** do canvas (`clearRect(0, 0, width, height)`, nas
  coordenadas do desenho) não alcançava as bordas direita e de baixo: 36% do
  canvas ficava sujo (79.676 de 221.741 pixels medidos com escala 0,8).

## 2. Correção (`inst/app/www/global/funcoes_javascript.js`)

- `_redraw` foi reescrito: o recorte é levado para pixels da tela com
  `getTransform()`, arredondado para fora (`floor`/`ceil`) e devolvido às
  coordenadas do desenho, de modo que a limpeza e o `clip` caiam em pixels
  inteiros.
- `_clear` foi reescrito: sem recorte, a limpeza usa `setTransform` de
  identidade e `clearRect` com o tamanho real do canvas, em pixels da tela.
- **Alternativa avaliada e descartada:** forçar o redesenho completo (recorte
  nulo). Também elimina as linhas, mas custa 17–25 ms por hover no
  enquadramento do Brasil (5.570 camadas), contra ~1 ms com o recorte alinhado.

## 3. Testes e validação

- `devtools::test()`: **392 asserções verdes** (a suíte não cobre JavaScript).
- Smoke headless em DPR 1,25 e 1,5, com 24 hovers reais em grade: imagens antes
  e depois sem as linhas, com hover, contorno de destaque e tooltip intactos e
  sem erros de JavaScript ou de servidor.
- Limpeza com escala 0,8: 0 pixels não limpos depois da correção (eram 79.676).
- Evidências em temporários fora do git (`hover_corrigido/` e `hover_final/`).

## 4. Limitações

- Restam os traços brancos das fendas da malha (Sessão 28), que não dependem do
  hover e seguem em aberto.

## 5. Commits da sessão

- `bc68ebd` Alinha o redesenho do canvas do mapa aos pixels da tela
- `95876a6` Regerados os arquivos tabela_ano do painel (fechamento da sessão;
  conteúdo idêntico ao anterior, mudou só a serialização)

---

# Sessão 30 — Fluidez do tooltip da evolução temporal (17/09/2026)

- **Pacote:** `painel_ibisma`.
- **Objetivo:** investigar a sensação de tooltip lento e pesado nos gráficos de
  evolução (echarts) e ajustar a transição do balão.

## 1. Diagnóstico (medido no app)

- O echarts 6.0.0 embutido aplica ao tooltip, por padrão,
  `transitionDuration: 0.4` e `displayTransition: true`, que viram CSS inline
  no balão: `transition: opacity 0.2s, visibility 0.2s, transform 0.4s
  cubic-bezier(0.23, 1, 0.32, 1)`.
- Além disso, com `transitionDuration > 0` o `TooltipView.render` troca o
  listener de posição por `createOrUpdate(this, "_updatePosition", 50,
  "fixRate")`: a posição do balão passa a ser recalculada no máximo a cada
  50 ms (20 Hz), qualquer que seja a taxa do mouse.
- Medição com varredura real do mouse sobre o gráfico do IBISMA (1600×950,
  DPR 2), amostrando por quadro a posição-alvo (transform inline) e a posição
  visível (transform computada) do balão:

| | 0,4 s (padrão) | 0,3 s (escolhido) | 0,2 s | 0 (sem transição) |
| --- | --- | --- | --- | --- |
| Intervalo entre atualizações | 50 ms | 51 ms | 50 ms | por evento |
| Atraso do desenho vs. cursor (mediana / máx.) | 47 / 85 px | 29 / 86 px | 17 / 99 px | 0 / 0 px |
| Deslize depois do cursor parar | 285 ms | 200 ms | 101 ms | nenhum |
| Tarefas longas de CPU | 0 | 0 | 0 | 0 |

- O peso não é cálculo: nenhuma tarefa longa do navegador apareceu nas
  medições; a lentidão vem da transição CSS e do *throttle* interno.

## 2. Iterações e decisão

- Primeira correção: `transitionDuration = 0`, que remove a transição e o
  *throttle* (balão colado no cursor; medido com atraso 0 px e nenhum
  deslize).
- A preferência passou por 0,2 s, voltou ao padrão (0,4 s) e ficou em
  **0,3 s**: meio-termo entre o deslize do padrão e a resposta imediata do 0.
- Qualquer valor maior que 0 reativa o *throttle* de 50 ms do echarts — a
  cadência de 20 Hz é comportamento interno da biblioteca.

## 3. Correção

- `tooltip_echarts()` (`R/fct_graficos_evolucao.R`) ganhou
  `transitionDuration = 0.3`, valendo para os sete gráficos da evolução
  (IBISMA e blocos).

## 4. Testes e validação

- `devtools::test()`: **394 asserções verdes**, com as novas asserções de
  `transitionDuration` e do acionamento por eixo do tooltip.
- Medições em smoke headless com varredura real do mouse (temporários fora do
  git, `mede_tooltip.R` e `sonda_cadencia.R`), com e sem a transição.
- Observação: a sensação de Hz baixo que ainda restava no computador do usuário
  vinha de um jogo aberto disputando a máquina, não do painel.

## 5. Commits da sessão

- `316084a` Encurta a transicao do tooltip da evolucao temporal

---

# Sessão 31 — Canvas nítido em escalas fracionárias (18/09/2026)

- **Pacote:** `painel_ibisma`.
- **Objetivo:** corrigir o borrão do mapa, que ficou pior do que no canvas de
  fator fixo 2 depois do ajuste de DPR real (Sessão 28), mantendo o
  `preferCanvas` e o desenho sempre na densidade adequada da tela.

## 1. Diagnóstico

- **Sintoma:** o mapa carregado ficou mais macio do que na versão de fator fixo
  2, mesmo sem alterar o zoom da página.
- **Reprodução:** smoke headless com `--dpr=1.25` e `--dpr=1.5`; no recorte
  ampliado, as divisas brancas ficam grossas e difusas na versão de DPR real,
  contra linhas finas e firmes na de fator 2.
- **Medição (magnitude de bordas no mesmo recorte):** DPR real 0,0430; fator 2
  0,0499.
- **Causa:** o bitmap na escala real (1,25) é nítido — extraído direto do canvas
  por `toDataURL`, o desenho está limpo. O borrão nasce na composição: o
  navegador reamostra o canvas (bitmap → tamanho CSS → pixels do dispositivo) e
  a escala fracionária suaviza o resultado. Com um fator inteiro acima do DPR
  (supersampling), a sobra de resolução mantém as bordas firmes, como no fator
  fixo 2 que existia antes.

## 2. Correção

- `L.Canvas._update` (`inst/app/www/global/funcoes_javascript.js`) passou a
  arredondar o `devicePixelRatio` para o próximo inteiro, com mínimo 1:
  1 → 1, 1,25 → 2, 1,5 → 2, 2 → 2, 3 → 3.
- O canvas usa `fator × tamanho` como bitmap e `ctx.scale(fator, fator)` no
  desenho; a densidade é relida a cada `_update`, disparado pelo Leaflet em
  `resize`/`moveend`, o que cobre o zoom do navegador e a troca de monitor.
- O alinhamento do recorte do hover (Sessão 29) continua valendo: com o fator
  inteiro o recorte cai exatamente nos pixels da tela.
- Custo: em DPR fracionário o bitmap volta ao tamanho do fator 2 antigo; em
  DPR 3 ele cresce de 2× para 3× (o caso que a Sessão 28 queria resolver).

## 3. Testes e validação

- `devtools::test()`: **394 asserções verdes**.
- Smoke headless: fator e bitmap na proporção esperada em DPR 1 (754×648),
  1,25 (1508×1296), 2 (mobile, 744×1176) e 3 (2262×1944), sem erros de
  JavaScript.
- Em DPR 1,25 a captura ficou **idêntica byte a byte** à versão de fator fixo 2
  (a que o usuário considerava nítida), e o hover real seguiu mostrando a
  tooltip ("Pontal do Araguaia (MT) — IBISMA 59,8 — Alto").
- Evidências em temporários fora do git (recortes comparativos 3× e bitmap
  extraído do canvas).

## 4. Commits da sessão

- `9ffe4c5` Corrige o borrao do canvas do mapa em escalas fracionarias

---

# Sessão 32 — Mapa acompanhando o escopo do ranking (12/10/2026)

- **Pacote:** `painel_ibisma`.
- **Objetivo:** fazer o mapa da seção Onde? acompanhar o seletor de escopo —
  enquadrando a UF escolhida com uma transição animada e destacando-a
  visualmente —, sem recriar o mapa e sem tocar nas cores dos percentis.
  O destaque e a duração do voo foram refeitos após revisão de uso.

## 1. Enquadramento por escopo

- Novo `limites_escopo()` (`R/fct_mapa.R`): no nacional devolve o mesmo
  retângulo do enquadramento inicial do cliente e, em uma UF, a caixa
  envolvente da malha estadual em cache. O PE inclui Fernando de Noronha, que
  tem código próprio na base e entra no ranking do estado.
- `enquadrar_escopo()` move a câmera pelo proxy do leaflet, sem recriar o
  widget; `aplicar_escopo()` concentra destaque + voo.
- Em `mod_onde.R`, o escopo é aplicado na troca do seletor e, se a escolha
  acontecer antes de o mapa montar, no primeiro `mapa_pronto`.
- O mapa é o mesmo durante tudo: o contêiner e a instância do leaflet marcados
  no smoke continuam os mesmos depois das trocas (`MAPA_PRESERVADO true`).

## 2. Voo animado

- **Causa do salto brusco:** o `fitBounds` do leaflet vira `setView`, que só
  anima pan que caiba na viewport e anima zoom quando a diferença é de até 4
  níveis; entre UFs distantes com o mesmo zoom, a troca era instantânea.
- **Solução:** `flyToBounds` nativo (centro e zoom interpolados), com duração
  fixa de 1,2 s e folga de 16 px por lado. Na revisão de uso a duração foi
  reduzida para **0,8 s** ("a animação está durando muito tempo").
- **Interrupções:** o `flyTo` cancela o voo anterior e parte da posição atual;
  trocas sucessivas são contínuas e a última seleção sempre vence.
- Descartada uma passagem por `deferUntilFlush = FALSE`: o voo começava antes,
  mas travava ~0,6 s no meio, enquanto a tabela e o perfil re-renderizavam.

## 3. Destaque da UF escolhida

- A primeira abordagem (contorno com halo branco e linha azul escura) foi
  rejeitada na revisão de uso.
- **Solução final, por contraste:** um véu translúcido na cor do fundo do mapa
  (`#EDF1F7`, opacidade 0,5) cobre as UFs fora do escopo, e a UF escolhida
  permanece com as cores dos percentis intactas. O véu fica no painel
  `apagado` (zIndex 445), entre os municípios e os contornos das UFs, sem
  contorno próprio e sem capturar o mouse; no nacional é removido por completo.
- **Achado:** um mesmo `layerId` para 26 feições em `addPolygons` não funciona
  — o gerenciador do leaflet registra uma camada por id e remove as anteriores,
  de modo que o véu acabava cobrindo apenas o último estado. Solução: um
  identificador por UF (`apagado_<sigla>`), com os 27 ids removidos a cada
  troca e os 26 restantes readicionados em uma única chamada.
- As cores dos dados não são tocadas: o histograma de preenchimentos dos
  municípios é idêntico antes e depois do véu.

## 4. Testes e validação

- `devtools::test()`: **515 asserções verdes** (suíte com `rlang` 1.3.0 de
  biblioteca temporária, como nas sessões anteriores).
- Smoke headless com medições no app: `moveend` do voo em 819 ms com a duração
  de 0,8 s; RJ→PB (mesmo zoom) com 49–50 posições intermediárias amostradas;
  PB→DF (zoom 7→9) correto; AM interrompido por SP termina exatamente em SP; o
  véu tem 26 caminhos no painel e 0 no nacional; contra a captura sem destaque,
  ~61% dos canais de cor mudam (MG 170→204; SP 197→197); hover e clique seguem
  funcionando sobre UFs esmaecidas (Belo Horizonte); mobile 390 px com o
  contraste correto; nenhum erro de JavaScript.
- Evidências em temporários fora do git (`dev/smoke/zoom_escopo/`).

## 5. Limitações

- O início do voo depende do processamento do servidor e da re-renderização da
  tabela e do perfil no cliente; em máquinas carregadas há atraso entre o
  clique e o movimento (até ~1,4 s medido em cenário carregado), sem alongar a
  animação em si. Durante o voo podem ocorrer 1–2 travadas de quadro pelo mesmo
  motivo.
- O véu clareia as cores das UFs fora do escopo (percepção), por decisão de
  contraste; a UF escolhida e os tooltips seguem com as cores exatas.
- A duração do voo (0,8 s) e a opacidade do véu (0,5) ficam em pontos únicos
  em `R/fct_mapa.R`, fáceis de ajustar.
- O `run_app()` de desenvolvimento precisa ser reiniciado para carregar o
  código novo (o processo carrega o pacote uma única vez).

## 6. Commits da sessão

- `dd2aa49` Faz o mapa acompanhar o escopo do ranking

