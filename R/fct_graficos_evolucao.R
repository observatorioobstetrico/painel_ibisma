# =============================================================================
#   FUNÇÕES AUXILIARES DA EVOLUÇÃO TEMPORAL
#   Monta os gráficos de evolução do Índice VIDAS e dos seis blocos com echarts4r
#   (licença Apache 2.0). O leque de pétalas fica em fct_petalas.R, em SVG.
# =============================================================================

# Definindo a família de fontes usada em todos os gráficos
FONTE_GRAFICOS <- "'Source Sans Pro', system-ui, -apple-system, sans-serif"

# Definindo o estilo compartilhado dos tooltips do echarts
CSS_TOOLTIP <- paste0(
  "border-radius:10px;",
  "box-shadow:0 6px 20px rgba(10,30,60,.14);",
  "padding:10px 12px;"
)

# Definindo as alturas dos gráficos de evolução do índice e dos blocos
ALTURA_GRAFICO_VIDAS <- 240L
ALTURA_GRAFICO_BLOCO <- 170L

# Definindo a altura dos gráficos de evolução dos indicadores, igual à dos blocos
ALTURA_GRAFICO_INDICADOR <- ALTURA_GRAFICO_BLOCO

# Definindo a largura mínima para manter os rótulos de ano na horizontal
LARGURA_ROTULOS_ANOS <- 340L

# Definindo o número de marcações equiespaçadas do eixo Y de todos os gráficos
MARCACOES_EIXO <- 5L

# Definindo os passos redondos usados nos eixos dos indicadores
PASSOS_EIXO <- c(1, 1.5, 2, 2.5, 5, 10)

# Definindo os passos redondos dos eixos das medidas (sempre inteiros)
PASSOS_MEDIDA <- c(1, 2, 5, 10)

# Definindo a opacidade do preenchimento sob as linhas da evolução (0 desliga)
OPACIDADE_AREA_EVOLUCAO <- 0

#' Definindo uma função que aplica o tooltip padrão do painel a um gráfico echarts4r
#'
#' @param grafico Objeto echarts4r.
#' @param trigger Modo de acionamento do tooltip ("item" ou "axis").
#' @param formatter Função JavaScript com o conteúdo do tooltip (opcional).
#' @param extras Lista com opções adicionais do tooltip (opcional).
#' @return Objeto echarts4r com o tooltip configurado.
#' Usada em: fct_graficos_evolucao.R (grafico_evolucao).
#' @noRd
tooltip_echarts <- function(grafico, trigger = "item", formatter = NULL, extras = list()) {
  # Reunindo o estilo padrão com as opções específicas de cada gráfico
  opcoes <- c(
    list(
      trigger = trigger,
      backgroundColor = "#FFFFFF",
      borderColor = "#E3E6EB",
      borderWidth = 1,
      textStyle = list(
        color = COR_AZUL_ESCURO,
        fontFamily = "Source Sans Pro",
        fontSize = 12
      ),
      extraCssText = CSS_TOOLTIP,
      # Encurtando a transição padrão do echarts (0,4 s), que deixa o tooltip
      # deslizando demais atrás do cursor nas varreduras do mouse
      transitionDuration = 0.3,
      confine = TRUE
    ),
    extras
  )
  if (!is.null(formatter)) {
    opcoes$formatter <- htmlwidgets::JS(formatter)
  }
  do.call(echarts4r::e_tooltip, c(list(grafico), opcoes))
}

