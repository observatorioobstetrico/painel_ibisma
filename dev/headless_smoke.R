#!/usr/bin/env Rscript

# =============================================================================
#   SMOKE TEST VISUAL/HEADLESS DO PAINEL VIDAS
#   Sobe o app em segundo plano, abre o Chrome headless, espera um seletor,
#   tira um screenshot, avalia JavaScript opcional e derruba o servidor.
#
#   Uso (na raiz do pacote):
#     Rscript dev/headless_smoke.R [--port=4848] [--outdir=dev/smoke]
#       [--wait-for=".seletor"] [--shot=nome.png] [--eval="<JS>"]
#       [--pre-eval="<JS>"] [--eval-file=arq.js] [--pre-eval-file=arq.js]
#       [--width=1600] [--height=900] [--scroll=0] [--mobile] [--dpr=1.25]
#       [--motion] [--reduce] [--tap=x,y] [--tap2=x,y]
#
#   O JavaScript passado em --eval deve retornar uma STRING; o valor é
#   impresso no console pelo script.
# =============================================================================

suppressPackageStartupMessages({
  library(callr)
  library(chromote)
})

# Lendo os argumentos nomeados da linha de comando
args <- commandArgs(trailingOnly = TRUE)
pega_arg <- function(nome, padrao) {
  encontrado <- grep(paste0("^--", nome, "="), args, value = TRUE)
  if (length(encontrado) == 0) return(padrao)
  sub(paste0("^--", nome, "="), "", encontrado[1])
}
tem_flag <- function(nome) any(args == paste0("--", nome))

porta   <- as.integer(pega_arg("port", "4848"))
outdir  <- pega_arg("outdir", file.path(getwd(), "dev", "smoke"))
seletor <- pega_arg("wait-for", ".navbar-vidas")
shot    <- pega_arg("shot", "smoke.png")
js_eval <- pega_arg("eval", "")
largura <- as.integer(pega_arg("width", "1600"))
altura  <- as.integer(pega_arg("height", "900"))
rolagem <- as.numeric(pega_arg("scroll", "0"))
mobile  <- tem_flag("mobile")

# Lendo o JavaScript de um arquivo quando o argumento for um caminho existente
arquivo_js <- pega_arg("eval-file", "")
if (nzchar(arquivo_js) && file.exists(arquivo_js)) {
  js_eval <- paste(readLines(arquivo_js, warn = FALSE), collapse = "\n")
}

# Validando o diretório do pacote
if (!file.exists("DESCRIPTION")) {
  stop("Execute este script na raiz do pacote (onde está o DESCRIPTION).")
}
pacote <- normalizePath(getwd())
dir.create(outdir, showWarnings = FALSE, recursive = TRUE)
log_app <- file.path(outdir, "app.log")

# Subindo o app em segundo plano; o print() é o que efetivamente inicia o servidor
processo <- callr::r_bg(
  function(pacote, porta) {
    setwd(pacote)
    pkgload::load_all(pacote, quiet = TRUE)
    print(painel_vidas::run_app(
      options = list(port = porta, host = "127.0.0.1", launch.browser = FALSE)
    ))
  },
  args = list(pacote = pacote, porta = porta),
  stdout = log_app,
  stderr = log_app
)
on.exit(processo$kill(), add = TRUE)

# Esperando o servidor aceitar conexões na porta escolhida
url_app <- paste0("http://127.0.0.1:", porta, "/")
pronto <- FALSE
for (tentativa in seq_len(90)) {
  if (!processo$is_alive()) break
  pronto <- tryCatch({
    conexao <- socketConnection("127.0.0.1", porta, open = "ab", timeout = 1)
    close(conexao)
    TRUE
  }, error = function(e) FALSE)
  if (pronto) break
  Sys.sleep(0.5)
}
if (!pronto) {
  cat("ERRO: o app não ficou disponível.\n")
  if (file.exists(log_app)) cat(readLines(log_app), sep = "\n")
  quit(status = 1)
}

# Abrindo a sessão do Chrome com o tamanho de tela pedido
sessao <- chromote::ChromoteSession$new(width = largura, height = altura)
on.exit(sessao$close(), add = TRUE)

# Registrando os erros de JavaScript antes de carregar a página
sessao$Page$addScriptToEvaluateOnNewDocument(
  source = paste0(
    "window.__erros = [];",
    "window.addEventListener('error', function (e) {",
    "  window.__erros.push('erro: ' + String(e.message) + ' @ ' + e.filename + ':' + e.lineno);",
    "});",
    "window.addEventListener('unhandledrejection', function (e) {",
    "  window.__erros.push('promise: ' + String(e.reason));",
    "});",
    "['error', 'warn'].forEach(function (nivel) {",
    "  var original = console[nivel];",
    "  console[nivel] = function () {",
    "    window.__erros.push(nivel + ': ' + Array.prototype.join.call(arguments, ' '));",
    "    original.apply(console, arguments);",
    "  };",
    "});"
  )
)

