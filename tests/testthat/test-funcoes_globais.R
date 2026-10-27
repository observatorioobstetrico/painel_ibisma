# Testes das funções globais do painel (dados, categorias, rankings e cores)

# Série pequena e previsível para os testes de gráficos e eixos
series_teste <- data.frame(
  ano = 2020:2021,
  indice_final = c(90, 70),
  bloco1 = c(85, 25),
  bloco2 = c(75, 30),
  bloco3 = c(65, 35),
  bloco4 = c(55, 40),
  bloco5 = c(45, 45),
  bloco6 = c(35, 50),
  stringsAsFactors = FALSE
)

# Base de referência da pipeline de indicadores, lida direto dos CSVs (fora do build)
caminho_indice <- testthat::test_path(
  "..", "..", "data-raw", "databases", "indice_materno_final_2015_2024.csv"
)
caminho_indicadores <- testthat::test_path(
  "..", "..", "data-raw", "databases", "banco_dados_atualizado_2024_abril.csv"
)
caminho_hemo <- testthat::test_path(
  "..", "..", "data-raw", "databases", "dados_servicos_hemo.csv"
)
tem_pipeline <- all(file.exists(caminho_indice, caminho_indicadores, caminho_hemo))
if (tem_pipeline) {
  indice_referencia <- unique(read.csv(caminho_indice))
}

# Pulando os testes da base quando os CSVs da pipeline não estão presentes
exigir_pipeline <- function() {
  testthat::skip_if_not(tem_pipeline, "CSVs da pipeline não disponíveis")
}

test_that("os dados prontos têm cadastro, anos e séries completos", {
  exigir_pipeline()
  dados <- dados_vidas()

  # O cadastro tem os municípios e os anos da base bruta
  expect_equal(dados$anos, sort(unique(indice_referencia$ano)))
  expect_equal(nrow(dados$municipios), length(unique(indice_referencia$codmunres)))
  expect_setequal(names(dados$municipios), c(
    "codmunres", "municipio", "sigla_uf", "uf",
    "regiao", "r_saude", "macro_r_saude"
  ))

  # As séries têm uma linha por município e ano, com as medidas e os indicadores
  expect_equal(nrow(dados$series), length(dados$anos) * nrow(dados$municipios))
  expect_equal(
    names(dados$series),
    c(
      "codmunres", "ano", MEDIDAS$medida,
      intersect(INDICADORES$indicador, names(dados$series))
    )
  )
})

test_that("as séries prontas batem com os CSVs da pipeline", {
  exigir_pipeline()
  dados <- dados_vidas()
  testthat::skip_if_not(
    tem_indicadores(dados),
    "séries prontas sem indicadores (rode data-raw/cria_rda.R)"
  )

  # Ligando cada linha da série à linha correspondente do índice final
  chave_serie <- paste(dados$series$ano, dados$series$codmunres)
  chave_indice <- paste(indice_referencia$ano, indice_referencia$codmunres)
  posicao <- match(chave_serie, chave_indice)

  # O índice e os blocos saem do CSV final, invertidos de vulnerabilidade para VIDAS
  for (medida in MEDIDAS$medida) {
    coluna <- if (medida == "indice_final") "indice_mf_v1" else medida
    expect_equal(
      dados$series[[medida]],
      100 * (1 - indice_referencia[[coluna]][posicao]),
      tolerance = 1e-12
    )
  }

  # Os indicadores saem da base intermediária, com a hemoterapia em separado
  brutos <- unique(read.csv(caminho_indicadores))
  hemo <- unique(read.csv(caminho_hemo))
  chave_brutos <- paste(brutos$ano, brutos$codmunres)
  chave_hemo <- paste(hemo$ano, hemo$codmunres)
  posicao_brutos <- match(chave_serie, chave_brutos)
  posicao_hemo <- match(chave_serie, chave_hemo)

  for (i in seq_len(nrow(INDICADORES))) {
    indicador <- INDICADORES$indicador[i]
    if (indicador == "leitos_obst_med_transfusional") {
      bruto <- hemo$indicador5[posicao_hemo]
    } else {
      bruto <- brutos[[indicador]][posicao_brutos]
    }
    esperado <- INDICADORES$fator[i] * bruto
    esperado[is.nan(esperado)] <- NA
    # Anos ausentes da pipeline ficam sem dado na série, mesmo com valor na fonte
    esperado[is.na(posicao)] <- NA
    expect_equal(dados$series[[indicador]], esperado, tolerance = 1e-12)
  }
})

test_that("as tabelas anuais usam as medidas e as categorias do painel", {
  exigir_pipeline()
  dados <- dados_vidas()

  # A pipeline precisa entregar os blocos e o índice que viram as medidas do painel
  expect_true(all(c(BLOCOS$medida, "indice_mf_v1") %in% names(indice_referencia)))

  for (ano in dados$anos) {
    tabela <- tabela_ano(dados, ano)
    expect_setequal(unique(tabela$medida), MEDIDAS$medida)
    expect_equal(levels(tabela$categoria), CATEGORIAS)
    expect_true(is.ordered(tabela$categoria))
  }
})

test_that("as categorias seguem os quintis e os rankings do ano", {
  dados <- dados_vidas()
  ano <- max(dados$anos)

  for (medida in MEDIDAS$medida) {
    base <- valores_ano(dados, ano, medida)

    # A categoria de cada município é a faixa dos quintis do ano
    cortes <- stats::quantile(base$valor, c(0.2, 0.4, 0.6, 0.8), na.rm = TRUE)
    expect_equal(
      as.integer(base$categoria),
      findInterval(base$valor, cortes) + 1L
    )
    expect_setequal(unique(base$categoria), CATEGORIAS)

    # A posição 1 é o município com menor Índice VIDAS, com empates pelo mínimo
    expect_equal(
      base$pos_nac,
      rank(base$valor, ties.method = "min", na.last = "keep")
    )
    expect_equal(unique(base$total_nac), sum(!is.na(base$valor)))

    # O ranking da UF é calculado dentro de cada estado
    iguais <- base[base$sigla_uf == "RO", ]
    expect_equal(
      iguais$pos_uf,
      rank(iguais$valor, ties.method = "min", na.last = "keep")
    )
    expect_equal(unique(iguais$total_uf), sum(!is.na(iguais$valor)))

    # O ranking da macrorregião é calculado dentro de cada UF e macro
    macro <- base[base$sigla_uf == "RO", ]
    macro <- macro[macro$macro_r_saude == macro$macro_r_saude[1], ]
    expect_equal(
      macro$pos_macro,
      rank(macro$valor, ties.method = "min", na.last = "keep")
    )
    expect_equal(unique(macro$total_macro), sum(!is.na(macro$valor)))
  }
})

test_that("o resumo do município alimenta o palco com índice, rankings e blocos", {
  dados <- dados_vidas()
  ano_ref <- max(dados$anos)
  cod <- municipio_padrao(dados)

  # Conferindo o que o palco exibe contra a tabela do ano
  linha <- valores_ano(dados, ano_ref, "indice_final")
  linha <- linha[linha$codmunres == cod, ]
  # O município padrão é o de menor Índice VIDAS do último ano
  expect_equal(linha$pos_nac, 1)

  municipio <- shiny::reactiveVal(cod)
  shiny::testServer(
    mod_como_server,
    args = list(
      dados = dados,
      municipio = municipio,
      ano = shiny::reactiveVal(max(dados$anos))
    ),
    {
      session$setInputs(ano = as.character(ano_ref))
      # Convertendo a árvore de tags do palco em um texto único para conferir
      palco <- paste(as.character(output$palco_principal$html), collapse = "\n")

      # O placar mostra o valor e a categoria do índice final
      expect_true(grepl(formatar_numero(linha$valor), palco, fixed = TRUE))
      expect_true(grepl(as.character(linha$categoria), palco, fixed = TRUE))
      # Os três rankings aparecem com a leitura da posição na tabela do ano
      partes_macro <- partes_ranking(linha$pos_macro, linha$total_macro)
      partes_uf <- partes_ranking(linha$pos_uf, linha$total_uf)
      partes_nac <- partes_ranking(linha$pos_nac, linha$total_nac)
      expect_true(grepl(partes_macro$destaque, palco, fixed = TRUE))
      expect_true(grepl(partes_macro$complemento, palco, fixed = TRUE))
      expect_true(grepl(partes_uf$destaque, palco, fixed = TRUE))
      expect_true(grepl(partes_uf$complemento, palco, fixed = TRUE))
      expect_true(grepl(partes_nac$destaque, palco, fixed = TRUE))
      expect_true(grepl(partes_nac$complemento, palco, fixed = TRUE))

      # Os seis blocos da pétala vêm na ordem configurada e com o valor real
      for (i in seq_len(nrow(BLOCOS))) {
        base_bloco <- valores_ano(dados, ano_ref, BLOCOS$medida[i])
        base_bloco <- base_bloco[base_bloco$codmunres == cod, ]
        expect_true(grepl(BLOCOS$nome[i], palco, fixed = TRUE))
        expect_true(grepl(formatar_numero(base_bloco$valor), palco, fixed = TRUE))
      }

      # Ativando a comparação, o segundo palco mostra o valor do comparado
      comparado <- dados$municipios$codmunres[dados$municipios$codmunres != cod][1]
      linha_comp <- valores_ano(dados, ano_ref, "indice_final")
      linha_comp <- linha_comp[linha_comp$codmunres == comparado, ]
      session$setInputs(comparar = as.character(comparado))
      palco_comp <- paste(as.character(output$palco_comparado$html), collapse = "\n")
      expect_true(grepl(formatar_numero(linha_comp$valor), palco_comp, fixed = TRUE))
      expect_true(grepl("Município comparado", palco_comp, fixed = TRUE))
    }
  )
})

test_that("o palco fica vazio quando o município não tem dado no ano", {
  dados <- dados_vidas()

  # Município com ano faltante (Borá em 2023)
  lacuna <- dados$series[is.na(dados$series$indice_final), c("codmunres", "ano")][1, ]

  municipio <- shiny::reactiveVal(lacuna$codmunres)
  shiny::testServer(
    mod_como_server,
    args = list(
      dados = dados,
      municipio = municipio,
      ano = shiny::reactiveVal(max(dados$anos))
    ),
    {
      session$setInputs(ano = as.character(lacuna$ano))
      # Sem resumo no ano, o palco cai no estado vazio no lugar do perfil
      palco <- paste(as.character(output$palco_principal$html), collapse = "\n")
      expect_true(grepl("não possui dados no ano selecionado", palco, fixed = TRUE))
      expect_false(grepl("perfil-indice", palco, fixed = TRUE))
      expect_false(grepl("perfil-rankings", palco, fixed = TRUE))
    }
  )
})

test_that("series_municipio monta as medidas e os indicadores em colunas", {
  dados <- dados_vidas()
  cod <- dados$municipios$codmunres[1]

  colunas_esperadas <- c(
    "ano", MEDIDAS$medida,
    intersect(INDICADORES$indicador, names(dados$series))
  )
  series <- series_municipio(dados, cod)
  expect_equal(names(series), colunas_esperadas)
  expect_equal(nrow(series), length(dados$anos))
  expect_true(series_tem_valor(series))

  # Município fora da base não tem linhas na tabela pronta de séries
  vazio <- series_municipio(dados, 999999)
  expect_equal(names(vazio), colunas_esperadas)
  expect_equal(nrow(vazio), 0)
  expect_false(series_tem_valor(vazio))

  # O município com ano faltante mantém a linha do ano, mas com NA
  lacuna <- dados$series[is.na(dados$series$indice_final), c("codmunres", "ano")][1, ]
  serie_lacuna <- series_municipio(dados, lacuna$codmunres)
  expect_true(is.na(serie_lacuna$indice_final[serie_lacuna$ano == lacuna$ano]))
})

