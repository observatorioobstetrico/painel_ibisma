# =============================================================================
#   FUNÇÕES AUXILIARES DA EVOLUÇÃO TEMPORAL
#   Monta os gráficos de evolução do IBISMA e dos seis blocos com echarts4r
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
ALTURA_GRAFICO_IBISMA <- 270L
ALTURA_GRAFICO_BLOCO <- 160L

# Definindo a largura mínima para manter os rótulos de ano na horizontal
LARGURA_ROTULOS_ANOS <- 340L

# Definindo o passo dos ticks e das linhas de grade do eixo Y
PASSO_EIXO_Y <- 25

#' Definindo uma função que aplica o tooltip padrão do IBISMA a um gráfico echarts4r
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

#' Definindo uma função que calcula o piso do eixo Y de um conjunto de séries
#'
#' @param series Data frame retornado por series_municipio().
#' @param medidas Medidas consideradas no cálculo (o índice ou os seis blocos).
#' @return Piso em múltiplo de 25 para o eixo começar perto dos dados (0 a 75).
#' Usada em: fct_graficos_evolucao.R (grafico_evolucao) e mod_como.R (limites do eixo).
#' @noRd
piso_eixo_y <- function(series, medidas = MEDIDAS$medida) {
  # Reunindo os valores das medidas pedidas em um único vetor
  colunas <- intersect(medidas, names(series))
  valores <- unlist(series[, colunas, drop = FALSE], use.names = FALSE)
  if (all(is.na(valores))) {
    return(0)
  }

  # Arredondando o menor valor para baixo no múltiplo de 25 e evitando eixo degenerado
  piso <- floor(min(valores, na.rm = TRUE) / PASSO_EIXO_Y) * PASSO_EIXO_Y
  max(0, min(piso, 100 - PASSO_EIXO_Y))
}

#' Definindo uma função que calcula o teto do eixo Y de um conjunto de séries
#'
#' @param series Data frame retornado por series_municipio().
#' @param medidas Medidas consideradas no cálculo (o índice ou os seis blocos).
#' @return Teto em múltiplo de 25 para o eixo terminar perto dos dados (25 a 100).
#' Usada em: fct_graficos_evolucao.R (grafico_evolucao) e mod_como.R (limites do eixo).
#' @noRd
teto_eixo_y <- function(series, medidas = MEDIDAS$medida) {
  # Reunindo os valores das medidas pedidas em um único vetor
  colunas <- intersect(medidas, names(series))
  valores <- unlist(series[, colunas, drop = FALSE], use.names = FALSE)
  if (all(is.na(valores))) {
    return(100)
  }

  # Arredondando o maior valor para cima no múltiplo de 25 e respeitando o limite do índice
  teto <- ceiling(max(valores, na.rm = TRUE) / PASSO_EIXO_Y) * PASSO_EIXO_Y
  min(100, max(PASSO_EIXO_Y, teto))
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
#' @param minimo_y Piso do eixo Y; quando NULL, calculado das próprias séries.
#' @param maximo_y Teto do eixo Y; quando NULL, calculado das próprias séries.
#' @return Objeto echarts4r pronto para renderização.
#' Usada em: mod_como.R (grade da evolução).
#' @noRd
grafico_evolucao <- function(series, medida, nome = NULL,
                             comparacao = NULL, nome_comparacao = NULL,
                             minimo_y = NULL, maximo_y = NULL) {
  # Identificando a cor e o destaque da medida desenhada
  cor <- cor_medida(medida)
  eh_indice <- identical(medida, "indice_final")
  # Escurecendo o traço do Social, cujo amarelo some em linha fina sobre o branco
  if (identical(medida, "bloco1")) {
    cor <- COR_LINHA_SOCIAL
  }

  # Calculando o piso do eixo quando o módulo não impõe um valor compartilhado
  if (is.null(minimo_y)) {
    minimo_y <- piso_eixo_y(series, medida)
  }
  # Calculando o teto do eixo quando o módulo não impõe um valor compartilhado
  if (is.null(maximo_y)) {
    maximo_y <- teto_eixo_y(series, medida)
  }
  # Evitando um eixo degenerado quando piso e teto caem no mesmo múltiplo
  if (maximo_y <= minimo_y) {
    maximo_y <- min(100, minimo_y + PASSO_EIXO_Y)
  }

  # Montando a tabela do gráfico com uma coluna por localidade
  dados <- data.frame(ano = series$ano, principal = series[[medida]])
  if (!is.null(comparacao)) {
    dados$comparacao <- comparacao[[medida]]
  }

  # Reservando ao IBISMA a linha mais espessa e o símbolo maior
  largura <- if (eh_indice) 3 else 2
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
      # Preenchendo a área sob a linha com um véu chapado bem discreto
      areaStyle = list(color = cor, opacity = 0.07)
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
        # Mantendo o mesmo véu chapado da linha principal sob a comparação
        areaStyle = list(color = cor, opacity = 0.07)
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
      min = minimo_y,
      max = maximo_y,
      name = NULL,
      # Marcando o eixo de 25 em 25, como as linhas de grade do desenho
      interval = PASSO_EIXO_Y,
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

#' Definindo uma função que monta o JavaScript do tooltip da evolução temporal
#'
#' @return Texto de função JavaScript para o echarts.
#' Usada em: fct_graficos_evolucao.R (grafico_evolucao).
#' @noRd
tooltip_evolucao_js <- function() {
  paste0(
    "function (params) {
       if (!params || !params.length) return '';
       var f = function (v) { return Number(v).toFixed(1).replace('.', ','); };
       /* Buscando a cor das linhas entre as séries: o miolo branco da séries */
       /* comparada esconde a cor real no itemStyle dela */
       var corSerie = '#4B1D73';
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
              '<b style=\"color:#5A6472;font-weight:600\">' + f(Math.abs(valores[0] - valores[1])) + '</b></div>';
       }
       return s;
     }"
  )
}

#' Definindo uma função que monta a grade de gráficos da evolução temporal
#'
#' @param ns Função de namespace do módulo.
#' @return Elemento HTML com o cartão do IBISMA e os seis cartões dos blocos.
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
    # Destacando o IBISMA em um cartão de largura total
    cartao("indice_final", ALTURA_GRAFICO_IBISMA, "evolucao-card--ibisma"),
    # Organizando os seis blocos em pequenos múltiplos
    htmltools::tags$h4(class = "evolucao-grade__titulo", "Blocos do IBISMA"),
    lapply(seq_len(nrow(BLOCOS)), function(i) {
      cartao(BLOCOS$medida[i], ALTURA_GRAFICO_BLOCO)
    })
  )
}