# Ativando emulação de celular quando o teste for mobile
if (mobile) {
  sessao$Emulation$setDeviceMetricsOverride(
    width = largura, height = altura, deviceScaleFactor = 2, mobile = TRUE
  )
  sessao$Emulation$setTouchEmulationEnabled(enabled = TRUE)
} else if (as.numeric(pega_arg("dpr", "0")) > 0) {
  # Emulando uma escala de tela específica (útil para checar nitidez)
  sessao$Emulation$setDeviceMetricsOverride(
    width = largura,
    height = altura,
    deviceScaleFactor = as.numeric(pega_arg("dpr", "0")),
    mobile = FALSE
  )
}

# Emulando a preferência de movimento para testar animações de verdade
# O Chrome headless assume "reduce" por padrão, o que desliga as transições
if (tem_flag("motion")) {
  sessao$Emulation$setEmulatedMedia(
    features = list(list(name = "prefers-reduced-motion", value = "no-preference"))
  )
} else if (tem_flag("reduce")) {
  sessao$Emulation$setEmulatedMedia(
    features = list(list(name = "prefers-reduced-motion", value = "reduce"))
  )
}

# Navegando até o app e aguardando o seletor combinado
sessao$Page$navigate(url_app)
seletor_json <- jsonlite::toJSON(seletor, auto_unbox = TRUE)
apareceu <- FALSE
for (tentativa in seq_len(120)) {
  resultado <- tryCatch(
    sessao$Runtime$evaluate(
      paste0("document.querySelector(", seletor_json, ") !== null"),
      returnByValue = TRUE
    ),
    error = function(e) NULL
  )
  if (isTRUE(resultado$result$value)) {
    apareceu <- TRUE
    break
  }
  Sys.sleep(0.5)
}
if (!apareceu) {
  cat("AVISO: seletor não encontrado:", seletor, "\n")
}

# Aguardando as renderizações tardias (mapa, gráficos e tabelas) concluírem
espera <- as.numeric(pega_arg("espera", "120"))
concluido <- FALSE
for (tentativa in seq_len(max(1, espera))) {
  estado <- tryCatch(
    sessao$Runtime$evaluate(
      paste0(
        "(function () {",
        "  var recalc = document.querySelectorAll('.recalculating').length;",
        "  var mapa = document.querySelectorAll('.leaflet-container').length;",
        "  var erro = document.querySelectorAll('.shiny-output-error').length;",
        "  return recalc + '|' + mapa + '|' + erro;",
        "})()"
      ),
      returnByValue = TRUE
    )$result$value,
    error = function(e) NULL
  )
  if (!is.null(estado) && identical(estado, "0|1|0")) {
    concluido <- TRUE
    break
  }
  Sys.sleep(1)
}
if (!concluido) {
  cat("AVISO: renderizações não concluíram no tempo esperado. Estado:", estado, "\n")
}

# Rolando a página quando pedido, útil para capturar seções específicas
if (rolagem > 0) {
  sessao$Runtime$evaluate(paste0("window.scrollTo(0, ", rolagem, ")"))
  Sys.sleep(1.5)
}

# Avaliando JavaScript antes do screenshot para preparar um estado específico
js_pre <- pega_arg("pre-eval", "")
arquivo_pre <- pega_arg("pre-eval-file", "")
if (nzchar(arquivo_pre) && file.exists(arquivo_pre)) {
  js_pre <- paste(readLines(arquivo_pre, warn = FALSE), collapse = "\n")
}
if (nzchar(js_pre)) {
  resultado_pre <- sessao$Runtime$evaluate(
    js_pre,
    returnByValue = TRUE,
    awaitPromise = TRUE
  )
  if (is.null(resultado_pre$result$value) && !is.null(resultado_pre$exceptionDetails)) {
    cat("ERRO NA PRE-AVALIACAO:", resultado_pre$exceptionDetails$exception$description, "\n")
  } else {
    cat("PRE-AVALIACAO:", resultado_pre$result$value, "\n")
  }
  Sys.sleep(0.6)
}

# Movendo o mouse de verdade para testar hovers quando as coordenadas forem dadas
mouse <- pega_arg("mouse", "")
if (nzchar(mouse)) {
  xy <- as.numeric(strsplit(mouse, ",")[[1]])
  sessao$Page$bringToFront()
  # Fazendo um pequeno deslocamento para o navegador gerar o evento de movimento
  sessao$Input$dispatchMouseEvent(type = "mouseMoved", x = xy[1] - 3, y = xy[2] - 3)
  Sys.sleep(0.2)
  sessao$Input$dispatchMouseEvent(type = "mouseMoved", x = xy[1], y = xy[2])
  Sys.sleep(1.5)
}