test_that("grafico_evolucao destaca a série principal com área chapada e sem rótulo na linha", {
  # Sem comparação existe apenas a série principal, com a cor da medida
  grafico <- grafico_evolucao(series_teste, "indice_final", nome = "Dois (RO)")
  expect_length(grafico$x$opts$series, 1)
  serie <- grafico$x$opts$series[[1]]
  expect_equal(serie$name, "Dois (RO)")
  expect_equal(serie$itemStyle$color, cor_medida("indice_final"))
  expect_equal(serie$lineStyle$type, "solid")
  expect_true(serie$showSymbol)
  # A bolinha do índice fica no meio do caminho entre os dois tamanhos antigos
  expect_equal(serie$symbolSize, 7)
  # Sem contorno na bolinha, a linha segue contínua por dentro do marcador
  expect_null(serie$itemStyle$borderColor)

  # A área sob a linha é chapada, na cor da série, com a opacidade configurada
  expect_equal(serie$areaStyle$color, cor_medida("indice_final"))
  expect_equal(serie$areaStyle$opacity, OPACIDADE_AREA_EVOLUCAO)

  # O nome da localidade saiu do fim da linha: quem identifica é a seção
  expect_null(serie$endLabel)
  expect_false(isTRUE(grafico$x$opts$legend$show))

  # O eixo X precisa formatar os anos como inteiros, sem separador de milhar
  formatter <- grafico$x$opts$xAxis[[1]]$axisLabel$formatter
  expect_s3_class(formatter, "JS_EVAL")
  expect_true(grepl("Math.round", as.character(formatter)))

  # O eixo Y fecha em cinco marcações inteiras ao redor da própria medida
  expect_equal(grafico$x$opts$yAxis[[1]]$min, 70)
  expect_equal(grafico$x$opts$yAxis[[1]]$max, 90)
  expect_equal(grafico$x$opts$yAxis[[1]]$interval, 5)
  expect_equal(
    (grafico$x$opts$yAxis[[1]]$max - grafico$x$opts$yAxis[[1]]$min) /
      grafico$x$opts$yAxis[[1]]$interval,
    MARCACOES_EIXO - 1
  )

  # O módulo pode impor uma faixa compartilhada na comparação
  compartilhado <- grafico_evolucao(
    series_teste, "indice_final",
    limites = list(min = 60, max = 100, passo = 10)
  )
  expect_equal(compartilhado$x$opts$yAxis[[1]]$min, 60)
  expect_equal(compartilhado$x$opts$yAxis[[1]]$max, 100)

  # Uma série constante abre folga para o eixo não degenerar
  constante <- series_teste
  constante$indice_final <- c(80, 80)
  degenerado <- grafico_evolucao(constante, "indice_final")
  expect_equal(degenerado$x$opts$yAxis[[1]]$min, 70)
  expect_equal(degenerado$x$opts$yAxis[[1]]$max, 90)

  # O desenho em SVG evita o borrão do canvas sob zoom ou escala fracionária
  expect_equal(grafico$x$renderer, "svg")

  # Os rótulos de ano giram conforme a largura do cartão no cliente
  hook <- as.character(grafico$jsHooks$render[[1]]$code)
  expect_match(hook, "getBoundingClientRect")
  expect_match(hook, "setOption")
  expect_match(hook, "rotate: estreito ? 45 : 0", fixed = TRUE)
  expect_match(hook, as.character(LARGURA_ROTULOS_ANOS), fixed = TRUE)
  expect_match(hook, "addEventListener('resize'", fixed = TRUE)

  # O tooltip mostra apenas o ano e cada localidade com a marca da série
  tooltip <- as.character(grafico$x$opts$tooltip$formatter)
  expect_true(grepl("Math.round", tooltip))
  expect_true(grepl("repeating-linear-gradient", tooltip, fixed = TRUE))
  expect_true(grepl("seriesIndex", tooltip, fixed = TRUE))
  expect_true(grepl("space-between", tooltip, fixed = TRUE))
  # A marca usa a própria cor da linha, sem clareamento para a comparação
  expect_false(grepl("clarear", tooltip, fixed = TRUE))
  expect_false(grepl("rgba(", tooltip, fixed = TRUE))
  # A bolinha da principal funde com o traço: sem halo branco separando os dois
  expect_false(grepl("0 0 0 1.5px #FFFFFF", tooltip, fixed = TRUE))
  # Com as duas séries no mesmo ano, o tooltip fecha a diferença entre elas,
  # sem sufixo de unidade e em tom mais suave que o valor da série
  expect_true(grepl("Diferença", tooltip, fixed = TRUE))
  expect_false(grepl("pts", tooltip, fixed = TRUE))
  expect_true(grepl("color:#5A6472;font-weight:600", tooltip, fixed = TRUE))
  expect_false(grepl("Índice VIDAS", tooltip, fixed = TRUE))

  # O tooltip acompanha o cursor com transição mais curta que o padrão do echarts
  expect_equal(grafico$x$opts$tooltip$transitionDuration, 0.3)
  expect_equal(grafico$x$opts$tooltip$trigger, "axis")
})

test_that("grafico_evolucao diferencia a comparação pelo traço e pelo símbolo vazado", {
  comparacao <- series_teste
  comparacao$bloco1 <- c(40, 90)
  grafico <- grafico_evolucao(
    series_teste, "bloco1",
    nome = "Dois (RO)",
    comparacao = comparacao,
    nome_comparacao = "Quatro (SP)"
  )

  # As duas localidades usam a mesma cor, com o amarelo do Social escurecido
  expect_length(grafico$x$opts$series, 2)
  linha_principal <- grafico$x$opts$series[[1]]
  linha_comparada <- grafico$x$opts$series[[2]]
  expect_equal(linha_comparada$name, "Quatro (SP)")
  expect_equal(linha_principal$lineStyle$color, COR_LINHA_SOCIAL)
  expect_equal(linha_comparada$lineStyle$color, COR_LINHA_SOCIAL)
  expect_equal(linha_principal$lineStyle$type, "solid")
  # A comparação tem traço tracejado longo, com pontas arredondadas
  expect_equal(linha_comparada$lineStyle$type, c(9, 7))
  expect_equal(linha_comparada$lineStyle$cap, "round")
  expect_true(linha_comparada$z < linha_principal$z)

  # As bolinhas ficam sempre visíveis, no mesmo tamanho nas duas séries
  expect_true(linha_principal$showSymbol)
  expect_equal(linha_principal$symbolSize, 5.5)
  expect_equal(linha_comparada$symbolSize, 5.5)
  expect_equal(linha_principal$itemStyle$color, COR_LINHA_SOCIAL)
  # A bolinha principal não tem contorno, para a linha seguir contínua por dentro
  expect_null(linha_principal$itemStyle$borderColor)
  # A da comparação é vazada, com o miolo branco e o anel na cor da linha
  expect_true(linha_comparada$showSymbol)
  expect_equal(linha_comparada$itemStyle$color, "#FFFFFF")
  expect_equal(linha_comparada$itemStyle$borderColor, COR_LINHA_SOCIAL)

  # As duas áreas são chapadas, na cor da série, com a opacidade configurada
  expect_equal(linha_principal$areaStyle$color, COR_LINHA_SOCIAL)
  expect_equal(linha_principal$areaStyle$opacity, OPACIDADE_AREA_EVOLUCAO)
  expect_equal(linha_comparada$areaStyle$color, COR_LINHA_SOCIAL)
  expect_equal(linha_comparada$areaStyle$opacity, OPACIDADE_AREA_EVOLUCAO)

  # As linhas não projetam sombra
  expect_null(linha_principal$lineStyle$shadowBlur)
  expect_null(linha_comparada$lineStyle$shadowBlur)

  # Nenhuma série leva rótulo no fim da linha
  expect_null(linha_principal$endLabel)
  expect_null(linha_comparada$endLabel)

  # Nenhuma série apaga a outra no hover (sem foco de série no destaque)
  expect_null(linha_principal$emphasis)
  expect_null(linha_comparada$emphasis)
})

test_that("os limites das medidas fecham o eixo em cinco marcações inteiras", {
  # O índice de teste vai de 70 a 90, então o eixo fecha em 70..90 de 5 em 5
  limites <- limites_medidas(series_teste, "indice_final")
  expect_equal(limites$min, 70)
  expect_equal(limites$max, 90)
  expect_equal(limites$passo, 5)

  # Os seis blocos compartilham a faixa inteira dos valores (25 a 85)
  limites <- limites_medidas(series_teste, BLOCOS$medida)
  expect_equal((limites$max - limites$min) / limites$passo, MARCACOES_EIXO - 1)
  expect_lte(limites$min, 25)
  expect_gte(limites$max, 85)

  # Uma série constante abre folga para o eixo não degenerar
  constante <- series_teste
  constante$indice_final <- c(80, 80)
  limites <- limites_medidas(constante, "indice_final")
  expect_equal(limites$min, 70)
  expect_equal(limites$max, 90)

  # O topo do eixo nunca passa dos 100 do percentil
  alto <- series_teste
  alto[, MEDIDAS$medida] <- 100
  limites <- limites_medidas(alto, MEDIDAS$medida)
  expect_lte(limites$max, 100)
  expect_equal((limites$max - limites$min) / limites$passo, MARCACOES_EIXO - 1)

  # Uma série que usa todo o percentil fecha em 0..100 de 25 em 25
  extremos <- series_teste
  extremos[, MEDIDAS$medida] <- 0
  extremos$bloco1 <- c(0, 100)
  expect_equal(
    limites_medidas(extremos, BLOCOS$medida),
    list(min = 0, max = 100, passo = 25)
  )

  # Série sem valor algum mantém a escala completa do índice
  vazio <- series_teste
  vazio[, MEDIDAS$medida] <- NA_real_
  expect_equal(
    limites_medidas(vazio, MEDIDAS$medida),
    list(min = 0, max = 100, passo = 25)
  )
})

test_that("a evolução usa limites de eixo por grupo de medidas", {
  dados <- dados_vidas()
  principal <- municipio_padrao(dados)
  comparado <- dados$municipios$codmunres[dados$municipios$codmunres != principal][1]
  ano_ref <- max(dados$anos)

  # Calculando os limites esperados para conferir o que o módulo entrega
  series_principal_ref <- series_municipio(dados, principal)
  series_comparacao_ref <- series_municipio(dados, comparado)
  limites_indice <- limites_medidas(
    series_principal_ref, "indice_final", series_comparacao_ref
  )

  municipio <- shiny::reactiveVal(principal)
  shiny::testServer(
    mod_como_server,
    args = list(
      dados = dados,
      municipio = municipio,
      ano = shiny::reactiveVal(max(dados$anos))
    ),
    {
      session$setInputs(
        municipio = as.character(principal),
        ano = as.character(ano_ref),
        comparar = as.character(comparado)
      )

      # Lendo as opções diretamente do JSON do widget renderizado
      opcoes_do_grafico <- function(saida) {
        jsonlite::fromJSON(saida, simplifyVector = FALSE)$x$opts
      }

      # O Índice VIDAS tem escala própria, cobrindo os dois índices sem cortá-los
      expect_equal(
        opcoes_do_grafico(output$grafico_indice_final)$yAxis[[1]]$min,
        limites_indice$min
      )
      expect_equal(
        opcoes_do_grafico(output$grafico_indice_final)$yAxis[[1]]$max,
        limites_indice$max
      )
      expect_equal(
        opcoes_do_grafico(output$grafico_indice_final)$yAxis[[1]]$interval,
        limites_indice$passo
      )

      # Os seis blocos compartilham a mesma escala entre os cartões
      min_blocos <- opcoes_do_grafico(output$grafico_bloco1)$yAxis[[1]]$min
      max_blocos <- opcoes_do_grafico(output$grafico_bloco1)$yAxis[[1]]$max
      intervalo_blocos <- opcoes_do_grafico(output$grafico_bloco1)$yAxis[[1]]$interval
      # Todos os cartões de bloco desenham cinco marcações equiespaçadas
      expect_equal((max_blocos - min_blocos) / intervalo_blocos, MARCACOES_EIXO - 1)
      for (medida in BLOCOS$medida[-1]) {
        opcoes <- opcoes_do_grafico(output[[paste0("grafico_", medida)]])
        expect_equal(opcoes$yAxis[[1]]$min, min_blocos)
        expect_equal(opcoes$yAxis[[1]]$max, max_blocos)
        expect_equal(opcoes$yAxis[[1]]$interval, intervalo_blocos)
      }

      # Cada gráfico desenha a localidade principal e a comparação
      series_bloco <- opcoes_do_grafico(output$grafico_bloco1)$series
      expect_length(series_bloco, 2)
      # A comparação repete a cor da principal, com tracejado longo e bolinha vazada
      expect_equal(
        series_bloco[[2]]$lineStyle$color,
        series_bloco[[1]]$lineStyle$color
      )
      expect_equal(series_bloco[[2]]$lineStyle$type, list(9, 7))
      expect_equal(series_bloco[[2]]$itemStyle$color, "#FFFFFF")

      # A identificação reúne os dois municípios, sem separador nem período
      identificacao <- as.character(output$evolucao_identificacao$html)
      expect_true(grepl(nome_municipio(dados, principal), identificacao, fixed = TRUE))
      expect_true(grepl(nome_municipio(dados, comparado), identificacao, fixed = TRUE))
      expect_false(grepl("evolucao-identificacao__periodo", identificacao, fixed = TRUE))
      expect_false(grepl("evolucao-identificacao__separador", identificacao, fixed = TRUE))
      # Cada nome vem com a amostra do traço e da bolinha usados no próprio gráfico
      expect_true(grepl(
        "evolucao-identificacao__amostra--comparacao",
        identificacao,
        fixed = TRUE
      ))

      # A identificação se repete abaixo do título dos blocos e do seletor
      identificacao_blocos <- as.character(output$evolucao_identificacao_blocos$html)
      expect_true(grepl(nome_municipio(dados, principal), identificacao_blocos, fixed = TRUE))
      expect_true(grepl(nome_municipio(dados, comparado), identificacao_blocos, fixed = TRUE))
      identificacao_indicadores <- as.character(output$indicadores_identificacao$html)
      expect_true(grepl(nome_municipio(dados, principal), identificacao_indicadores, fixed = TRUE))
      expect_true(grepl(nome_municipio(dados, comparado), identificacao_indicadores, fixed = TRUE))

      # Sem comparação o eixo do Índice VIDAS segue apenas o município principal
      session$setInputs(comparar = "nenhum")
      limites_so_principal <- limites_medidas(series_principal_ref, "indice_final")
      expect_equal(
        opcoes_do_grafico(output$grafico_indice_final)$yAxis[[1]]$min,
        limites_so_principal$min
      )
      expect_equal(
        opcoes_do_grafico(output$grafico_indice_final)$yAxis[[1]]$max,
        limites_so_principal$max
      )
      expect_length(opcoes_do_grafico(output$grafico_bloco1)$series, 1)

      # A identificação cita apenas o município principal
      identificacao <- as.character(output$evolucao_identificacao$html)
      expect_true(grepl(nome_municipio(dados, principal), identificacao, fixed = TRUE))
      expect_false(grepl(nome_municipio(dados, comparado), identificacao, fixed = TRUE))
      # Sem comparação não existe amostra tracejada na identificação
      expect_false(grepl(
        "evolucao-identificacao__amostra--comparacao",
        identificacao,
        fixed = TRUE
      ))

      # Com o principal sem dado, os gráficos ficam suspensos na grade
      session$setInputs(comparar = as.character(comparado), municipio = "999999")
      expect_error(output$grafico_indice_final, class = "shiny.silent.error")
      expect_error(output$evolucao_identificacao, class = "shiny.silent.error")
    }
  )
})