#' Definindo uma função que calcula a faixa do eixo Y de um conjunto de valores
#'
#' @param valores Vetor de valores exibidos nos gráficos.
#' @param passo_minimo Menor passo aceito, igual à precisão do dado.
#' @param passos Passos redondos candidatos, em ordem crescente.
#' @param limite_maximo Maior valor permitido no topo do eixo.
#' @return Lista com min, max e passo de um eixo de cinco marcações.
#' Usada em: fct_graficos_evolucao.R (limites_medidas e limites_indicador).
#' @noRd
limites_eixo <- function(valores, passo_minimo = 1, passos = PASSOS_EIXO,
                         limite_maximo = Inf) {
  valores <- valores[is.finite(valores)]
  intervalos <- MARCACOES_EIXO - 1L

  # Abrindo uma faixa neutra quando não há valor para desenhar
  if (length(valores) == 0) {
    return(list(min = 0, max = intervalos * passo_minimo, passo = passo_minimo))
  }

  # Dando folga em torno de uma série constante (ex.: IDHM fixo no tempo)
  inicio <- min(valores)
  fim <- max(valores)
  if (inicio == fim) {
    folga <- abs(inicio) * 0.1
    # Garantindo uma folga mínima para séries constantes próximas de zero
    if (abs(inicio) < 1) folga <- max(folga, 0.05)
    inicio <- max(0, inicio - folga)
    fim <- fim + folga
  }

  # Buscando o menor passo que cobre os dados nas cinco marcações
  candidatos <- passos_do_eixo(fim - inicio, passo_minimo, passos)
  # Acrescentando o passo que fecha o teto do dado exatamente na última marcação
  if (is.finite(limite_maximo)) {
    candidatos <- sort(unique(c(candidatos, limite_maximo / intervalos)))
  }
  # Descartando passos cuja faixa completa passaria do teto do dado (ex.: 100)
  if (is.finite(limite_maximo)) {
    candidatos <- candidatos[intervalos * candidatos <= limite_maximo + 1e-9]
  }
  for (passo in candidatos) {
    # Múltiplos do passo que comportam a janela de cinco marcações
    k_minimo <- ceiling(max(0, fim - intervalos * passo) / passo - 1e-9)
    k_maximo <- floor(inicio / passo + 1e-9)
    if (k_minimo > k_maximo) {
      next
    }
    # Centralizando a janela nos dados, dentro dos múltiplos possíveis
    k <- round((inicio - (intervalos * passo - (fim - inicio)) / 2) / passo)
    k <- min(max(k, k_minimo), k_maximo)
    # Reposicionando a janela para não passar do limite do dado
    base <- min(k * passo, limite_maximo - intervalos * passo)
    base <- max(0, base)
    return(list(min = base, max = base + intervalos * passo, passo = passo))
  }

  # Fallback defensivo: dividindo o teto do dado nas cinco marcações
  if (is.finite(limite_maximo)) {
    passo <- limite_maximo / intervalos
    return(list(min = 0, max = limite_maximo, passo = passo))
  }
  passo <- passos[length(passos)]
  list(min = 0, max = intervalos * passo, passo = passo)
}

#' Definindo uma função que monta o JavaScript que rotaciona os rótulos de ano conforme a largura
#'
#' @return Texto de função JavaScript executada pelo htmlwidgets no cliente.
#' Usada em: fct_graficos_evolucao.R (grafico_evolucao).
#' @noRd
rotulos_anos_js <- function() {
  paste0(
    "function (el) {
       /* Inclinando os anos quando o cartão fica estreito, com mais espaço embaixo */
       var ajustar = function () {
         var widget = window.HTMLWidgets && HTMLWidgets.find('#' + el.id);
         if (!widget || typeof widget.getChart !== 'function') return;
         var grafico = widget.getChart();
         if (!grafico) return;
         var estreito = el.getBoundingClientRect().width < ", LARGURA_ROTULOS_ANOS, ";
         grafico.setOption({
           xAxis: { axisLabel: { rotate: estreito ? 45 : 0 } },
           grid: { bottom: estreito ? 40 : 28 }
         });
       };
       ajustar();
       /* Registrando o acompanhamento de resize uma única vez por elemento */
       if (!el.dataset.rotulosAnos) {
         el.dataset.rotulosAnos = 'sim';
         window.addEventListener('resize', ajustar);
       }
     }"
  )
}