# Clicando de verdade em um ponto da tela quando as coordenadas forem dadas
click <- pega_arg("click", "")
if (nzchar(click)) {
  xy <- as.numeric(strsplit(click, ",")[[1]])
  sessao$Page$bringToFront()
  sessao$Input$dispatchMouseEvent(type = "mouseMoved", x = xy[1] - 3, y = xy[2] - 3)
  sessao$Input$dispatchMouseEvent(type = "mouseMoved", x = xy[1], y = xy[2])
  sessao$Input$dispatchMouseEvent(
    type = "mousePressed", x = xy[1], y = xy[2],
    button = "left", clickCount = 1
  )
  Sys.sleep(0.15)
  sessao$Input$dispatchMouseEvent(
    type = "mouseReleased", x = xy[1], y = xy[2],
    button = "left", clickCount = 1
  )
  Sys.sleep(1.5)
}

# Tocando de verdade na tela quando as coordenadas forem dadas
tocar <- function(coordenadas) {
  xy <- as.numeric(strsplit(coordenadas, ",")[[1]])
  ponto <- list(list(x = xy[1], y = xy[2]))
  sessao$Page$bringToFront()
  sessao$Input$dispatchTouchEvent(type = "touchStart", touchPoints = ponto)
  Sys.sleep(0.1)
  # O fim do toque leva o ponto liberado para o navegador gerar o clique
  sessao$Input$dispatchTouchEvent(type = "touchEnd", touchPoints = ponto)
  Sys.sleep(1.5)
}

# Dando o primeiro toque, útil para testar os comportamentos de toque no mobile
tap <- pega_arg("tap", "")
if (nzchar(tap)) tocar(tap)

# Dando um segundo toque, útil para testar alternâncias (ex.: tooltip abrir e fechar)
tap2 <- pega_arg("tap2", "")
if (nzchar(tap2)) tocar(tap2)

# Salvando o screenshot da página inteira ou apenas da janela visível
caminho_shot <- file.path(outdir, shot)
if (tem_flag("full")) {
  # Desativando temporariamente elementos fixos para não repetir na captura
  sessao$Runtime$evaluate(
    "(function () {
       var estilo = document.createElement('style');
       estilo.id = 'ajuste-captura';
       estilo.textContent = '.navbar-vidas { position: static !important; }';
       document.head.appendChild(estilo);
     })()"
  )
  Sys.sleep(0.4)

  # Medindo a altura total e a largura da página para a captura completa
  dimensoes <- sessao$Runtime$evaluate(
    "JSON.stringify({ w: document.documentElement.clientWidth, h: document.body.scrollHeight })",
    returnByValue = TRUE
  )$result$value
  medidas <- jsonlite::fromJSON(dimensoes)
  dados_imagem <- sessao$Page$captureScreenshot(
    captureBeyondViewport = TRUE,
    clip = list(x = 0, y = 0, width = medidas$w, height = medidas$h, scale = 1)
  )$data
  writeBin(jsonlite::base64_dec(dados_imagem), caminho_shot)
  cat("SCREENSHOT COMPLETO:", caminho_shot, "| altura:", medidas$h, "px\n")
  sessao$Runtime$evaluate(
    "(function () { var e = document.getElementById('ajuste-captura'); if (e) e.remove(); })()"
  )
} else {
  # Capturando apenas a área visível, o que funciona em qualquer rolagem
  Sys.sleep(0.5)
  dados_imagem <- sessao$Page$captureScreenshot()$data
  writeBin(jsonlite::base64_dec(dados_imagem), caminho_shot)
  cat("SCREENSHOT:", caminho_shot, "\n")
}

# Reportando os erros de JavaScript capturados durante o carregamento
erros_js <- sessao$Runtime$evaluate(
  "JSON.stringify(window.__erros || [])",
  returnByValue = TRUE
)$result$value
if (!identical(erros_js, "[]")) {
  cat("ERROS JS:", erros_js, "\n")
}

# Avaliando o JavaScript opcional e imprimindo o valor retornado
if (nzchar(js_eval)) {
  # Avaliando também promises, o que permite testar interações com espera
  resultado <- sessao$Runtime$evaluate(
    js_eval,
    returnByValue = TRUE,
    awaitPromise = TRUE
  )
  if (is.null(resultado$result$value) && !is.null(resultado$exceptionDetails)) {
    cat("ERRO NA AVALIACAO:", resultado$exceptionDetails$exception$description, "\n")
  } else {
    cat("RESULTADO:", resultado$result$value, "\n")
  }
}

# Reportando erros registrados no log do servidor
if (file.exists(log_app)) {
  linhas_log <- readLines(log_app, warn = FALSE)
  erros_log <- grep("Error|Erro|Warning", linhas_log, value = TRUE)
  if (length(erros_log) > 0) {
    cat("ERROS NO SERVIDOR:\n")
    cat(tail(erros_log, 20), sep = "\n")
    cat("\n")
  }
}

# Encerrando o processo do app e a sessão do Chrome
processo$kill()
cat("OK\n")