test_that("os títulos da evolução ficam só com o texto, sem bolinha de cor", {
  grade <- as.character(grade_evolucao_ui(shiny::NS("como")))
  # Os sete títulos continuam na grade, apenas como texto
  expect_true(grepl("Índice VIDAS", grade, fixed = TRUE))
  expect_true(grepl("Dimensões do Índice VIDAS", grade, fixed = TRUE))
  # A bolinha colorida e a variável de cor dela saíram dos cartões
  expect_false(grepl("evolucao-card__ponto", grade, fixed = TRUE))
  expect_false(grepl("--cor-medida", grade, fixed = TRUE))
  # O título dos blocos fica agrupado com a identificação dos municípios
  expect_true(grepl("evolucao-grade__cabecalho", grade, fixed = TRUE))
})

test_that("formatadores usam a convenção brasileira", {
  expect_equal(formatar_numero(12.345), "12,3")
  expect_equal(formatar_numero(c(1.5, NA)), c("1,5", "Sem dados"))
  expect_equal(formatar_inteiro(5570), "5.570")
  expect_equal(rotulo_posicao(1234, 5570), "1.234 de 5.570")
  # Todos os valores do painel são exibidos com uma casa decimal
  expect_equal(formatar_numero(99.96), "100,0")
  expect_equal(formatar_numero(0.04), "0,0")
})

test_that("frase_percentil mostra a parcela de municípios abaixo", {
  expect_match(
    frase_percentil(99.96),
    "Maior VIDA que 100,0% dos municípios brasileiros",
    fixed = TRUE
  )
  expect_match(
    frase_percentil(50),
    "Maior VIDA que 50,0% dos municípios brasileiros",
    fixed = TRUE
  )
  expect_match(
    frase_percentil(40),
    "Maior VIDA que 40,0% dos municípios brasileiros",
    fixed = TRUE
  )
  expect_match(frase_percentil(NA), "Sem dado")
})

test_that("frase_percentil destaca o melhor e o pior município", {
  # A posição 1 é o menor VIDA do ranking
  expect_match(
    frase_percentil(0, pos_nac = 1, total_nac = 5570),
    "Menor VIDA entre todos os municípios brasileiros",
    fixed = TRUE
  )
  # A última posição é o maior VIDA do ranking
  expect_match(
    frase_percentil(100, pos_nac = 5570, total_nac = 5570),
    "Maior VIDA entre todos os municípios brasileiros",
    fixed = TRUE
  )
  # As posições intermediárias mantêm a leitura do percentil
  expect_match(
    frase_percentil(50, pos_nac = 3000, total_nac = 5570),
    "Maior VIDA que 50,0% dos municípios brasileiros",
    fixed = TRUE
  )
})

test_that("posicao_trilho distribui a posição do pior ao melhor", {
  expect_equal(posicao_trilho(1, 100), 0)
  expect_equal(posicao_trilho(100, 100), 100)
  expect_equal(posicao_trilho(50, 100), round(100 * 49 / 99, 6))
  # Com um único município, o ponto fica no extremo do melhor
  expect_equal(posicao_trilho(1, 1), 100)
  expect_equal(posicao_trilho(NA, 100), 100)
})

test_that("frase_ranking descreve a posição no ranking", {
  expect_equal(frase_ranking(1, 21), "Menor VIDA entre 21 municípios")
  expect_equal(frase_ranking(21, 21), "Maior VIDA entre 21 municípios")
  expect_equal(frase_ranking(12, 21), "12ª menor VIDA entre 21 municípios")
  # O plural se ajusta quando o escopo tem um único município
  expect_equal(frase_ranking(1, 1), "Menor VIDA entre 1 município")
  expect_equal(frase_ranking(NA, 21), "Sem dados")
})

test_that("regua_indice monta as cinco categorias e o marcador", {
  html <- as.character(regua_indice(27.8))
  # A régua desenha as cinco faixas da mais clara para a mais escura
  expect_equal(
    lengths(regmatches(html, gregexpr('class="perfil-indice__faixa"', html, fixed = TRUE))),
    5
  )
  expect_true(grepl("left:27.8%;", html, fixed = TRUE))
  expect_true(grepl("0 · muito baixo", html, fixed = TRUE))
  expect_true(grepl("100 · muito alto", html, fixed = TRUE))
})

test_that("tooltip_indice reúne valor, categoria e leitura do percentil", {
  resumo <- list(
    valor = 27.8, categoria = "Baixo",
    pos_nac = 3000, total_nac = 5570
  )
  html <- tooltip_indice(resumo)
  expect_true(grepl("Índice VIDAS", html, fixed = TRUE))
  expect_true(grepl("27,8", html, fixed = TRUE))
  expect_true(grepl("Baixo", html, fixed = TRUE))
  expect_true(grepl(
    "Maior VIDA que 27,8% dos municípios brasileiros",
    html,
    fixed = TRUE
  ))
})

test_that("contexto_tooltip monta o rodapé discreto", {
  expect_equal(contexto_tooltip(NULL), "")
  expect_equal(contexto_tooltip(""), "")
  html <- contexto_tooltip("Jutaí (AM) · 2024")
  expect_true(grepl("tooltip-petala__contexto", html, fixed = TRUE))
  expect_true(grepl("Jutaí (AM) · 2024", html, fixed = TRUE))
})

test_that("grafico_barras_blocos preenche o valor e deixa o restante em cinza", {
  blocos <- data.frame(
    medida = BLOCOS$medida,
    nome = BLOCOS$nome,
    valor = c(0, 25, 50, 75, 100, NA),
    categoria = rep("Médio", 6),
    cor = BLOCOS$cor,
    pos_nac = 1:6,
    total_nac = rep(100, 6),
    stringsAsFactors = FALSE
  )
  html <- as.character(grafico_barras_blocos(blocos))
  # As seis linhas de barra aparecem na ordem dos blocos, sem o título da linha
  expect_false(grepl("Resultado por dimensão", html, fixed = TRUE))
  expect_false(grepl("resultado-blocos__ponto", html, fixed = TRUE))
  expect_equal(
    lengths(regmatches(html, gregexpr("resultado-blocos__linha", html, fixed = TRUE))),
    6
  )
  # Cada barra ganha a mesma tooltip das pétalas, acessível por teclado
  expect_equal(
    lengths(regmatches(html, gregexpr('data-bs-toggle="tooltip"', html, fixed = TRUE))),
    6
  )
  expect_equal(
    lengths(regmatches(html, gregexpr('tabindex="0"', html, fixed = TRUE))),
    6
  )
  expect_true(grepl("tooltip-petala__marca", html, fixed = TRUE))
  expect_true(grepl("Prioridade", html, fixed = TRUE))
  # O preenchimento usa a cor do bloco e a largura do valor
  expect_true(grepl("width:0.0%;background:#FAC80F", html, fixed = TRUE))
  expect_true(grepl("width:100.0%;background:#1E5AA0", html, fixed = TRUE))
  # O valor ausente não preenche a barra e aparece como "Sem dados"
  expect_true(grepl("width:0.0%;background:#00A6A6", html, fixed = TRUE))
  expect_true(grepl("Sem dados", html, fixed = TRUE))
  # Cada valor tem a escala "de 100" em texto discreto ao lado
  expect_equal(
    lengths(regmatches(
      html,
      gregexpr('class="resultado-blocos__escala"', html, fixed = TRUE)
    )),
    5
  )
  # Nada relacionado à mediana do Brasil é exibido
  expect_false(grepl("mediana", html, ignore.case = TRUE))
})

test_that("paletas e cores seguem a configuração do projeto", {
  expect_setequal(names(PALETAS), MEDIDAS$medida)
  expect_equal(cor_medida("bloco1"), BLOCOS$cor[1])
  expect_equal(cor_medida("indice_final"), COR_VIDAS)
  expect_equal(cor_categoria(NA_character_), COR_SEM_DADOS)
  expect_equal(cor_texto_sobre("#FFFFFF"), COR_AZUL_ESCURO)
  expect_equal(cor_texto_sobre("#0A1E3C"), "#FFFFFF")

  # A rampa de um bloco deve ter cinco tons distintos
  rampa <- unname(PALETAS[["bloco3"]])
  expect_length(rampa, 5)
  expect_equal(length(unique(rampa)), 5)
})

test_that("opções de medida, ano e escopo do ranking estão completas", {
  exigir_pipeline()
  # As medidas do seletor são o dicionário central, com o prefixo "Dimensão" nos rótulos
  expect_equal(MEDIDAS$rotulo[-1], paste("Dimensão", MEDIDAS$nome[-1]))
  expect_equal(dados_vidas()$anos, sort(unique(indice_referencia$ano)))

  # Conferindo as opções do seletor de escopo embutidas na própria seção Onde?
  ui <- as.character(mod_onde_ui("onde"))
  json <- regmatches(
    ui,
    regexpr('data-for="onde-escopo">\\{.*?\\}</script>', ui, perl = TRUE)
  )
  json <- sub('data-for="onde-escopo">', "", json, fixed = TRUE)
  json <- sub("</script>$", "", json)
  opcoes <- jsonlite::fromJSON(json)$data
  # O Brasil vem primeiro e as 27 UFs completam as opções do escopo
  expect_equal(opcoes$value[1], "nacional")
  expect_equal(nrow(opcoes), 28)
  siglas_uf <- unique(dados_vidas()$municipios$sigla_uf)
  expect_setequal(opcoes$value[-1], siglas_uf)
})

test_that("nome_medida prefixa as dimensões com Dimensão quando pedido", {
  # O Índice VIDAS nunca recebe o prefixo
  expect_equal(nome_medida("indice_final", prefixo_bloco = TRUE), "Índice VIDAS")
  expect_equal(
    nome_medida("bloco2", prefixo_bloco = TRUE),
    "Dimensão Planejamento Reprodutivo"
  )
  # Sem o prefixo, os nomes continuam como configurados
  expect_equal(
    nome_medida(c("indice_final", "bloco2")),
    c("Índice VIDAS", "Planejamento Reprodutivo")
  )
})