#' Definindo uma função que monta o gráfico de evolução temporal de uma medida
#'
#' @param series Data frame retornado por series_municipio().
#' @param medida Medida desenhada ("indice_final" ou um "bloco1"..."bloco6").
#' @param nome Nome da localidade principal exibido no rótulo e no tooltip.
#' @param comparacao Data frame do município comparado (opcional).
#' @param nome_comparacao Nome do município comparado (opcional).
#' @param limites Faixa e passo do eixo Y; quando NULL, calculados das séries.
#' @return Objeto echarts4r pronto para renderização.
#' Usada em: mod_como.R (grade da evolução).
#' @noRd
grafico_evolucao <- function(series, medida, nome = NULL,
                             comparacao = NULL, nome_comparacao = NULL,
                             limites = NULL) {
  # Identificando a cor do traço e o destaque da medida desenhada
  cor <- cor_linha_medida(medida)
  eh_indice <- identical(medida, "indice_final")

  # Calculando a faixa do eixo quando o módulo não impõe uma escala compartilhada
  if (is.null(limites)) {
    limites <- limites_medidas(series, medida, comparacao)
  }

  # Montando a tabela do gráfico com uma coluna por localidade
  dados <- data.frame(ano = series$ano, principal = series[[medida]])
  if (!is.null(comparacao)) {
    dados$comparacao <- comparacao[[medida]]
  }

  # Reservando ao Índice VIDAS a linha mais espessa e o símbolo maior
  largura <- if (eh_indice) 2.5 else 2
  # Usando o mesmo tamanho de bolinha nas duas séries, a meio caminho do desenho
  tamanho <- if (eh_indice) 7 else 5.5

  # Criando o gráfico e desenhando a série da localidade principal
  grafico <- echarts4r::e_charts(dados, ano, renderer = "svg") |>
    echarts4r::e_line_(
      serie = "principal",
      name = if (is.null(nome)) "Município" else nome,
      symbol = "circle",
      symbolSize = tamanho,
      showSymbol = TRUE,
      z = 3,
      connectNulls = FALSE,
      # Sem foco de série no hover: a outra linha nunca é apagada
      lineStyle = list(width = largura, color = cor, type = "solid"),
      # Sem contorno na bolinha: a linha segue contínua por dentro do marcador
      itemStyle = list(color = cor),
      # Preenchendo a área sob a linha conforme a opacidade configurada
      areaStyle = list(color = cor, opacity = OPACIDADE_AREA_EVOLUCAO)
    )

  # Acrescentando a linha tracejada do município comparado, quando houver
  if (!is.null(dados$comparacao)) {
    grafico <- grafico |>
      echarts4r::e_line_(
        serie = "comparacao",
        name = if (is.null(nome_comparacao)) "Comparação" else nome_comparacao,
        symbol = "circle",
        # Mantendo a bolinha da comparação no mesmo tamanho da principal
        symbolSize = tamanho,
        showSymbol = TRUE,
        # Desenhando abaixo da linha principal, que fica em evidência
        z = 2,
        connectNulls = FALSE,
        # Diferenciando a comparação pelo traço tracejado com pontas arredondadas
        lineStyle = list(
          width = largura,
          color = cor,
          type = c(9, 7),
          cap = "round"
        ),
        itemStyle = list(
          color = "#FFFFFF",
          borderColor = cor,
          borderWidth = 2
        ),
        # Mantendo o mesmo preenchimento da linha principal sob a comparação
        areaStyle = list(color = cor, opacity = OPACIDADE_AREA_EVOLUCAO)
      )
  }

  # Finalizando eixos, tooltip e estilo geral do gráfico
  grafico <- grafico |>
    echarts4r::e_x_axis(
      type = "value",
      min = min(series$ano),
      max = max(series$ano),
      interval = 1,
      # Formando os anos como inteiros, sem o separador de milhar do echarts
      formatter = htmlwidgets::JS(
        "function (valor) { return String(Math.round(valor)); }"
      ),
      axisLabel = list(color = "#5A6472", fontSize = 11),
      axisLine = list(lineStyle = list(color = "#E3E6EB")),
      axisTick = list(show = FALSE),
      splitLine = list(show = FALSE)
    ) |>
    echarts4r::e_y_axis(
      min = limites$min,
      max = limites$max,
      name = NULL,
      # Marcando o eixo no passo redondo calculado para a faixa
      interval = limites$passo,
      axisLabel = list(color = "#5A6472", fontSize = 11),
      axisLine = list(show = FALSE),
      axisTick = list(show = FALSE),
      splitLine = list(lineStyle = list(color = "#EEF0F4"))
    ) |>
    tooltip_echarts(
      trigger = "axis",
      formatter = tooltip_evolucao_js(),
      extras = list(
        axisPointer = list(type = "line", lineStyle = list(color = "#C7CCD4"))
      )
    ) |>
    echarts4r::e_text_style(
      fontFamily = FONTE_GRAFICOS,
      color = COR_AZUL_ESCURO
    ) |>
    # Desligando a legenda do echarts, já que os municípios aparecem como chips
    # na identificação acima da grade
    echarts4r::e_legend(show = FALSE) |>
    # Reservando só a coluna dos números do eixo Y, alinhada ao título do cartão
    echarts4r::e_grid(left = 28, right = 12, top = 16, bottom = 28) |>
    echarts4r::e_animation(duration = 350)

  # Espaçando os rótulos de ano conforme a largura, sem passar pelo servidor
  htmlwidgets::onRender(grafico, rotulos_anos_js())
}

