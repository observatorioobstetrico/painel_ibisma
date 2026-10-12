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

# Base bruta de referência, lida direto do CSV de entrada (fora do build)
caminho_base <- testthat::test_path(
  "..", "..", "data-raw", "databases", "base_exemplo_ibisma.csv"
)
tem_base <- file.exists(caminho_base)
if (tem_base) {
  base_referencia <- unique(read.csv(caminho_base))
}

# Pulando os testes da base quando o CSV do data-raw não está presente
exigir_base <- function() {
  testthat::skip_if_not(tem_base, "CSV da base bruta não disponível")
}

test_that("os dados prontos têm cadastro, anos e séries completos", {
  exigir_base()
  dados <- dados_ibisma()

  # O cadastro tem os municípios e os anos da base bruta
  expect_equal(dados$anos, sort(unique(base_referencia$ano)))
  expect_equal(nrow(dados$municipios), length(unique(base_referencia$codmunres)))
  expect_setequal(names(dados$municipios), c(
    "codmunres", "municipio", "sigla_uf", "uf",
    "regiao", "r_saude", "macro_r_saude"
  ))

  # As séries têm uma linha por município e ano, com as sete medidas
  expect_equal(nrow(dados$series), length(dados$anos) * nrow(dados$municipios))
  expect_equal(names(dados$series), c("codmunres", "ano", MEDIDAS$medida))
})

test_that("as séries prontas batem com a base bruta", {
  exigir_base()
  dados <- dados_ibisma()

  # Ligando cada linha da série à linha correspondente da base bruta
  chave_serie <- paste(dados$series$ano, dados$series$codmunres)
  chave_base <- paste(base_referencia$ano, base_referencia$codmunres)
  posicao <- match(chave_serie, chave_base)

  for (medida in MEDIDAS$medida) {
    expect_equal(
      dados$series[[medida]],
      100 * base_referencia[[medida]][posicao],
      tolerance = 1e-12
    )
  }
})

test_that("as tabelas anuais usam as medidas e as categorias do painel", {
  exigir_base()
  dados <- dados_ibisma()

  # As medidas de constantes.R precisam cobrir as colunas do CSV de entrada
  colunas_geo <- c(
    "ano", "codmunres", "municipio", "sigla_uf", "uf",
    "regiao", "r_saude", "macro_r_saude"
  )
  expect_setequal(setdiff(names(base_referencia), colunas_geo), MEDIDAS$medida)

  for (ano in dados$anos) {
    tabela <- tabela_ano(dados, ano)
    expect_setequal(unique(tabela$medida), MEDIDAS$medida)
    expect_equal(levels(tabela$categoria), CATEGORIAS)
    expect_true(is.ordered(tabela$categoria))
  }
})

test_that("as categorias seguem os quintis e os rankings do ano", {
  dados <- dados_ibisma()
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

    # A posição 1 é o município mais vulnerável, com empates pelo mínimo
    expect_equal(
      base$pos_nac,
      rank(-base$valor, ties.method = "min", na.last = "keep")
    )
    expect_equal(unique(base$total_nac), sum(!is.na(base$valor)))

    # O ranking da UF é calculado dentro de cada estado
    iguais <- base[base$sigla_uf == "RO", ]
    expect_equal(
      iguais$pos_uf,
      rank(-iguais$valor, ties.method = "min", na.last = "keep")
    )
    expect_equal(unique(iguais$total_uf), sum(!is.na(iguais$valor)))
  }
})