test_that("tema_reactable adapta os destaques à cor da medida", {
  # No Índice VIDAS os destaques continuam roxos e com texto branco
  vidas <- tema_reactable("indice_final")
  expect_equal(vidas$highlightColor, misturar_cores(COR_VIDAS, "#FFFFFF", 0.94))
  expect_equal(
    vidas$rowSelectedStyle$backgroundColor,
    misturar_cores(COR_VIDAS, "#FFFFFF", 0.90)
  )
  expect_equal(vidas$pageButtonActiveStyle$backgroundColor, COR_VIDAS)
  expect_equal(vidas$pageButtonActiveStyle$color, "#FFFFFF")

  # Em um bloco, hover, linha selecionada e paginação usam a cor do bloco
  bloco <- tema_reactable("bloco1")
  base <- cor_medida("bloco1")
  expect_equal(bloco$highlightColor, misturar_cores(base, "#FFFFFF", 0.94))
  expect_equal(
    bloco$rowSelectedStyle$backgroundColor,
    misturar_cores(base, "#FFFFFF", 0.90)
  )
  expect_true(grepl(base, bloco$rowSelectedStyle$boxShadow, fixed = TRUE))
  expect_equal(
    bloco$pageButtonHoverStyle$backgroundColor,
    misturar_cores(base, "#FFFFFF", 0.94)
  )
  expect_equal(bloco$pageButtonActiveStyle$backgroundColor, base)
  # O amarelo do bloco Social pede texto escuro no botão de página ativo
  expect_equal(bloco$pageButtonActiveStyle$color, COR_AZUL_ESCURO)
  # A cor de hover também viaja como variável CSS usada pelas linhas com coluna fixa
  expect_equal(
    bloco$style[["--cor-hover-ranking"]],
    misturar_cores(base, "#FFFFFF", 0.94)
  )
  expect_equal(
    bloco$style[["--cor-selecao-ranking"]],
    misturar_cores(base, "#FFFFFF", 0.90)
  )
})

test_that("o ranking marca o município em foco na montagem e mantém o foco", {
  dados <- dados_vidas()
  ano <- max(dados$anos)
  foco <- municipio_padrao(dados)

  # Ordenando os rankings como o módulo faz, do menor para o maior Índice VIDAS
  base_indice <- valores_ano(dados, ano, "indice_final")
  ranking_indice <- base_indice[order(base_indice$valor, decreasing = FALSE, na.last = TRUE), ]
  outro <- ranking_indice$codmunres[2]

  # Escolhendo uma UF que não contém o segundo colocado
  uf_outro <- dados$municipios$sigla_uf[dados$municipios$codmunres == outro]
  uf_fora <- setdiff(dados$municipios$sigla_uf, uf_outro)[1]

  municipio <- shiny::reactiveVal(foco)
  chamadas <- new.env(parent = emptyenv())
  chamadas$registro <- list()

  # Capturando as chamadas de atualização do reactable sem depender do cliente
  testthat::local_mocked_bindings(
    updateReactable = function(outputId, selected = NULL, page = NULL, ...) {
      chamadas$registro[[length(chamadas$registro) + 1]] <- list(
        selected = selected, page = page
      )
      invisible(NULL)
    },
    .package = "reactable"
  )

  shiny::testServer(
    mod_onde_server,
    args = list(
      dados = dados,
      municipio = municipio,
      ano = shiny::reactiveVal(max(dados$anos))
    ),
    {
      # Lendo o destaque marcado já na montagem do widget (índice 0-based)
      destaque_do_render <- function() {
        widget <- jsonlite::fromJSON(output$ranking, simplifyVector = FALSE)
        unlist(widget$x$tag$attribs$defaultSelected)
      }

      session$setInputs(
        ano = as.character(ano()),
        medida = "indice_final",
        escopo = "nacional"
      )
      # O município padrão abre o ranking do índice e já vem marcado no próprio render
      expect_equal(destaque_do_render(), 0)

      # Trocando o município em foco fora da tabela, a seleção acompanha
      municipio(outro)
      session$flushReact()
      ultima <- tail(chamadas$registro, 1)[[1]]
      expect_equal(ultima$selected, which(ranking_indice$codmunres == outro))

      # Ao trocar a dimensão, o foco é mantido porque segue no ranking
      session$setInputs(medida = "bloco6")
      session$flushReact()
      expect_equal(municipio(), outro)

      base_bloco <- valores_ano(dados, ano(), "bloco6")
      ranking_bloco <- base_bloco[order(base_bloco$valor, decreasing = FALSE, na.last = TRUE), ]
      expect_equal(
        destaque_do_render(),
        which(ranking_bloco$codmunres == outro) - 1L
      )

      # Ao mudar o escopo para fora do ranking, o foco vai para o 1º colocado
      session$setInputs(escopo = uf_fora)
      session$flushReact()
      ranking_uf <- ranking_bloco[ranking_bloco$sigla_uf == uf_fora, ]
      expect_equal(municipio(), ranking_uf$codmunres[1])
      expect_equal(destaque_do_render(), 0)

      # Voltando ao Brasil, o foco é mantido porque segue no ranking
      session$setInputs(escopo = "nacional")
      session$flushReact()
      expect_equal(municipio(), ranking_uf$codmunres[1])
      expect_equal(
        destaque_do_render(),
        which(ranking_bloco$codmunres == ranking_uf$codmunres[1]) - 1L
      )

      # Quando a seleção chega fora da página exibida, a tabela salta para ela
      session$setInputs(`ranking__reactable__selected` = 22L, `ranking__reactable__page` = 1L)
      ultima <- tail(chamadas$registro, 1)[[1]]
      expect_null(ultima$selected)
      expect_equal(ultima$page, 2)

      # A linha escolhida na tabela vira o município em foco
      foco_clique <- ranking_bloco$codmunres[22]
      expect_equal(municipio(), foco_clique)

      # Ao limpar a busca da tabela, a página volta para o município em foco
      chamadas$registro <- list()
      session$setInputs(`ranking_busca_limpa` = 1)
      expect_length(chamadas$registro, 1)
      expect_null(chamadas$registro[[1]]$selected)
      expect_equal(
        chamadas$registro[[1]]$page,
        ceiling(which(ranking_bloco$codmunres == foco_clique) / 12)
      )
    }
  )
})

test_that("o ranking explica a primeira posição e resume acima da tabela", {
  ui <- as.character(mod_onde_ui("onde"))
  # O título da seção fala em desafios, e não em valores baixos
  expect_true(grepl("Onde o Índice VIDAS revela maiores desafios?", ui, fixed = TRUE))
  # A descrição padrão já vem carregada no HTML, antes do output dos blocos
  expect_true(grepl("ranking-descricao__padrao", ui, fixed = TRUE))
  expect_true(grepl(
    "A primeira posição indica o município com menor Índice VIDAS",
    ui,
    fixed = TRUE
  ))
  posicao_output <- regexpr('id="onde-ranking_descricao"', ui, fixed = TRUE)
  posicao_padrao <- regexpr("ranking-descricao__padrao", ui, fixed = TRUE)
  expect_true(posicao_output < posicao_padrao)
  # O resumo fica logo acima da tabela, com a classe própria
  expect_true(grepl("ranking-resumo", ui, fixed = TRUE))
  posicao_resumo <- regexpr("ranking-resumo", ui, fixed = TRUE)
  posicao_tabela <- regexpr('id="onde-ranking"', ui, fixed = TRUE)
  expect_true(posicao_resumo < posicao_tabela)
  # A antiga dica de clique e a nota de rodapé saíram do bloco
  expect_false(grepl("bloco-descricao--tabela", ui, fixed = TRUE))
  expect_false(grepl("bloco-nota", ui, fixed = TRUE))
})

test_that("a descrição e a legenda acompanham a medida escolhida", {
  dados <- dados_vidas()
  municipio <- shiny::reactiveVal(municipio_padrao(dados))
  shiny::testServer(
    mod_onde_server,
    args = list(
      dados = dados,
      municipio = municipio,
      ano = shiny::reactiveVal(max(dados$anos))
    ),
    {
      session$setInputs(
        ano = as.character(max(dados$anos)),
        medida = "indice_final",
        escopo = "nacional"
      )
      # No índice, o output fica vazio e a descrição padrão do HTML permanece
      expect_null(output$ranking_descricao)
      legenda <- as.character(output$legenda$html)
      expect_true(grepl("Nível do Índice VIDAS", legenda, fixed = TRUE))

      # Trocando para um bloco, a descrição e a legenda acompanham a medida
      session$setInputs(medida = "bloco3")
      texto <- as.character(output$ranking_descricao$html)
      expect_true(grepl("menor valor na Dimensão Pré-natal", texto, fixed = TRUE))
      legenda <- as.character(output$legenda$html)
      expect_true(grepl("Nível da Dimensão Pré-natal", legenda, fixed = TRUE))
    }
  )
})

test_that("o ano compartilhado mantém os seletores sincronizados", {
  dados <- dados_vidas()
  municipio <- shiny::reactiveVal(municipio_padrao(dados))
  ano_outro <- min(dados$anos)
  chamadas <- new.env(parent = emptyenv())
  chamadas$anos <- character(0)

  # Capturando as atualizações do seletor sem depender do cliente
  testthat::local_mocked_bindings(
    updateSlimSelect = function(session, inputId, selected = NULL, ...) {
      if (identical(inputId, "ano")) {
        chamadas$anos <- c(chamadas$anos, as.character(selected))
      }
      invisible(NULL)
    },
    .package = "shinyWidgets"
  )

  # Conferindo a sincronização no módulo Onde?
  shiny::testServer(
    mod_onde_server,
    args = list(
      dados = dados,
      municipio = municipio,
      ano = shiny::reactiveVal(max(dados$anos))
    ),
    {
      session$flushReact()
      # O ano compartilhado chega ao seletor já na montagem
      expect_true(as.character(max(dados$anos)) %in% chamadas$anos)
      # A troca no seletor atualiza o estado compartilhado
      session$setInputs(ano = as.character(ano_outro))
      session$flushReact()
      expect_equal(ano(), ano_outro)
      expect_equal(tail(chamadas$anos, 1), as.character(ano_outro))
    }
  )

  # Conferindo a sincronização no módulo Como?
  chamadas$anos <- character(0)
  shiny::testServer(
    mod_como_server,
    args = list(
      dados = dados,
      municipio = municipio,
      ano = shiny::reactiveVal(max(dados$anos))
    ),
    {
      session$flushReact()
      # O ano compartilhado chega ao seletor já na montagem
      expect_true(as.character(max(dados$anos)) %in% chamadas$anos)
      # A troca no seletor atualiza o estado compartilhado
      session$setInputs(ano = as.character(ano_outro))
      session$flushReact()
      expect_equal(ano(), ano_outro)
      expect_equal(tail(chamadas$anos, 1), as.character(ano_outro))
    }
  )
})

test_that("seletor_inline controla a busca e traduz os textos", {
  # O seletor padrão liga a busca e usa os textos em português
  com_busca <- as.character(seletor_inline("teste", c("A" = "a", "B" = "b")))
  expect_true(grepl('"showSearch":true', com_busca, fixed = TRUE))
  expect_true(grepl("Buscar...", com_busca, fixed = TRUE))
  expect_true(grepl("Nenhum resultado", com_busca, fixed = TRUE))
  expect_true(grepl('"searchHighlight":true', com_busca, fixed = TRUE))

  # O seletor sem busca esconde o campo, mantendo as opções intactas
  sem_busca <- as.character(seletor_inline("teste2", c("A" = "a"), busca = FALSE))
  expect_true(grepl('"showSearch":false', sem_busca, fixed = TRUE))
})