#' Definindo uma função que lista os passos redondos candidatos para um eixo
#'
#' @param faixa Diferença entre o maior e o menor valor exibidos.
#' @param minimo Menor passo aceito, igual à precisão do dado.
#' @param passos Passos redondos candidatos, em ordem crescente.
#' @return Vetor crescente de passos redondos que cobrem a faixa.
#' Usada em: fct_graficos_evolucao.R (limites_eixo).
#' @noRd
passos_do_eixo <- function(faixa, minimo = 0, passos = PASSOS_EIXO) {
  # Partindo das marcações do eixo e montando a escada de passos redondos
  bruto <- max(faixa / (MARCACOES_EIXO - 1L), minimo, 1e-9)
  expoente <- floor(log10(bruto))
  opcoes <- as.vector(outer(passos, 10^(expoente + -1:3), "*"))
  sort(unique(opcoes[opcoes >= bruto * (1 - 1e-9)]))
}

#' Definindo uma função que conta as casas decimais de um passo redondo
#'
#' @param passo Passo do eixo, vindo de passos_do_eixo().
#' @return Número de casas decimais necessárias para exibir o passo.
#' Usada em: fct_graficos_evolucao.R (grafico_evolucao_indicador).
#' @noRd
casas_do_passo <- function(passo) {
  # Decompondo o passo em mantissa e potência de dez
  expoente <- floor(log10(passo))
  mantissa <- passo / 10^expoente
  # Passos com meio (1,5 e 2,5) pedem uma casa a mais que os passos inteiros
  if (abs(mantissa - round(mantissa)) > 1e-9) {
    return(max(0, 1 - expoente))
  }
  max(0, -expoente)
}

#' Definindo uma função que calcula a faixa do eixo de um grupo de medidas
#'
#' @param series Data frame retornado por series_municipio() (pode ser NULL).
#' @param medidas Medidas consideradas no cálculo (o índice ou os seis blocos).
#' @param comparacao Data frame do município comparado (opcional).
#' @return Lista com min, max e passo de um eixo de cinco marcações inteiras.
#' Usada em: fct_graficos_evolucao.R (grafico_evolucao) e mod_como.R (escala compartilhada).
#' @noRd
limites_medidas <- function(series, medidas = MEDIDAS$medida, comparacao = NULL) {
  # Reunindo os valores das medidas pedidas nos municípios exibidos
  colunas <- function(base) {
    if (is.null(base)) {
      return(NULL)
    }
    unlist(base[, intersect(medidas, names(base)), drop = FALSE], use.names = FALSE)
  }
  valores <- c(colunas(series), colunas(comparacao))
  if (length(valores[is.finite(valores)]) == 0) {
    return(list(min = 0, max = 100, passo = 25))
  }

  # Mantendo os números inteiros e o topo dentro dos 100 do percentil
  limites_eixo(valores, 1, PASSOS_MEDIDA, 100)
}