test_that("o resumo do município alimenta o palco com índice, rankings e blocos", {
  dados <- dados_ibisma()
  ano_ref <- max(dados$anos)
  cod <- municipio_padrao(dados)

  # Conferindo o que o palco exibe contra a tabela do ano
  linha <- valores_ano(dados, ano_ref, "indice_final")
  linha <- linha[linha$codmunres == cod, ]
  # O município padrão é o mais vulnerável do último ano
  expect_equal(linha$pos_nac, 1)

  municipio <- shiny::reactiveVal(cod)
  shiny::testServer(
    mod_como_server,
    args = list(dados = dados, municipio = municipio),
    {
      session$setInputs(ano = as.character(ano_ref))
      # Convertendo a árvore de tags do palco em um texto único para conferir
      palco <- paste(as.character(output$palco_principal$html), collapse = "\n")

      # O placar mostra o valor e a categoria do índice final
      expect_true(grepl(formatar_numero(linha$valor), palco, fixed = TRUE))
      expect_true(grepl(as.character(linha$categoria), palco, fixed = TRUE))
      expect_true(grepl(rotulo_posicao(linha$pos_nac, linha$total_nac), palco, fixed = TRUE))

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
  dados <- dados_ibisma()

  # Município com ano faltante (Borá em 2023)
  lacuna <- dados$series[is.na(dados$series$indice_final), c("codmunres", "ano")][1, ]

  municipio <- shiny::reactiveVal(lacuna$codmunres)
  shiny::testServer(
    mod_como_server,
    args = list(dados = dados, municipio = municipio),
    {
      session$setInputs(ano = as.character(lacuna$ano))
      # Sem resumo no ano, o palco cai no estado vazio no lugar do placar
      palco <- paste(as.character(output$palco_principal$html), collapse = "\n")
      expect_true(grepl("não possui dados no ano selecionado", palco, fixed = TRUE))
      expect_false(grepl("perfil-placar", palco, fixed = TRUE))
    }
  )
})

test_that("series_municipio monta as sete medidas em colunas", {
  dados <- dados_ibisma()
  cod <- dados$municipios$codmunres[1]

  series <- series_municipio(dados, cod)
  expect_equal(names(series), c("ano", MEDIDAS$medida))
  expect_equal(nrow(series), length(dados$anos))
  expect_true(series_tem_valor(series))

  # Município fora da base não tem linhas na tabela pronta de séries
  vazio <- series_municipio(dados, 999999)
  expect_equal(names(vazio), c("ano", MEDIDAS$medida))
  expect_equal(nrow(vazio), 0)
  expect_false(series_tem_valor(vazio))

  # O município com ano faltante mantém a linha do ano, mas com NA
  lacuna <- dados$series[is.na(dados$series$indice_final), c("codmunres", "ano")][1, ]
  serie_lacuna <- series_municipio(dados, lacuna$codmunres)
  expect_true(is.na(serie_lacuna$indice_final[serie_lacuna$ano == lacuna$ano]))
})

test_that("grafico_evolucao desenha uma medida com o nome no fim da linha", {
  # Sem comparação existe apenas a série principal, com a cor da medida
  grafico <- grafico_evolucao(series_teste, "indice_final", nome = "Dois (RO)")
  expect_length(grafico$x$opts$series, 1)
  serie <- grafico$x$opts$series[[1]]
  expect_equal(serie$name, "Dois (RO)")
  expect_equal(serie$itemStyle$color, cor_medida("indice_final"))
  expect_equal(serie$lineStyle$type, "solid")
  expect_true(serie$showSymbol)

  # O nome da localidade é o rótulo do fim da linha, sem legenda no gráfico
  expect_true(serie$endLabel$show)
  expect_equal(serie$endLabel$formatter, "{a}")
  expect_equal(serie$endLabel$align, "right")
  expect_false(isTRUE(grafico$x$opts$legend$show))

  # O eixo X precisa formatar os anos como inteiros, sem separador de milhar
  formatter <- grafico$x$opts$xAxis[[1]]$axisLabel$formatter
  expect_s3_class(formatter, "JS_EVAL")
  expect_true(grepl("Math.round", as.character(formatter)))

  # O eixo Y começa no piso e termina no teto calculados da própria medida
  expect_equal(grafico$x$opts$yAxis[[1]]$min, 70)
  expect_equal(grafico$x$opts$yAxis[[1]]$max, 90)

  # Os dois limites podem ser fixados pelo módulo na comparação
  compartilhado <- grafico_evolucao(
    series_teste, "indice_final",
    minimo_y = 70, maximo_y = 95
  )
  expect_equal(compartilhado$x$opts$yAxis[[1]]$min, 70)
  expect_equal(compartilhado$x$opts$yAxis[[1]]$max, 95)

  # Um piso colado no teto sobe o topo para o eixo não degenerar
  degenerado <- grafico_evolucao(series_teste, "indice_final", minimo_y = 90)
  expect_equal(degenerado$x$opts$yAxis[[1]]$min, 90)
  expect_equal(degenerado$x$opts$yAxis[[1]]$max, 100)

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
  # A marca da comparação usa a mesma cor clareada em direção ao branco
  expect_true(grepl("clarear", tooltip, fixed = TRUE))
  expect_true(grepl("0.55", tooltip, fixed = TRUE))
  expect_false(grepl("rgba(", tooltip, fixed = TRUE))
  expect_false(grepl("IBISMA", tooltip, fixed = TRUE))

  # O tooltip acompanha o cursor com transição mais curta que o padrão do echarts
  expect_equal(grafico$x$opts$tooltip$transitionDuration, 0.3)
  expect_equal(grafico$x$opts$tooltip$trigger, "axis")
})

test_that("grafico_evolucao destaca a comparação com traço pontilhado", {
  comparacao <- series_teste
  comparacao$bloco1 <- c(40, 90)
  grafico <- grafico_evolucao(
    series_teste, "bloco1",
    nome = "Dois (RO)",
    comparacao = comparacao,
    nome_comparacao = "Quatro (SP)"
  )

  # As duas localidades usam a mesma cor, diferenciadas pelo traço
  expect_length(grafico$x$opts$series, 2)
  linha_principal <- grafico$x$opts$series[[1]]
  linha_comparada <- grafico$x$opts$series[[2]]
  expect_equal(linha_comparada$name, "Quatro (SP)")
  expect_equal(linha_principal$lineStyle$color, cor_medida("bloco1"))
  expect_equal(linha_comparada$lineStyle$color, cor_medida("bloco1"))
  expect_equal(linha_comparada$lineStyle$type, "dotted")
  expect_true(linha_comparada$lineStyle$opacity < 1)
  expect_true(linha_comparada$z < linha_principal$z)

  # Os dois nomes vão para o fim das linhas, respeitando o lado calculado
  expect_equal(linha_principal$endLabel$formatter, "{a}")
  expect_equal(linha_comparada$endLabel$formatter, "{a}")

  # Nenhuma série apaga a outra no hover (sem foco de série no destaque)
  expect_null(linha_principal$emphasis)
  expect_null(linha_comparada$emphasis)
})

test_that("lados_rotulos separa rótulos próximos e respeita as bordas do eixo", {
  # Fins bem separados mantêm cada rótulo no lado natural do próprio ponto
  lados <- lados_rotulos(data.frame(principal = c(1, 95), comparacao = c(1, 60)), 50, 100)
  expect_equal(lados$principal$lado, "abaixo")
  expect_equal(lados$comparacao$lado, "acima")

  # Fins próximos e longe do topo ficam em lados opostos
  lados <- lados_rotulos(data.frame(principal = c(60, 70), comparacao = c(60, 68)), 50, 100)
  expect_equal(lados$principal$lado, "acima")
  expect_equal(lados$comparacao$lado, "abaixo")

  # Fins próximos e perto do topo descem juntos, com afastamentos diferentes
  lados <- lados_rotulos(data.frame(principal = c(60, 99), comparacao = c(60, 98.5)), 90, 100)
  expect_equal(lados$principal$lado, "abaixo")
  expect_equal(lados$comparacao$lado, "abaixo")
  expect_true(lados$principal$afastamento != lados$comparacao$afastamento)

  # Fins próximos e no piso do eixo sobem juntos, com afastamentos diferentes
  lados <- lados_rotulos(data.frame(principal = c(95, 91), comparacao = c(1, 90.5)), 90, 100)
  expect_equal(lados$principal$lado, "acima")
  expect_equal(lados$comparacao$lado, "acima")
  expect_true(lados$principal$afastamento != lados$comparacao$afastamento)

  # Sem comparação o rótulo sobe, a menos que a série termine no topo
  expect_equal(lados_rotulos(data.frame(principal = c(60, 70)), 50, 100)$principal$lado, "acima")
  expect_equal(lados_rotulos(data.frame(principal = c(60, 95)), 50, 100)$principal$lado, "abaixo")

  # O teto menor encolhe a faixa e aproxima o corte de "perto do topo"
  expect_equal(lados_rotulos(data.frame(principal = c(60, 78)), 50, 80)$principal$lado, "abaixo")
})

test_that("piso_eixo_y arredonda o menor valor para baixo na dezena", {
  # O menor valor da série fica em 25, então o eixo começa em 20
  expect_equal(piso_eixo_y(series_teste), 20)

  # O piso pode ser calculado apenas com um grupo de medidas
  expect_equal(piso_eixo_y(series_teste, "indice_final"), 70)
  expect_equal(piso_eixo_y(series_teste, BLOCOS$medida), 20)

  # Valores altos aproximam o piso de 100, sem criar um eixo degenerado
  alto <- series_teste
  alto[, MEDIDAS$medida] <- 95
  alto$indice_final[alto$ano == 2021] <- 91
  expect_equal(piso_eixo_y(alto), 90)

  cem <- series_teste
  cem[, MEDIDAS$medida] <- 100
  expect_equal(piso_eixo_y(cem), 90)

  # Série sem valor algum mantém o eixo na escala completa
  vazio <- series_teste
  vazio[, MEDIDAS$medida] <- NA_real_
  expect_equal(piso_eixo_y(vazio), 0)
})

test_that("teto_eixo_y arredonda o maior valor para cima na dezena", {
  # O maior valor da série fica em 90, então o eixo termina em 90
  expect_equal(teto_eixo_y(series_teste), 90)

  # O teto pode ser calculado apenas com um grupo de medidas
  expect_equal(teto_eixo_y(series_teste, "indice_final"), 90)
  expect_equal(teto_eixo_y(series_teste, BLOCOS$medida), 90)

  # Valores baixos mantêm uma dezena mínima para o eixo não degenerar
  baixo <- series_teste
  baixo[, MEDIDAS$medida] <- 5
  expect_equal(teto_eixo_y(baixo), 10)

  # Valores no topo da escala param no limite do índice
  alto <- series_teste
  alto[, MEDIDAS$medida] <- 95
  expect_equal(teto_eixo_y(alto), 100)

  # Série sem valor algum mantém o eixo na escala completa
  vazio <- series_teste
  vazio[, MEDIDAS$medida] <- NA_real_
  expect_equal(teto_eixo_y(vazio), 100)
})

test_that("a evolução usa limites de eixo por grupo de medidas", {
  dados <- dados_ibisma()
  principal <- municipio_padrao(dados)
  comparado <- dados$municipios$codmunres[dados$municipios$codmunres != principal][1]
  ano_ref <- max(dados$anos)

  # Calculando os limites esperados para conferir o que o módulo entrega
  series_principal_ref <- series_municipio(dados, principal)
  series_comparacao_ref <- series_municipio(dados, comparado)
  limites_indice <- c(
    min(
      piso_eixo_y(series_principal_ref, "indice_final"),
      piso_eixo_y(series_comparacao_ref, "indice_final")
    ),
    max(
      teto_eixo_y(series_principal_ref, "indice_final"),
      teto_eixo_y(series_comparacao_ref, "indice_final")
    )
  )

  municipio <- shiny::reactiveVal(principal)
  shiny::testServer(
    mod_como_server,
    args = list(dados = dados, municipio = municipio),
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

      # O IBISMA tem escala própria, cobrindo os dois índices sem cortá-los
      expect_equal(opcoes_do_grafico(output$grafico_indice_final)$yAxis[[1]]$min, limites_indice[1])
      expect_equal(opcoes_do_grafico(output$grafico_indice_final)$yAxis[[1]]$max, limites_indice[2])

      # Os seis blocos compartilham a mesma escala entre os cartões
      min_blocos <- opcoes_do_grafico(output$grafico_bloco1)$yAxis[[1]]$min
      max_blocos <- opcoes_do_grafico(output$grafico_bloco1)$yAxis[[1]]$max
      for (medida in BLOCOS$medida[-1]) {
        opcoes <- opcoes_do_grafico(output[[paste0("grafico_", medida)]])
        expect_equal(opcoes$yAxis[[1]]$min, min_blocos)
        expect_equal(opcoes$yAxis[[1]]$max, max_blocos)
      }

      # Cada gráfico desenha a localidade principal e a comparação
      series_bloco <- opcoes_do_grafico(output$grafico_bloco1)$series
      expect_length(series_bloco, 2)
      expect_equal(series_bloco[[2]]$lineStyle$type, "dotted")

      # A identificação reúne os dois municípios e o período dos gráficos
      identificacao <- as.character(output$evolucao_identificacao$html)
      expect_true(grepl(nome_municipio(dados, principal), identificacao, fixed = TRUE))
      expect_true(grepl(nome_municipio(dados, comparado), identificacao, fixed = TRUE))
      expect_true(grepl(as.character(ano_ref), identificacao, fixed = TRUE))

      # Sem comparação o eixo do IBISMA segue apenas o município principal
      session$setInputs(comparar = "nenhum")
      expect_equal(
        opcoes_do_grafico(output$grafico_indice_final)$yAxis[[1]]$min,
        piso_eixo_y(series_principal_ref, "indice_final")
      )
      expect_equal(
        opcoes_do_grafico(output$grafico_indice_final)$yAxis[[1]]$max,
        teto_eixo_y(series_principal_ref, "indice_final")
      )
      expect_length(opcoes_do_grafico(output$grafico_bloco1)$series, 1)

      # A identificação cita apenas o município principal
      identificacao <- as.character(output$evolucao_identificacao$html)
      expect_true(grepl(nome_municipio(dados, principal), identificacao, fixed = TRUE))
      expect_false(grepl(nome_municipio(dados, comparado), identificacao, fixed = TRUE))

      # Com o principal sem dado, os gráficos ficam suspensos na grade
      session$setInputs(comparar = as.character(comparado), municipio = "999999")
      expect_error(output$grafico_indice_final, class = "shiny.silent.error")
      expect_error(output$evolucao_identificacao, class = "shiny.silent.error")
    }
  )
})

test_that("os títulos da evolução levam a bolinha da dimensão", {
  grade <- as.character(grade_evolucao_ui(shiny::NS("como")))
  # Cada um dos sete cartões tem a própria bolinha com a cor da medida
  expect_equal(
    lengths(regmatches(grade, gregexpr("evolucao-card__ponto", grade))),
    7
  )
  expect_true(grepl(
    paste0("--cor-medida:", cor_medida("indice_final")),
    grade,
    fixed = TRUE
  ))
  expect_true(grepl(
    paste0("--cor-medida:", cor_medida("bloco3")),
    grade,
    fixed = TRUE
  ))
})

test_that("formatadores usam a convenção brasileira", {
  expect_equal(formatar_numero(12.345), "12,3")
  expect_equal(formatar_numero(c(1.5, NA)), c("1,5", "Sem dados"))
  expect_equal(formatar_inteiro(5570), "5.570")
  expect_equal(rotulo_posicao(1234, 5570), "1.234º de 5.570")
  # Todos os valores do painel são exibidos com uma casa decimal
  expect_equal(formatar_numero(99.96), "100,0")
  expect_equal(formatar_numero(0.04), "0,0")
})

test_that("frase_percentil limita o texto a 99,9% com uma casa decimal", {
  expect_match(frase_percentil(99.96), "99,9%")
  expect_match(frase_percentil(100), "99,9%")
  expect_match(frase_percentil(50), "50,0%")
  expect_match(frase_percentil(NA), "Sem dado")
})

test_that("paletas e cores seguem a configuração do projeto", {
  expect_setequal(names(PALETAS), MEDIDAS$medida)
  expect_equal(cor_medida("bloco1"), BLOCOS$cor[1])
  expect_equal(cor_medida("indice_final"), COR_IBISMA)
  expect_equal(cor_categoria(NA_character_), COR_SEM_DADOS)
  expect_equal(cor_texto_sobre("#FFFFFF"), COR_AZUL_ESCURO)
  expect_equal(cor_texto_sobre("#0A1E3C"), "#FFFFFF")

  # A rampa de um bloco deve ter cinco tons distintos
  rampa <- unname(PALETAS[["bloco3"]])
  expect_length(rampa, 5)
  expect_equal(length(unique(rampa)), 5)
})

test_that("opções de medida, ano e escopo do ranking estão completas", {
  exigir_base()
  # As medidas do seletor são o dicionário central, com o prefixo "Bloco" nos rótulos
  expect_equal(MEDIDAS$rotulo[-1], paste("Bloco", MEDIDAS$nome[-1]))
  expect_equal(dados_ibisma()$anos, sort(unique(base_referencia$ano)))

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
  siglas_uf <- unique(dados_ibisma()$municipios$sigla_uf)
  expect_setequal(opcoes$value[-1], siglas_uf)
})

test_that("nome_medida prefixa os blocos com Bloco quando pedido", {
  # O IBISMA nunca recebe o prefixo
  expect_equal(nome_medida("indice_final", prefixo_bloco = TRUE), "IBISMA")
  expect_equal(
    nome_medida("bloco2", prefixo_bloco = TRUE),
    "Bloco Planejamento Reprodutivo"
  )
  # Sem o prefixo, os nomes continuam como configurados
  expect_equal(
    nome_medida(c("indice_final", "bloco2")),
    c("IBISMA", "Planejamento Reprodutivo")
  )
})

test_that("tema_reactable adapta os destaques à cor da medida", {
  # No IBISMA os destaques continuam roxos e com texto branco
  ibisma <- tema_reactable("indice_final")
  expect_equal(ibisma$highlightColor, misturar_cores(COR_IBISMA, "#FFFFFF", 0.94))
  expect_equal(
    ibisma$rowSelectedStyle$backgroundColor,
    misturar_cores(COR_IBISMA, "#FFFFFF", 0.90)
  )
  expect_equal(ibisma$pageButtonActiveStyle$backgroundColor, COR_IBISMA)
  expect_equal(ibisma$pageButtonActiveStyle$color, "#FFFFFF")

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
  dados <- dados_ibisma()
  ano <- max(dados$anos)
  foco <- municipio_padrao(dados)

  # Ordenando os rankings como o módulo faz, para conferir as posições
  base_indice <- valores_ano(dados, ano, "indice_final")
  ranking_indice <- base_indice[order(base_indice$valor, decreasing = TRUE, na.last = TRUE), ]
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
    args = list(dados = dados, municipio = municipio),
    {
      # Lendo o destaque marcado já na montagem do widget (índice 0-based)
      destaque_do_render <- function() {
        widget <- jsonlite::fromJSON(output$ranking, simplifyVector = FALSE)
        unlist(widget$x$tag$attribs$defaultSelected)
      }

      session$setInputs(
        ano = as.character(ano),
        medida = "indice_final",
        escopo = "nacional"
      )
      # O município padrão lidera o índice final e já vem marcado no próprio render
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

      base_bloco <- valores_ano(dados, ano, "bloco6")
      ranking_bloco <- base_bloco[order(base_bloco$valor, decreasing = TRUE, na.last = TRUE), ]
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

test_that("o ranking descreve o clique na tabela logo acima dela", {
  ui <- as.character(mod_onde_ui("onde"))
  # A dica usa a classe de descrição com o modificador de respiro da tabela
  expect_true(grepl(
    paste0(
      'class="bloco-descricao bloco-descricao--tabela"',
      ">Clique em um município para destacá-lo em todo o painel.</p>"
    ),
    ui,
    fixed = TRUE
  ))
  # O resumo fica sem a classe de descrição
  expect_false(grepl("esqueleto-slot--texto bloco-descricao", ui, fixed = TRUE))
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
  dados <- dados_ibisma()
  malha <- carregar_malha_municipios()
  base <- dados_mapa(dados, max(dados$anos), "indice_final")
  atualizar_municipios(sessao, "mapa", base, "indice_final")

  expect_equal(capturada$tipo, "ibisma_mapa_atualiza")
  mensagem <- capturada$mensagem
  # Os dados vão em vetores alinhados à malha, sem HTML de tooltip
  expect_equal(mensagem$id, "mapa")
  expect_equal(mensagem$medida, "IBISMA")
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
  dados <- dados_ibisma()
  base <- dados_mapa(dados, max(dados$anos), "indice_final")
  enviar_desenho_municipios(sessao, "mapa", base, "indice_final")

  expect_equal(capturada$tipo, "ibisma_mapa_desenha")
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
  dados <- dados_ibisma()
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
  dados <- dados_ibisma()
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

test_that("municipio_padrao escolhe o mais vulnerável do último ano", {
  dados <- dados_ibisma()
  base <- valores_ano(dados, max(dados$anos), "indice_final")
  expect_equal(
    municipio_padrao(dados),
    base$codmunres[which.max(base$valor)]
  )
})

test_that("nome_municipio devolve nome e sigla", {
  dados <- dados_ibisma()
  info <- dados$municipios[1, ]
  expect_equal(
    nome_municipio(dados, info$codmunres),
    paste0(info$municipio, " (", info$sigla_uf, ")")
  )
  expect_equal(nome_municipio(dados, 999999), "Município")
})

test_that("nome_uf traduz a sigla no nome por extenso", {
  dados <- dados_ibisma()
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
  for (sigla in unique(dados_ibisma()$municipios$sigla_uf)) {
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
  dados <- dados_ibisma()
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
    args = list(dados = dados, municipio = municipio),
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
  # O índice tem a cor de identificação no topo da rampa
  expect_equal(unname(PALETAS$indice_final[5]), COR_IBISMA)

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
  expect_true(grepl("petalas-legenda", html, fixed = TRUE))
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

test_that("perfil_palco monta identificação, pétalas e placar", {
  dados <- dados_ibisma()
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
  expect_true(grepl(paste0("IBISMA em ", ano), html, fixed = TRUE))
  expect_true(grepl("perfil-placar", html, fixed = TRUE))
  # O ranking estadual não repete o nome da UF no título
  expect_true(grepl("Ranking na UF", html, fixed = TRUE))
  expect_false(grepl("Ranking na UF (", html, fixed = TRUE))
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
})

test_that("perfil_palco mostra estado vazio quando não há dado no ano", {
  dados <- dados_ibisma()
  cod <- municipio_padrao(dados)
  municipio <- dados$municipios[dados$municipios$codmunres == cod, ]
  html <- as.character(perfil_palco(municipio, NULL, ano = max(dados$anos)))
  expect_true(grepl("não possui dados no ano selecionado", html, fixed = TRUE))
  expect_false(grepl("perfil-placar", html, fixed = TRUE))
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

  # O palco mantém identificação, pétalas e placar na mesma composição
  palco <- as.character(esqueleto_palco())
  expect_true(grepl("perfil-nome", palco))
  expect_true(grepl("perfil-metricas", palco))
  expect_true(grepl("svg-petalas", palco))
  expect_true(grepl("perfil-placar", palco))
  expect_equal(
    lengths(regmatches(palco, gregexpr("esqueleto__disco", palco))),
    6
  )
  # O esqueleto não deve repetir nenhum valor do conteúdo real
  expect_false(grepl("IBISMA em", palco))

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
  expect_equal(
    lengths(regmatches(evolucao, gregexpr("esqueleto__barra--rotulo", evolucao))),
    28
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