test_that("atualizar_municipios envia os dados compactos sem aviso de serialização", {
  # Capturando a mensagem enviada por uma sessão simulada
  capturada <- new.env(parent = emptyenv())
  sessao <- list(sendCustomMessage = function(tipo, mensagem) {
    capturada$tipo <- tipo
    capturada$mensagem <- mensagem
  })
  dados <- dados_vidas()
  malha <- carregar_malha_municipios()
  base <- dados_mapa(dados, max(dados$anos), "indice_final")
  atualizar_municipios(sessao, "mapa", base, "indice_final")

  expect_equal(capturada$tipo, "vidas_mapa_atualiza")
  mensagem <- capturada$mensagem
  # Os dados vão em vetores alinhados à malha, sem HTML de tooltip
  expect_equal(mensagem$id, "mapa")
  expect_equal(mensagem$medida, "Índice VIDAS")
  expect_length(mensagem$municipios, nrow(malha))
  expect_length(mensagem$ufs, nrow(malha))
  expect_length(mensagem$valores, nrow(malha))
  expect_length(mensagem$categorias, nrow(malha))
  expect_equal(mensagem$rotulos, unname(CATEGORIAS))
  expect_false(any(grepl("tooltip-mapa", mensagem$valores)))

  # O toJSON usado pelo Shiny não deve emitir aviso de serialização
  aviso <- NULL
  withCallingHandlers(
    shiny:::toJSON(mensagem),
    warning = function(w) {
      aviso <<- conditionMessage(w)
      invokeRestart("muffleWarning")
    }
  )
  expect_null(aviso)
})

test_that("enviar_desenho_municipios junta o desenho pronto aos dados do mapa", {
  # Capturando a mensagem enviada por uma sessão simulada
  capturada <- new.env(parent = emptyenv())
  sessao <- list(sendCustomMessage = function(tipo, mensagem) {
    capturada$tipo <- tipo
    capturada$mensagem <- mensagem
  })
  dados <- dados_vidas()
  base <- dados_mapa(dados, max(dados$anos), "indice_final")
  enviar_desenho_municipios(sessao, "mapa", base, "indice_final")

  expect_equal(capturada$tipo, "vidas_mapa_desenha")
  mensagem <- capturada$mensagem
  desenho <- carregar_desenho_municipios()
  expect_equal(mensagem$layers, desenho$layers)
  expect_equal(mensagem$pgons, desenho$pgons)
  expect_length(mensagem$valores, length(mensagem$layers))
})

test_that("o desenho pronto da malha casa com a conversão do leaflet", {
  malha <- carregar_malha_municipios()
  desenho <- carregar_desenho_municipios()

  # A malha e o desenho têm os mesmos municípios, na mesma ordem
  expect_equal(desenho$layers, as.character(malha$codmunres))

  # O texto não deve ter coordenadas com mais de 4 casas decimais
  expect_false(grepl("\\.\\d{5,}", desenho$pgons))

  # O JSON bate com o que o leaflet monta para o addPolygons
  referencia <- leaflet::addPolygons(
    leaflet::leaflet(),
    data = malha,
    layerId = ~as.character(codmunres)
  )
  chamada <- Filter(
    function(x) x$method == "addPolygons",
    referencia$x$calls
  )[[1]]
  esperado <- as.character(jsonlite::toJSON(
    chamada$args[[1]],
    dataframe = "columns",
    auto_unbox = TRUE,
    digits = 4
  ))
  expect_equal(desenho$pgons, esperado)
})

test_that("badge_categoria_html gera o HTML dos selos de categoria", {
  selos <- badge_categoria_html(c("Muito baixo", "Muito alto"))
  expect_length(selos, 2)
  expect_true(all(grepl("badge-categoria", selos)))
  expect_true(grepl(PALETAS$indice_final[["Muito alto"]], selos[2]))
})

test_that("dados_mapa alinha os valores à malha em formato compacto", {
  dados <- dados_vidas()
  malha <- carregar_malha_municipios()
  ano <- max(dados$anos)
  base <- dados_mapa(dados, ano, "indice_final")

  # Os dados ficam na ordem das camadas do mapa e sem HTML de tooltip
  expect_equal(nrow(base), nrow(malha))
  expect_setequal(
    names(base),
    c("municipio", "sigla_uf", "valor_texto", "categoria_cod")
  )
  expect_false(any(grepl("tooltip-mapa", base$valor_texto)))
  expect_true(all(base$categoria_cod %in% 1:5))
  expect_false(any(base$valor_texto == "—"))

  # O valor em texto segue a convenção brasileira e a ordem da malha
  valor_tabela <- valores_ano(dados, ano, "indice_final")
  codigo <- valor_tabela$codmunres[1]
  posicao <- match(codigo, malha$codmunres)
  valor_esperado <- formatar_numero(
    valor_tabela$valor[valor_tabela$codmunres == codigo]
  )
  expect_equal(base$valor_texto[posicao], valor_esperado)

  # Municípios sem valor no ano viram "Sem dados" em cinza (Borá/2023)
  base_2023 <- dados_mapa(dados, 2023L, "indice_final")
  bora <- which(malha$codmunres == 350720)
  expect_equal(base_2023$valor_texto[bora], "—")
  expect_true(is.na(base_2023$categoria_cod[bora]))
  expect_equal(base_2023$municipio[bora], "Borá")
})

test_that("mensagem_mapa usa a paleta e as cores de texto da medida exibida", {
  dados <- dados_vidas()
  ano <- max(dados$anos)

  # A mensagem do índice leva a rampa roxa e os textos de contraste
  base_indice <- dados_mapa(dados, ano, "indice_final")
  msg_indice <- mensagem_mapa("mapa", base_indice, "indice_final")
  expect_equal(msg_indice$paleta, unname(PALETAS$indice_final))
  expect_equal(msg_indice$cores_texto, unname(cor_texto_sobre(PALETAS$indice_final)))
  expect_equal(msg_indice$cor_sem_dados, COR_SEM_DADOS)

  # A mensagem de um bloco usa a rampa daquele bloco
  base_bloco <- dados_mapa(dados, ano, "bloco3")
  msg_bloco <- mensagem_mapa("mapa", base_bloco, "bloco3")
  expect_equal(msg_bloco$paleta, unname(PALETAS$bloco3))
  expect_false(identical(msg_bloco$paleta, msg_indice$paleta))
})

test_that("municipio_padrao escolhe o menor Índice VIDAS do último ano", {
  dados <- dados_vidas()
  base <- valores_ano(dados, max(dados$anos), "indice_final")
  expect_equal(
    municipio_padrao(dados),
    base$codmunres[which.min(base$valor)]
  )
})

test_that("nome_municipio devolve nome e sigla", {
  dados <- dados_vidas()
  info <- dados$municipios[1, ]
  expect_equal(
    nome_municipio(dados, info$codmunres),
    paste0(info$municipio, " (", info$sigla_uf, ")")
  )
  expect_equal(nome_municipio(dados, 999999), "Município")
})

test_that("nome_uf traduz a sigla no nome por extenso", {
  dados <- dados_vidas()
  info <- dados$municipios[1, ]
  expect_equal(nome_uf(info$sigla_uf), info$uf)
  expect_true(is.na(nome_uf("XX")))
})

test_that("mapa_base limita o zoom e o arrasto ao enquadramento do Brasil", {
  mapa <- mapa_base()
  opcoes <- mapa$x$options
  expect_equal(opcoes$minZoom, 4)
  expect_equal(opcoes$maxZoom, 10)
  expect_equal(opcoes$maxBoundsViscosity, 1)
  metodos <- vapply(
    mapa$x$calls,
    function(chamada) chamada$method,
    character(1)
  )
  expect_true("setMaxBounds" %in% metodos)

  # Os painéis mantêm a hierarquia municípios < véu < UFs < município selecionado
  paineis <- Filter(
    function(chamada) chamada$method == "createMapPane",
    mapa$x$calls
  )
  alturas <- stats::setNames(
    vapply(paineis, function(painel) painel$args[[2]], numeric(1)),
    vapply(paineis, function(painel) painel$args[[1]], character(1))
  )
  expect_setequal(names(alturas), c("ufs", "apagado", "destaque"))
  expect_true(alturas[["apagado"]] < alturas[["ufs"]])
  expect_true(alturas[["ufs"]] < alturas[["destaque"]])
})

test_that("limites_escopo devolve o retângulo do Brasil ou da UF escolhida", {
  # O escopo nacional usa o mesmo retângulo do enquadramento inicial do mapa
  expect_equal(
    limites_escopo("nacional"),
    list(lng1 = -74.5, lat1 = -34.5, lng2 = -33.5, lat2 = 6.5)
  )

  # Uma UF devolve a caixa envolvente da própria malha estadual
  malha <- carregar_malha_ufs()
  for (sigla in c("SP", "PE", "AM", "DF")) {
    caixa <- sf::st_bbox(malha[malha$sigla_uf == sigla, ])
    expect_equal(
      limites_escopo(sigla),
      list(
        lng1 = unname(caixa[["xmin"]]), lat1 = unname(caixa[["ymin"]]),
        lng2 = unname(caixa[["xmax"]]), lat2 = unname(caixa[["ymax"]])
      )
    )
  }

  # Todas as siglas do seletor cabem no quadro máximo do mapa
  for (sigla in unique(dados_vidas()$municipios$sigla_uf)) {
    limites <- limites_escopo(sigla)
    expect_true(limites$lng1 >= -75 && limites$lng2 <= -32)
    expect_true(limites$lat1 >= -34.5 && limites$lat2 <= 6)
    expect_true(limites$lng2 > limites$lng1 && limites$lat2 > limites$lat1)
  }
})

test_that("enquadrar_escopo voa até o retângulo do escopo escolhido", {
  chamada <- new.env(parent = emptyenv())
  # Capturando o flyToBounds enviado ao proxy sem um servidor de verdade
  testthat::local_mocked_bindings(
    leafletProxy = function(outputId, session = NULL, ...) {
      chamada$output <- outputId
      chamada$sessao <- session
      structure(list(id = outputId, session = session), class = "leaflet_proxy")
    },
    flyToBounds = function(map, lng1, lat1, lng2, lat2, options = list()) {
      chamada$limites <- c(lng1 = lng1, lat1 = lat1, lng2 = lng2, lat2 = lat2)
      chamada$options <- options
      invisible(map)
    },
    .package = "leaflet"
  )

  sessao <- list(token = "teste")
  enquadrar_escopo(sessao, "onde-mapa", "SP")

  # O proxy é criado para o mapa do módulo e recebe a caixa envolvente de SP
  expect_equal(chamada$output, "onde-mapa")
  expect_identical(chamada$sessao, sessao)
  limites <- limites_escopo("SP")
  expect_equal(
    chamada$limites,
    c(
      lng1 = limites$lng1, lat1 = limites$lat1,
      lng2 = limites$lng2, lat2 = limites$lat2
    )
  )
  # O voo usa uma duração fixa e a folga de 16 px de cada lado
  expect_equal(chamada$options, list(duration = 0.8, padding = c(32, 32)))

  # O escopo nacional restaura o retângulo usado na abertura do painel
  enquadrar_escopo(sessao, "onde-mapa", "nacional")
  expect_equal(
    chamada$limites,
    c(lng1 = -74.5, lat1 = -34.5, lng2 = -33.5, lat2 = 6.5)
  )
})

test_that("destacar_uf cobre as UFs fora do escopo e limpa no nacional", {
  chamadas <- new.env(parent = emptyenv())
  chamadas$registros <- list()
  registrar <- function(registro) {
    chamadas$registros[[length(chamadas$registros) + 1]] <- registro
  }

  # Capturando o que o proxy envia sem um servidor de verdade
  testthat::local_mocked_bindings(
    leafletProxy = function(outputId, session = NULL, ...) {
      structure(list(id = outputId, session = session), class = "leaflet_proxy")
    },
    removeShape = function(map, layerId) {
      registrar(list(acao = "remove", layerId = layerId))
      map
    },
    addPolygons = function(map, data, layerId, ...) {
      registrar(list(
        acao = "add", layerId = layerId, data = data, extras = list(...)
      ))
      map
    },
    .package = "leaflet"
  )

  # No escopo escolhido, o véu anterior sai de todas as UFs e entra de novo
  destacar_uf(NULL, "onde-mapa", "SP")
  malha <- carregar_malha_ufs()
  acoes <- vapply(chamadas$registros, function(r) r$acao, character(1))
  expect_equal(sum(acoes == "remove"), nrow(malha))
  expect_equal(
    vapply(
      chamadas$registros[acoes == "remove"],
      function(r) r$layerId,
      character(1)
    ),
    paste0("apagado_", malha$sigla_uf)
  )
  expect_equal(which(acoes == "add"), nrow(malha) + 1)

  veu <- chamadas$registros[[nrow(malha) + 1]]
  # O véu cobre as 26 UFs restantes, deixando a escolhida de fora
  expect_equal(nrow(veu$data), 26)
  expect_false("SP" %in% veu$data$sigla_uf)
  expect_true("PE" %in% veu$data$sigla_uf)
  # Cada UF tem o próprio identificador, na ordem da malha
  expect_equal(veu$layerId, paste0("apagado_", veu$data$sigla_uf))
  # É só preenchimento na cor do fundo do mapa, sem contorno nem mouse
  expect_true(veu$extras$fill)
  expect_equal(veu$extras$fillColor, "#EDF1F7")
  expect_equal(veu$extras$fillOpacity, 0.5)
  expect_false(veu$extras$stroke)
  expect_equal(veu$extras$options$pane, "apagado")
  expect_false(veu$extras$options$interactive)

  # No escopo nacional sobram apenas as remoções do véu anterior
  chamadas$registros <- list()
  destacar_uf(NULL, "onde-mapa", "nacional")
  expect_equal(
    vapply(chamadas$registros, function(r) r$acao, character(1)),
    rep("remove", nrow(malha))
  )
})