#' Definindo uma função que calcula a faixa e o passo do eixo de um indicador
#'
#' @param series Data frame retornado por series_municipio().
#' @param indicador Identificador do indicador (ex.: "PRE_NATAL").
#' @param comparacao Data frame do município comparado (opcional).
#' @return Lista com min, max e passo de um eixo de cinco marcações.
#' Usada em: fct_graficos_evolucao.R (grafico_evolucao_indicador).
#' @noRd
limites_indicador <- function(series, indicador, comparacao = NULL) {
  # Reunindo os valores do indicador nos municípios exibidos
  info <- info_indicador(indicador)
  valores <- c(series[[indicador]], if (!is.null(comparacao)) comparacao[[indicador]])

  # Respeitando a precisão do indicador e os 100% do que é porcentagem
  limites_eixo(
    valores,
    10^(-info$decimais),
    PASSOS_EIXO,
    if (info$unidade == "%") 100 else Inf
  )
}

#' Definindo uma função que monta o gráfico de evolução temporal de um indicador
#'
#' @param series Data frame retornado por series_municipio().
#' @param indicador Identificador do indicador (ex.: "PRE_NATAL").
#' @param nome Nome da localidade principal exibido no rótulo e no tooltip.
#' @param comparacao Data frame do município comparado (opcional).
#' @param nome_comparacao Nome do município comparado (opcional).
#' @return Objeto echarts4r pronto para renderização.
#' Usada em: mod_como.R (seção de indicadores do bloco).
#' @noRd
grafico_evolucao_indicador <- function(series, indicador, nome = NULL,
                                       comparacao = NULL, nome_comparacao = NULL) {
  # Identificando a cor do bloco do indicador e a escala do eixo
  info <- info_indicador(indicador)
  cor <- cor_linha_medida(info$bloco)
  limites <- limites_indicador(series, indicador, comparacao)
  # Garantindo, em passos fracionários, ao menos as casas do próprio indicador
  casas <- casas_do_passo(limites$passo)
  if (limites$passo < 1) casas <- max(casas, info$decimais)
  # Mostrando o sufixo da unidade no eixo e no tooltip quando fizer sentido
  sufixo <- if (info$unidade %in% c("%", "°C")) info$unidade else ""

  # Montando a tabela do gráfico com uma coluna por localidade
  dados <- data.frame(ano = series$ano, principal = series[[indicador]])
  if (!is.null(comparacao)) {
    dados$comparacao <- comparacao[[indicador]]
  }

  # Criando o gráfico e desenhando a série da localidade principal
  grafico <- echarts4r::e_charts(dados, ano, renderer = "svg") |>
    echarts4r::e_line_(
      serie = "principal",
      name = if (is.null(nome)) "Município" else nome,
      symbol = "circle",
      symbolSize = 4.5,
      showSymbol = TRUE,
      z = 3,
      connectNulls = FALSE,
      # Desenhando o traço com a cor do bloco do indicador
      lineStyle = list(width = 2, color = cor, type = "solid"),
      itemStyle = list(color = cor),
      areaStyle = list(color = cor, opacity = OPACIDADE_AREA_EVOLUCAO)
    )

  # Acrescentando a linha tracejada do município comparado, quando houver
  if (!is.null(dados$comparacao)) {
    grafico <- grafico |>
      echarts4r::e_line_(
        serie = "comparacao",
        name = if (is.null(nome_comparacao)) "Comparação" else nome_comparacao,
        symbol = "circle",
        # Mantendo a bolinha da comparação no mesmo tamanho da principal
        symbolSize = 4.5,
        showSymbol = TRUE,
        # Desenhando abaixo da linha principal, que fica em evidência
        z = 2,
        connectNulls = FALSE,
        # Diferenciando a comparação pelo traço tracejado com pontas arredondadas
        lineStyle = list(
          width = 2,
          color = cor,
          type = c(9, 7),
          cap = "round"
        ),
        itemStyle = list(
          color = "#FFFFFF",
          borderColor = cor,
          borderWidth = 2
        ),
        # Mantendo o mesmo preenchimento da linha principal sob a comparação
        areaStyle = list(color = cor, opacity = OPACIDADE_AREA_EVOLUCAO)
      )
  }

  # Finalizando eixos, tooltip e estilo geral do gráfico
  grafico <- grafico |>
    echarts4r::e_x_axis(
      type = "value",
      min = min(series$ano),
      max = max(series$ano),
      interval = 1,
      # Formando os anos como inteiros, sem o separador de milhar do echarts
      formatter = htmlwidgets::JS(
        "function (valor) { return String(Math.round(valor)); }"
      ),
      axisLabel = list(color = "#5A6472", fontSize = 11),
      axisLine = list(lineStyle = list(color = "#E3E6EB")),
      axisTick = list(show = FALSE),
      splitLine = list(show = FALSE)
    ) |>
    echarts4r::e_y_axis(
      min = limites$min,
      max = limites$max,
      name = NULL,
      # Marcando o eixo no passo redondo do indicador, com as casas do passo
      interval = limites$passo,
      axisLabel = list(
        color = "#5A6472",
        fontSize = 11,
        formatter = htmlwidgets::JS(sprintf(
          "function (valor) { return Number(valor).toFixed(%d).replace('.', ',') + '%s'; }",
          casas, sufixo
        ))
      ),
      axisLine = list(show = FALSE),
      axisTick = list(show = FALSE),
      splitLine = list(lineStyle = list(color = "#EEF0F4"))
    ) |>
    tooltip_echarts(
      trigger = "axis",
      # Usando as casas e a unidade do indicador nos valores do tooltip
      formatter = tooltip_evolucao_js(info$decimais, sufixo),
      extras = list(
        axisPointer = list(type = "line", lineStyle = list(color = "#C7CCD4"))
      )
    ) |>
    echarts4r::e_text_style(
      fontFamily = FONTE_GRAFICOS,
      color = COR_AZUL_ESCURO
    ) |>
    # Desligando a legenda do echarts, já que os municípios aparecem como chips
    # na identificação acima das grades
    echarts4r::e_legend(show = FALSE) |>
    # Deixando o echarts reservar a coluna dos números, encostada no título
    echarts4r::e_grid(left = 0, right = 12, top = 16, bottom = 28, containLabel = TRUE) |>
    echarts4r::e_animation(duration = 350)

  # Espaçando os rótulos de ano conforme a largura, sem passar pelo servidor
  htmlwidgets::onRender(grafico, rotulos_anos_js())
}