test_that("aplicar_escopo destaca a UF antes de voar até ela", {
  registros <- new.env(parent = emptyenv())
  registros$ordem <- character(0)
  # Anotando a sequência das duas etapas sem tocar no leaflet
  testthat::local_mocked_bindings(
    destacar_uf = function(session, output_id, escopo) {
      registros$ordem <- c(registros$ordem, paste0("destaque:", escopo))
      invisible(NULL)
    },
    enquadrar_escopo = function(session, output_id, escopo) {
      registros$ordem <- c(registros$ordem, paste0("voo:", escopo))
      invisible(NULL)
    }
  )

  aplicar_escopo(NULL, "onde-mapa", "AM")
  expect_equal(registros$ordem, c("destaque:AM", "voo:AM"))
})

test_that("o escopo do ranking aplica o destaque e o voo conforme a escolha", {
  dados <- dados_vidas()
  municipio <- shiny::reactiveVal(municipio_padrao(dados))
  chamadas <- new.env(parent = emptyenv())
  chamadas$escopos <- character(0)

  # Capturando os escopos aplicados pelo módulo sem tocar no leaflet
  testthat::local_mocked_bindings(
    aplicar_escopo = function(session, output_id, escopo) {
      chamadas$escopos <- c(chamadas$escopos, escopo)
      chamadas$output_id <- output_id
      invisible(NULL)
    }
  )

  shiny::testServer(
    mod_onde_server,
    args = list(
      dados = dados,
      municipio = municipio,
      ano = shiny::reactiveVal(max(dados$anos))
    ),
    {
      session$setInputs(ano = "2024", medida = "indice_final", escopo = "nacional")
      session$flushReact()
      # O escopo nacional inicial não pede nada: o mapa abre no Brasil sem destaque
      expect_length(chamadas$escopos, 0)

      # Antes de o mapa ficar pronto, trocar o escopo ainda não aplica nada
      session$setInputs(escopo = "SP")
      session$flushReact()
      expect_length(chamadas$escopos, 0)

      # Quando o mapa termina de montar, a UF já escolhida é aplicada
      session$setInputs(mapa_pronto = 1)
      session$flushReact()
      expect_equal(chamadas$escopos, "SP")
      expect_equal(chamadas$output_id, session$ns("mapa"))

      # Trocando de UF, o mapa acompanha a nova escolha
      session$setInputs(escopo = "AM")
      session$flushReact()
      expect_equal(chamadas$escopos, c("SP", "AM"))

      # Voltando ao nacional, o destaque sai e o mapa volta ao Brasil
      session$setInputs(escopo = "nacional")
      session$flushReact()
      expect_equal(chamadas$escopos, c("SP", "AM", "nacional"))
    }
  )
})

test_that("legenda_categorias omite Sem dados por padrão", {
  padrao <- as.character(legenda_categorias())
  expect_false(grepl("Sem dados", padrao))
  expect_true(grepl("Muito alto", padrao))

  completo <- as.character(legenda_categorias(com_sem_dados = TRUE))
  expect_true(grepl("Sem dados", completo))
})

test_that("as rampas de PALETAS seguem a configuração do projeto", {
  # O índice tem a cor de identificação no fim da rampa, onde ficam as melhores condições
  expect_equal(unname(PALETAS$indice_final[5]), COR_VIDAS)

  # Cada bloco tem a própria rampa e a categoria central é a cor de identificação
  for (m in BLOCOS$medida) {
    rampa <- PALETAS[[m]]
    expect_length(rampa, 5)
    expect_equal(names(rampa), CATEGORIAS)
    expect_equal(length(unique(rampa)), 5)
    expect_equal(unname(rampa[3]), cor_medida(m))
  }

  # A cor mais clara não pode se confundir com o cinza de "Sem dados"
  expect_false(any(PALETAS[["bloco1"]] == COR_SEM_DADOS))
})

test_that("cor_categoria e badge_categoria_html respeitam a medida informada", {
  cor_bloco <- cor_categoria("Muito alto", "bloco3")
  expect_equal(cor_bloco, unname(PALETAS[["bloco3"]]["Muito alto"]))
  expect_false(identical(cor_bloco, cor_categoria("Muito alto")))
  selos <- badge_categoria_html(c("Muito baixo", "Muito alto"), "bloco3")
  expect_true(grepl(cor_bloco, selos[2], fixed = TRUE))
})

test_that("tooltip da pétala carrega a cor da dimensão", {
  blocos <- data.frame(
    medida = BLOCOS$medida,
    nome = BLOCOS$nome,
    valor = c(10, 30, 50, 70, 90, 100),
    categoria = c("Muito baixo", "Baixo", "Médio", "Alto", "Muito alto", "Muito alto"),
    cor = BLOCOS$cor,
    pos_nac = 1:6,
    total_nac = rep(100, 6),
    stringsAsFactors = FALSE
  )
  html <- as.character(grafico_petalas(blocos))
  expect_true(grepl("tooltip-petala__marca", html, fixed = TRUE))
  expect_true(grepl(paste0("--cor-medida:", cor_medida("bloco3")), html, fixed = TRUE))
  expect_true(grepl(paste0("--cor-fundo:", cor_categoria("Médio", "bloco3")), html, fixed = TRUE))
  # A tooltip nomeia a posição como prioridade no escopo
  expect_true(grepl("Prioridade", html, fixed = TRUE))
  expect_false(grepl("Ranking", html, fixed = TRUE))
  # A chip de categoria fica na linha do valor, antes da prioridade
  tooltip <- tooltip_petala("Social", 40.9, "Médio", 2279, 5570, "bloco1")
  pos_valor <- regexpr("Valor", tooltip, fixed = TRUE)[1]
  pos_chip <- regexpr("--cor-fundo:", tooltip, fixed = TRUE)[1]
  pos_prioridade <- regexpr("Prioridade", tooltip, fixed = TRUE)[1]
  expect_true(pos_valor < pos_chip)
  expect_true(pos_chip < pos_prioridade)
  # Os nomes dos blocos ficam nas próprias pétalas, sem a legenda abaixo
  expect_true(grepl("rotulo-petala", html, fixed = TRUE))
  expect_false(grepl("petalas-legenda", html, fixed = TRUE))
})

test_that("grafico_petalas monta as seis pétalas com tooltip", {
  blocos <- data.frame(
    nome = BLOCOS$nome,
    valor = c(10, 30, 50, 70, 90, 100),
    categoria = c("Muito baixo", "Baixo", "Médio", "Alto", "Muito alto", "Muito alto"),
    cor = BLOCOS$cor,
    pos_nac = 1:6,
    total_nac = rep(100, 6),
    stringsAsFactors = FALSE
  )
  html <- as.character(grafico_petalas(blocos))
  expect_true(grepl("svg-petalas", html))
  expect_equal(
    lengths(regmatches(html, gregexpr("grupo-petala", html))),
    6
  )
  expect_true(grepl("tooltip-petala", html))
  expect_true(grepl("Planejamento Reprodutivo", html))
  # Os valores dentro das pétalas usam sempre uma casa decimal
  expect_true(grepl(">100,0</text>", html, fixed = TRUE))
  expect_true(grepl(">10,0</text>", html, fixed = TRUE))

  # Os discos de valor ficam sempre no fim da guia, e não na ponta da pétala
  expect_false(grepl("ponto-mediana", html))
  discos <- regmatches(
    html,
    gregexpr('cx="[0-9.]+" cy="[0-9.]+" r="16"', html)
  )[[1]]
  expect_length(discos, 6)
  coordenadas <- do.call(rbind, lapply(discos, function(disco) {
    as.numeric(regmatches(disco, gregexpr("[0-9.]+", disco))[[1]])[1:2]
  }))
  distancias <- sqrt((coordenadas[, 1] - 250)^2 + (coordenadas[, 2] - 275)^2)
  expect_true(all(round(distancias) == 185))

  # A ponta da pétala percorre a guia na mesma escala do disco
  escalas <- as.numeric(sub(
    ".*scale\\(([0-9.]+)\\).*", "\\1",
    regmatches(html, gregexpr('scale\\([0-9.]+\\)" class="forma-petala"', html))[[1]]
  ))
  esperadas <- round((blocos$valor / 100) * (185 / 170), 3)
  expect_equal(round(escalas, 3), esperadas)

  # A silhueta de referência marca a extensão máxima em toda pétala
  silhuetas <- regmatches(
    html,
    gregexpr('scale\\([0-9.]+\\)" class="silhueta-petala"', html)
  )[[1]]
  expect_length(silhuetas, 6)
  escalas_silhueta <- as.numeric(sub(
    ".*scale\\(([0-9.]+)\\).*", "\\1", silhuetas
  ))
  expect_equal(round(escalas_silhueta, 3), rep(round(185 / 170, 3), 6))

  # Todas as silhuetas ficam em uma camada única desenhada abaixo das pétalas
  expect_equal(
    lengths(regmatches(html, gregexpr('class="camada-silhuetas"', html, fixed = TRUE))),
    1
  )
  expect_true(
    max(gregexpr('class="silhueta-petala"', html, fixed = TRUE)[[1]]) <
      min(gregexpr('class="grupo-petala"', html, fixed = TRUE)[[1]])
  )

  # O leque abre até perto da horizontal para reduzir a sobreposição
  expect_equal(ANGULOS_PETALAS, c(-80, -48, -16, 16, 48, 80))
  # As fantasmas e as guias ficam abaixo do centro, e as pétalas reais acima dele
  expect_equal(
    lengths(regmatches(html, gregexpr('class="camada-guias"', html, fixed = TRUE))),
    1
  )
  expect_equal(
    lengths(regmatches(html, gregexpr('class="guia-petala"', html, fixed = TRUE))),
    6
  )
  pos_silhuetas <- max(gregexpr('class="silhueta-petala"', html, fixed = TRUE)[[1]])
  pos_guias <- max(gregexpr('class="guia-petala"', html, fixed = TRUE)[[1]])
  pos_centro <- max(gregexpr('cx="250" cy="275" r="6"', html, fixed = TRUE)[[1]])
  pos_petalas <- min(gregexpr('class="grupo-petala"', html, fixed = TRUE)[[1]])
  expect_true(pos_silhuetas < pos_guias)
  expect_true(pos_guias < pos_centro)
  expect_true(pos_centro < pos_petalas)
  # Os rótulos dos blocos aparecem diretamente junto das pétalas
  for (rotulo in c(
    "Social", "Planejamento", "Reprodutivo", "Pré-natal",
    "Parto", "Sistema de Saúde", "Clima"
  )) {
    expect_true(grepl(paste0(">", rotulo, "</tspan>"), html, fixed = TRUE))
  }
  # Os nomes abreviados anteriores não são mais exibidos
  expect_false(grepl(">Planej.</tspan>", html, fixed = TRUE))
  expect_false(grepl(">Sistema</tspan>", html, fixed = TRUE))
})

test_that("a silhueta de referência permanece visível com valor zerado", {
  blocos <- data.frame(
    nome = BLOCOS$nome,
    valor = rep(0, 6),
    categoria = rep("Muito baixo", 6),
    cor = BLOCOS$cor,
    pos_nac = 1:6,
    total_nac = rep(100, 6),
    stringsAsFactors = FALSE
  )
  html <- as.character(grafico_petalas(blocos))
  # A pétala real desaparece na escala zero, mas a silhueta segue no máximo
  expect_equal(
    lengths(regmatches(html, gregexpr('scale\\(0\\)" class="forma-petala"', html))),
    6
  )
  expect_equal(
    lengths(regmatches(html, gregexpr('scale\\(1.088\\)" class="silhueta-petala"', html))),
    6
  )
})

test_that("perfil_palco monta identificação, índice, pétalas e rankings", {
  dados <- dados_vidas()
  ano <- max(dados$anos)
  cod <- municipio_padrao(dados)

  # Montando um resumo de referência para o componente exibir
  linha <- valores_ano(dados, ano, "indice_final")
  linha <- linha[linha$codmunres == cod, ]
  blocos <- do.call(rbind, lapply(BLOCOS$medida, function(medida) {
    valores_ano(dados, ano, medida)[valores_ano(dados, ano, medida)$codmunres == cod, ]
  }))
  blocos$medida <- BLOCOS$medida
  blocos$nome <- BLOCOS$nome
  blocos$cor <- BLOCOS$cor
  resumo <- list(
    codmunres = cod,
    municipio = linha$municipio,
    sigla_uf = linha$sigla_uf,
    valor = linha$valor,
    categoria = as.character(linha$categoria),
    pos_nac = linha$pos_nac,
    total_nac = linha$total_nac,
    pos_uf = linha$pos_uf,
    total_uf = linha$total_uf,
    pos_macro = linha$pos_macro,
    total_macro = linha$total_macro,
    blocos = blocos
  )

  municipio <- dados$municipios[dados$municipios$codmunres == cod, ]
  html <- as.character(perfil_palco(
    municipio, resumo, ano = ano,
    rotulo = "Município principal"
  ))
  expect_true(grepl(
    paste0(resumo$municipio, ", ", resumo$sigla_uf),
    html,
    fixed = TRUE
  ))
  expect_true(grepl("Município principal", html, fixed = TRUE))
  expect_true(grepl("svg-petalas", html, fixed = TRUE))
  expect_true(grepl(paste0("Índice VIDAS em ", ano), html, fixed = TRUE))
  expect_true(grepl("perfil-indice", html, fixed = TRUE))
  expect_true(grepl("perfil-rankings", html, fixed = TRUE))
  # A régua do índice fica logo abaixo da frase de leitura
  expect_true(grepl("perfil-indice__regua", html, fixed = TRUE))
  expect_true(grepl("0 · muito baixo", html, fixed = TRUE))
  expect_true(grepl("100 · muito alto", html, fixed = TRUE))
  # A régua é interativa e carrega a leitura do índice no tooltip
  regua_tag <- regmatches(
    html,
    regexpr('<div class="perfil-indice__regua"[^>]*>', html, perl = TRUE)
  )[[1]]
  expect_true(grepl('data-bs-toggle="tooltip"', regua_tag, fixed = TRUE))
  expect_true(grepl('tabindex="0"', regua_tag, fixed = TRUE))
  expect_true(grepl("Índice VIDAS", regua_tag, fixed = TRUE))
  # O município e o ano aparecem no topo de todas as tooltips do palco
  expect_true(grepl("Jutaí (AM) · 2024", html, fixed = TRUE))
  # O município padrão é o de menor VIDA e recebe o texto especial
  expect_equal(linha$pos_nac, 1L)
  expect_true(grepl("Menor VIDA entre todos os municípios brasileiros", html, fixed = TRUE))
  # A linha dos gráficos é nomeada uma única vez, antes das pétalas e das barras
  expect_true(grepl("perfil-palco__titulo", html, fixed = TRUE))
  expect_true(grepl("Resultado por dimensão", html, fixed = TRUE))
  # O botão de informação guarda a explicação das pétalas no tooltip
  expect_true(grepl("perfil-palco__info", html, fixed = TRUE))
  expect_true(grepl("No gráfico de pétalas, cada pétala representa", html, fixed = TRUE))
  expect_true(grepl("O contorno pontilhado mostra o tamanho máximo", html, fixed = TRUE))
  # A visão sem comparação mostra o resultado por bloco em barras
  expect_true(grepl("resultado-blocos", html, fixed = TRUE))
  # Os três rankings aparecem na ordem pedida
  expect_true(grepl("Na macrorregião", html, fixed = TRUE))
  expect_true(grepl("Na UF", html, fixed = TRUE))
  expect_true(grepl("No Brasil", html, fixed = TRUE))
  # Os rankings ganham trilhos com os extremos menor e maior VIDA
  expect_equal(
    lengths(regmatches(html, gregexpr("perfil-rankings__trilho", html, fixed = TRUE))),
    3
  )
  expect_equal(
    lengths(regmatches(html, gregexpr("perfil-rankings__extremos", html, fixed = TRUE))),
    3
  )
  expect_equal(
    lengths(regmatches(html, gregexpr("menor VIDA", html, fixed = TRUE))),
    3
  )
  expect_equal(
    lengths(regmatches(html, gregexpr("maior VIDA", html, fixed = TRUE))),
    3
  )
  # Os valores territoriais guardam o texto completo para o tooltip condicional
  expect_true(grepl("metrica-tooltip", html, fixed = TRUE))
  expect_true(grepl("data-tooltip-texto", html, fixed = TRUE))

  # O palco do comparado usa a classe própria, sem o rótulo do principal
  html_b <- as.character(perfil_palco(
    municipio, resumo, ano = ano,
    comparado = TRUE, rotulo = "Município comparado"
  ))
  expect_true(grepl("painel-bloco--comparado", html_b, fixed = TRUE))
  expect_true(grepl("Município comparado", html_b, fixed = TRUE))
  # Na comparação, o palco fica apenas com as pétalas, sem as barras
  expect_false(grepl("resultado-blocos", html_b, fixed = TRUE))
  expect_true(grepl("perfil-palco__graficos--petalas", html_b, fixed = TRUE))
})

test_that("perfil_rankings monta trilhos interativos com tooltip", {
  resumo <- list(
    pos_macro = 1, total_macro = 21, macro_r_saude = "OESTE",
    pos_uf = 1, total_uf = 62, uf = "Amazonas",
    pos_nac = 1, total_nac = 5570
  )
  html <- as.character(perfil_rankings(resumo))
  # Cada um dos três rankings ganha um trilho com tooltip e foco por teclado
  expect_equal(
    lengths(regmatches(html, gregexpr('class="perfil-rankings__trilho"', html, fixed = TRUE))),
    3
  )
  expect_equal(
    lengths(regmatches(html, gregexpr('data-bs-toggle="tooltip"', html, fixed = TRUE))),
    3
  )
  expect_equal(
    lengths(regmatches(html, gregexpr('tabindex="0"', html, fixed = TRUE))),
    3
  )
  # As tooltips identificam o território no título e leem a posição
  expect_true(grepl("Na macrorregião (OESTE)", html, fixed = TRUE))
  expect_true(grepl("Na UF (Amazonas)", html, fixed = TRUE))
  expect_true(grepl("Menor VIDA", html, fixed = TRUE))
  expect_true(grepl("entre 21 municípios", html, fixed = TRUE))
  expect_true(grepl("entre 62 municípios", html, fixed = TRUE))
  expect_true(grepl("entre 5.570 municípios", html, fixed = TRUE))
  expect_false(grepl("1º de", html, fixed = TRUE))
  expect_false(grepl("Escopo", html, fixed = TRUE))
  expect_false(grepl("Ranking", html, fixed = TRUE))
  # Apenas o começo da leitura fica em negrito
  expect_true(grepl(
    "<strong>12ª menor VIDA</strong> entre 21 municípios",
    tooltip_ranking("Na UF", 12, 21, "São Paulo"),
    fixed = TRUE
  ))
})

test_that("perfil_palco mostra estado vazio quando não há dado no ano", {
  dados <- dados_vidas()
  cod <- municipio_padrao(dados)
  municipio <- dados$municipios[dados$municipios$codmunres == cod, ]
  html <- as.character(perfil_palco(municipio, NULL, ano = max(dados$anos)))
  expect_true(grepl("não possui dados no ano selecionado", html, fixed = TRUE))
  expect_false(grepl("perfil-indice", html, fixed = TRUE))
  expect_false(grepl("perfil-rankings", html, fixed = TRUE))
})

test_that("esqueletos preservam a estrutura de cada output", {
  # O ranking replica a busca, o cabeçalho, as 12 linhas e a paginação
  ranking <- as.character(esqueleto_ranking())
  expect_equal(
    lengths(regmatches(ranking, gregexpr("esqueleto__linha", ranking))),
    12
  )
  expect_true(grepl("esqueleto__busca", ranking))
  expect_true(grepl("esqueleto__paginacao", ranking))
  # O cabeçalho alinha números à direita e a paginação reproduz os botões
  expect_true(grepl("esqueleto__celula--direita", ranking))
  expect_true(grepl("esqueleto__paginacao-nav", ranking))
  expect_true(grepl("esqueleto__barra--reticencias", ranking))

  # O mapa desenha a silhueta do Brasil junto do controle de zoom
  mapa <- as.character(esqueleto_mapa())
  expect_true(grepl("esqueleto__desenho", mapa))
  expect_true(grepl("esqueleto__forma", mapa))
  expect_true(grepl("esqueleto__controle", mapa))

  # O palco mantém identificação, índice, pétalas e rankings na mesma composição
  palco <- as.character(esqueleto_palco())
  expect_true(grepl("perfil-nome", palco))
  expect_true(grepl("perfil-metricas", palco))
  expect_true(grepl("perfil-indice", palco))
  expect_true(grepl("svg-petalas", palco))
  expect_true(grepl("perfil-palco__titulo", palco))
  expect_true(grepl("resultado-blocos", palco))
  expect_true(grepl("perfil-rankings", palco))
  expect_true(grepl("perfil-rankings__trilho", palco))
  # Cada trilho do esqueleto reserva também o ponto da posição
  expect_equal(
    lengths(regmatches(palco, gregexpr("esqueleto__barra--ponto", palco, fixed = TRUE))),
    3
  )
  expect_equal(
    lengths(regmatches(palco, gregexpr("esqueleto__disco", palco))),
    6
  )
  # O esqueleto não repete a legenda removida do gráfico de pétalas
  expect_false(grepl("petalas-legenda", palco))
  # O esqueleto não deve repetir nenhum valor do conteúdo real
  expect_false(grepl("Índice VIDAS em", palco))

  # A identificação da evolução reserva a linha do nome e do período
  identificacao <- as.character(esqueleto_identificacao())
  expect_true(grepl("esqueleto--identificacao", identificacao, fixed = TRUE))
  expect_true(grepl("esqueleto__barra", identificacao, fixed = TRUE))

  # A evolução reserva os sete cartões com eixos e traços abstratos
  evolucao <- as.character(esqueleto_grade_evolucao())
  expect_true(grepl("evolucao-grade", evolucao))
  expect_true(grepl("esqueleto__traco", evolucao))
  expect_equal(
    lengths(regmatches(evolucao, gregexpr('class="esqueleto__grafico"', evolucao))),
    7
  )
  # Cada gráfico reserva a coluna dos números do eixo Y, como o gráfico real
  expect_equal(
    lengths(regmatches(evolucao, gregexpr("esqueleto__grafico-margem", evolucao))),
    7
  )
  # Cada gráfico reserva as cinco marcações do eixo Y, como o gráfico real
  expect_equal(
    lengths(regmatches(evolucao, gregexpr("esqueleto__barra--rotulo", evolucao))),
    7 * MARCACOES_EIXO
  )
  # O grupo do título reserva também a barra da identificação dos municípios
  expect_true(grepl("evolucao-grade__cabecalho", evolucao, fixed = TRUE))
  expect_true(grepl("Dimensões do Índice VIDAS", evolucao, fixed = TRUE))
  expect_equal(
    lengths(regmatches(evolucao, gregexpr("esqueleto--identificacao", evolucao, fixed = TRUE))),
    1
  )

  # O slot empilha o output e o esqueleto para o CSS exibir durante a carga
  slot <- as.character(esqueleto_slot(
    htmltools::tags$div(id = "saida"),
    esqueleto_texto(),
    classe = "esqueleto-slot--texto"
  ))
  expect_true(grepl("esqueleto-slot", slot, fixed = TRUE))
  expect_true(grepl('id="saida"', slot, fixed = TRUE))
  expect_true(grepl("esqueleto--texto", slot, fixed = TRUE))
})

# ---------------------------------------------------------------------------
#   Indicadores dos blocos
# ---------------------------------------------------------------------------