#' Definindo uma função que monta o JavaScript do tooltip da evolução temporal
#'
#' @param decimais Número de casas decimais dos valores exibidos.
#' @param sufixo Unidade exibida junto aos valores ("%" ou "°C"), quando houver.
#' @return Texto de função JavaScript para o echarts.
#' Usada em: fct_graficos_evolucao.R (grafico_evolucao e grafico_evolucao_indicador).
#' @noRd
tooltip_evolucao_js <- function(decimais = 1, sufixo = "") {
  paste0(
    "function (params) {
       if (!params || !params.length) return '';
       var f = function (v) { return Number(v).toFixed(", decimais, ").replace('.', ',') + '", sufixo, "'; };
       var g = function (v) { return Number(v).toFixed(", decimais, ").replace('.', ','); };
       /* Buscando a cor das linhas entre as séries: o miolo branco da séries */
       /* comparada esconde a cor real no itemStyle dela */
       var corSerie = '", COR_VIDAS, "';
       for (var k = 0; k < params.length; k++) {
         var candidata = params[k].color;
         if (typeof candidata === 'string' && candidata.toUpperCase() !== '#FFFFFF') {
           corSerie = candidata;
           break;
         }
       }
       /* Montando a marca da série com o traço cheio ou tracejado do gráfico */
       var marca = function (p) {
         var traco = p.seriesIndex === 0
           ? 'background:' + corSerie
           : 'background-image:repeating-linear-gradient(90deg,' +
             corSerie + ' 0 4px,transparent 4px 8px)';
         /* Espelhando a bolinha do gráfico: cheia na principal e vazada na comparação */
         var ponto = p.seriesIndex === 0
           ? 'background:' + corSerie
           : 'background:#FFFFFF;box-shadow:inset 0 0 0 1.5px ' + corSerie;
         /* Fechando a marca de 20px com o ciclo de 8px do tracejado: fica um */
         /* traço em cada ponta e outro sob a bolinha, com os dois lados iguais */
         return '<span style=\"position:relative;display:inline-block;width:20px;height:9px;margin-right:6px;vertical-align:middle;flex:0 0 auto\">' +
                '<span style=\"position:absolute;left:0;right:0;top:3px;height:3px;border-radius:2px;' + traco + '\"></span>' +
                '<span style=\"position:absolute;left:50%;top:1px;width:7px;height:7px;margin-left:-3.5px;border-radius:50%;' + ponto + '\"></span>' +
                '</span>';
       };
       var ano = String(Math.round(params[0].axisValue));
       var valores = [];
       var s = '<b>' + ano + '</b>';
       params.forEach(function (p) {
         var v = p.value;
         if (Array.isArray(v)) { v = v[v.length - 1]; }
         if (v === null || v === undefined || isNaN(v)) return;
         valores.push(Number(v));
         s += '<div style=\"display:flex;align-items:center;justify-content:space-between;gap:1.5rem\">' +
              '<span>' + marca(p) + p.seriesName + '</span><b>' + f(v) + '</b></div>';
       });
       /* Mostrando a diferença entre os municípios quando as duas séries têm valor */
       if (valores.length === 2) {
         s += '<div style=\"display:flex;align-items:center;justify-content:space-between;gap:1.5rem;margin-top:5px;padding-top:5px;border-top:1px solid #EEF0F4;color:#5A6472\">' +
              '<span>Diferença</span>' +
              '<b style=\"color:#5A6472;font-weight:600\">' + g(Math.abs(valores[0] - valores[1])) + '</b></div>';
       }
       return s;
     }"
  )
}