test_that("o dicionário dos indicadores cobre os blocos na ordem canônica", {
  # Um indicador por código do cálculo e uma rodada de configurações completa
  expect_equal(nrow(INDICADORES), 16)
  expect_equal(anyDuplicated(INDICADORES$indicador), 0)
  expect_equal(anyDuplicated(INDICADORES$codigo), 0)
  expect_setequal(unique(INDICADORES$bloco), BLOCOS$medida)
  # O IDHM pede três casas decimais e os demais indicadores pedem uma
  expect_equal(info_indicador("idhm")$decimais, 3)
  expect_true(all(INDICADORES$decimais[INDICADORES$indicador != "idhm"] == 1))
  expect_true(all(INDICADORES$fator %in% c(1, 100)))
  expect_true(all(nzchar(INDICADORES$nome)))
  expect_true(all(nzchar(INDICADORES$unidade)))
  # Os títulos seguem os nomes oficiais do cálculo do índice
  expect_equal(
    info_indicador("NASC_CES")$nome,
    "Porcentagem de nascidos vivos por cesariana"
  )
  expect_equal(
    info_indicador("DIST_RES")$nome,
    "Medianas de deslocamento para partos ocorridos fora do município de residência da mulher"
  )

  # A contagem por bloco acompanha o cálculo do índice
  contagem <- table(INDICADORES$bloco)
  expect_equal(
    as.integer(contagem[c(BLOCOS$medida)]),
    c(5L, 1L, 1L, 3L, 5L, 1L)
  )
})

test_that("as consultas do dicionário devolvem o recorte pedido", {
  # A lista de um bloco mantém a ordem canônica do dicionário
  bloco5 <- indicadores_do_bloco("bloco5")
  expect_equal(
    bloco5$indicador,
    INDICADORES$indicador[INDICADORES$bloco == "bloco5"]
  )

  # A ficha de um indicador traz bloco, unidade e sentido do dicionário
  info <- info_indicador("PRE_NATAL")
  expect_equal(info$bloco, "bloco3")
  expect_equal(info$unidade, "%")
  expect_true(info$protetor)
  expect_false(info_indicador("tx_homicidio_100mil")$protetor)
})

test_that("a chip de sentido segue o protetor do indicador", {
  # Indicadores protetores sobem quando o município melhora
  maior <- as.character(chip_sentido_indicador(TRUE))
  expect_true(grepl("indicador-card__sentido--maior", maior, fixed = TRUE))
  expect_true(grepl("Maior é melhor", maior, fixed = TRUE))
  expect_true(grepl("↑", maior, fixed = TRUE))
  expect_true(grepl('data-bs-toggle="tooltip"', maior, fixed = TRUE))

  # Os demais indicadores caem quando o município melhora
  menor <- as.character(chip_sentido_indicador(FALSE))
  expect_true(grepl("indicador-card__sentido--menor", menor, fixed = TRUE))
  expect_true(grepl("Menor é melhor", menor, fixed = TRUE))
  expect_true(grepl("↓", menor, fixed = TRUE))
})

test_that("os gráficos dos indicadores acompanham a altura dos blocos", {
  expect_equal(ALTURA_GRAFICO_INDICADOR, ALTURA_GRAFICO_BLOCO)
})

test_that("tem_indicadores exige a base reconstruída por completo", {
  series_fake <- data.frame(codmunres = 1L, ano = 2020L)
  for (indicador in INDICADORES$indicador) {
    series_fake[[indicador]] <- 1
  }
  expect_true(tem_indicadores(list(series = series_fake)))

  # Faltando uma única coluna, a seção dos indicadores fica oculta
  series_fake$idhm <- NULL
  expect_false(tem_indicadores(list(series = series_fake)))
})

test_that("series_municipio respeita o recorte de colunas pedido", {
  series_fake <- data.frame(
    codmunres = c(1L, 1L, 2L),
    ano = c(2020L, 2021L, 2020L),
    indice_final = c(50, 60, 70),
    idhm = c(0.6, 0.7, 0.65)
  )
  dados_fake <- list(series = series_fake)

  completo <- series_municipio(dados_fake, 1L)
  expect_equal(names(completo), c("ano", "indice_final", "idhm"))
  expect_equal(nrow(completo), 2)
  expect_true(series_tem_valor(completo))
  expect_true(series_tem_valor(completo, "idhm"))

  # Colunas que não existem na base não entram no recorte
  expect_false(series_tem_valor(completo, c("bloco1", "bloco2")))
  so_idhm <- series_municipio(dados_fake, 1L, colunas = "idhm")
  expect_equal(names(so_idhm), c("ano", "idhm"))

  # Município fora da base devolve o mesmo desenho de colunas, sem linhas
  vazio <- series_municipio(dados_fake, 99L)
  expect_equal(names(vazio), c("ano", "indice_final", "idhm"))
  expect_false(series_tem_valor(vazio))
})

test_that("o passo redondo e as casas decimais cobrem cada escala", {
  expect_equal(passos_do_eixo(30)[1], 10)
  expect_equal(passos_do_eixo(0.15)[1], 0.05)
  expect_equal(casas_do_passo(5), 0)
  expect_equal(casas_do_passo(0.5), 1)
  expect_equal(casas_do_passo(0.02), 2)
  # Passos com meio pedem uma casa a mais (1,5 e 2,5)
  expect_equal(casas_do_passo(2.5), 1)
  expect_equal(casas_do_passo(15), 0)
})

test_that("os limites dos indicadores se adaptam à escala", {
  series_ind <- data.frame(ano = 2020:2022, PRE_NATAL = c(40, 55, 70))

  # A faixa fecha em cinco marcações redondas, centradas nos dados
  limites <- limites_indicador(series_ind, "PRE_NATAL")
  expect_equal(limites$min, 40)
  expect_equal(limites$max, 80)
  expect_equal(limites$passo, 10)
  expect_equal((limites$max - limites$min) / limites$passo, MARCACOES_EIXO - 1)

  # Uma série constante abre folga em torno do valor (caso do IDHM)
  constante <- data.frame(ano = 2020:2022, PRE_NATAL = c(60, 60, 60))
  limites <- limites_indicador(constante, "PRE_NATAL")
  expect_true(limites$min < 60 && limites$max > 60)

  # Série constante em zero não abre valores negativos (peso <1.500 g pode zerar)
  zerada <- data.frame(ano = 2020:2022, prop_menor_1500 = c(0, 0, 0))
  limites <- limites_indicador(zerada, "prop_menor_1500")
  expect_equal(limites$min, 0)
  expect_true(limites$max > 0)

  # Faixa estreita de porcentagem não desce abaixo da precisão de uma casa
  estreita <- data.frame(ano = 2020:2022, DEP_SUS = c(99.6, 99.9, 99.7))
  limites <- limites_indicador(estreita, "DEP_SUS")
  expect_gte(limites$passo, 0.1)
  expect_true(limites$min <= 99.6 && limites$max >= 99.9)

  # Sem valor algum, o eixo fica na faixa neutra de cinco marcações
  vazio <- data.frame(ano = 2020:2022, PRE_NATAL = c(NA, NA, NA))
  expect_equal(
    limites_indicador(vazio, "PRE_NATAL"),
    list(min = 0, max = 0.4, passo = 0.1)
  )

  # Com comparação, a faixa cobre os dois municípios
  comparacao <- data.frame(ano = 2020:2022, PRE_NATAL = c(10, 20, 95))
  limites <- limites_indicador(series_ind, "PRE_NATAL", comparacao)
  expect_equal(limites$min, 0)
  expect_equal(limites$max, 100)
})

test_that("grafico_evolucao_indicador usa a cor do bloco e a escala do indicador", {
  series_ind <- data.frame(ano = 2020:2022, PRE_NATAL = c(40, 55, 70))
  grafico <- grafico_evolucao_indicador(series_ind, "PRE_NATAL", nome = "Um (RO)")

  # A série principal usa a cor do bloco do indicador
  serie <- grafico$x$opts$series[[1]]
  expect_equal(serie$name, "Um (RO)")
  expect_equal(serie$itemStyle$color, cor_linha_medida("bloco3"))
  expect_equal(serie$lineStyle$type, "solid")

  # O eixo Y acompanha a escala própria do indicador, em cinco marcações
  expect_equal(grafico$x$opts$yAxis[[1]]$min, 40)
  expect_equal(grafico$x$opts$yAxis[[1]]$max, 80)
  expect_equal(grafico$x$opts$yAxis[[1]]$interval, 10)

  # O eixo de porcentagem mostra o sufixo % nos valores
  formatter_pct <- as.character(grafico$x$opts$yAxis[[1]]$axisLabel$formatter)
  expect_true(grepl("+ '%'", formatter_pct, fixed = TRUE))

  # O eixo do IDHM usa as três casas do indicador
  idhm <- data.frame(ano = 2020:2022, idhm = c(0.50, 0.51, 0.52))
  grafico_idhm <- grafico_evolucao_indicador(idhm, "idhm")
  formatter_idhm <- as.character(grafico_idhm$x$opts$yAxis[[1]]$axisLabel$formatter)
  expect_true(grepl("toFixed(3)", formatter_idhm, fixed = TRUE))

  # O tooltip respeita as casas e a unidade configuradas para o indicador
  expect_true(grepl("toFixed(1)", tooltip_evolucao_js(), fixed = TRUE))
  expect_true(grepl("toFixed(3)", tooltip_evolucao_js(3), fixed = TRUE))
  expect_true(grepl("+ '%'", tooltip_evolucao_js(1, "%"), fixed = TRUE))

  # Com comparação, as duas séries aparecem com o tracejado padrão
  grafico_comp <- grafico_evolucao_indicador(
    series_ind, "PRE_NATAL",
    comparacao = series_ind, nome_comparacao = "Dois (RO)"
  )
  expect_length(grafico_comp$x$opts$series, 2)
  expect_equal(grafico_comp$x$opts$series[[2]]$lineStyle$type, c(9, 7))
  expect_equal(grafico_comp$x$opts$series[[2]]$itemStyle$color, "#FFFFFF")
})

test_that("o esqueleto dos indicadores reserva os cartões do bloco padrão", {
  indicadores_esq <- as.character(esqueleto_indicadores())
  expect_true(grepl("indicadores-grade", indicadores_esq, fixed = TRUE))
  expect_equal(
    lengths(regmatches(indicadores_esq, gregexpr('class="indicador-card ', indicadores_esq))),
    5
  )
  expect_equal(
    lengths(regmatches(indicadores_esq, gregexpr("esqueleto__grafico-margem", indicadores_esq))),
    5
  )
  # A chip do sentido também é reservada no cabeçalho dos cartões
  expect_equal(
    lengths(regmatches(indicadores_esq, gregexpr("esqueleto__barra--selo", indicadores_esq))),
    5
  )
})

test_that("o módulo exibe os indicadores do bloco selecionado", {
  dados <- dados_vidas()
  testthat::skip_if_not(
    tem_indicadores(dados),
    "séries prontas sem indicadores (rode data-raw/cria_rda.R)"
  )
  principal <- municipio_padrao(dados)
  municipio <- shiny::reactiveVal(principal)
  shiny::testServer(
    mod_como_server,
    args = list(
      dados = dados,
      municipio = municipio,
      ano = shiny::reactiveVal(max(dados$anos))
    ),
    {
      session$setInputs(
        municipio = as.character(principal),
        ano = as.character(max(dados$anos))
      )

      # O bloco padrão é o Social, com os cinco indicadores em cartões
      cartoes <- as.character(output$indicadores$html)
      for (indicador in indicadores_do_bloco("bloco1")$indicador) {
        expect_true(grepl(paste0("indicador_", indicador), cartoes, fixed = TRUE))
      }

      # O Social mistura indicadores de maior e de menor melhor
      expect_true(grepl("indicador-card__sentido--maior", cartoes, fixed = TRUE))
      expect_true(grepl("indicador-card__sentido--menor", cartoes, fixed = TRUE))
      expect_true(grepl("Maior é melhor", cartoes, fixed = TRUE))
      expect_true(grepl("Menor é melhor", cartoes, fixed = TRUE))

      # Trocando o bloco, a grade passa a trazer os indicadores do bloco pedido
      session$setInputs(bloco = "bloco3")
      cartoes <- as.character(output$indicadores$html)
      expect_true(grepl("indicador_PRE_NATAL", cartoes, fixed = TRUE))
      expect_false(grepl("indicador_idhm", cartoes, fixed = TRUE))

      # O gráfico do indicador usa a escala própria do indicador
      opcoes <- jsonlite::fromJSON(
        output$indicador_PRE_NATAL,
        simplifyVector = FALSE
      )$x$opts
      esperados <- limites_indicador(series_municipio(dados, principal), "PRE_NATAL")
      expect_equal(opcoes$yAxis[[1]]$min, esperados$min)
      expect_equal(opcoes$yAxis[[1]]$max, esperados$max)
    }
  )
})