#' Definindo uma função que monta a grade de gráficos da evolução temporal
#'
#' @param ns Função de namespace do módulo.
#' @return Elemento HTML com o cartão do Índice VIDAS e os seis cartões dos blocos.
#' Usada em: mod_como.R (grade da evolução).
#' @noRd
grade_evolucao_ui <- function(ns) {
  # Montando um cartão com o título e o gráfico de uma medida
  cartao <- function(medida, altura, classe = NULL) {
    htmltools::tags$div(
      class = paste(c("evolucao-card", classe), collapse = " "),
      htmltools::tags$h4(
        class = "evolucao-card__titulo",
        nome_medida(medida)
      ),
      echarts4r::echarts4rOutput(
        ns(paste0("grafico_", medida)),
        height = paste0(altura, "px")
      )
    )
  }

  htmltools::tags$div(
    class = "evolucao-grade",
    # Destacando o Índice VIDAS em um cartão de largura total
    cartao("indice_final", ALTURA_GRAFICO_VIDAS, "evolucao-card--vidas"),
    # Organizando os seis blocos em pequenos múltiplos
    htmltools::tags$h4(class = "evolucao-grade__titulo", "Dimensões do Índice VIDAS"),
    # Identificando os municípios logo abaixo do título dos blocos
    htmltools::tags$div(
      class = "evolucao-identificacao--blocos",
      shiny::uiOutput(ns("evolucao_identificacao_blocos"))
    ),
    lapply(seq_len(nrow(BLOCOS)), function(i) {
      cartao(BLOCOS$medida[i], ALTURA_GRAFICO_BLOCO)
    })
  )
}
