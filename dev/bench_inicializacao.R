# Medindo o custo de inicialização do painel
# Executar na raiz do pacote: Rscript dev/bench_inicializacao.R
# Números de referência (antes das otimizações, sessão de 15/09/2026):
#   preparar_dados .............. 0,48 s por processo
#   tabela_ano (10 anos) ........ 0,57 s no total
#   juntar a malha .............. 0,39 s por sessão
#   readRDS da malha ............ 0,06 s por processo
#   series_municipio ............ 0,02 s por seleção
#   nome_uf ..................... 0,03 s por render
#   payload do mapa ............. 7,51 MB / 1,94 s de serialização
# Depois da otimização de 16/09/2026, a geometria sai do widget do leaflet e
# viaja como texto JSON pronto, gerado por data-raw/cria_rda.R.

suppressPackageStartupMessages(pkgload::load_all(quiet = TRUE))

medir <- function(nome, expressao) {
  tempo <- system.time(invisible(force(expressao)))
  cat(sprintf("%-42s %.3f s\n", nome, tempo[["elapsed"]]))
}

# Leitura do arquivo pequeno com cadastro, anos e séries
medir("dados_vidas() (arquivo pronto)", dados <- dados_vidas())

# Leitura da tabela do primeiro ano e de um ano ainda não visitado
medir("tabela_ano(2024) (primeira leitura)", tabela_ano(dados, 2024L))
medir("tabela_ano(2015) (ano novo)", tabela_ano(dados, 2015L))

# Município padrão e recortes usados nos controles e no perfil
medir("municipio_padrao()", municipio_padrao(dados))
medir("series_municipio() de um município", series_municipio(dados, 1302405L))
# Opções montadas dentro dos módulos (controles de município e de escopo)
medir("opções de municípios (mod_como)", {
  municipios <- dados$municipios[order(dados$municipios$municipio, dados$municipios$sigla_uf), ]
  stats::setNames(municipios$codmunres, paste0(municipios$municipio, " (", municipios$sigla_uf, ")"))
})
medir("opções de escopo do ranking (mod_onde)", {
  ufs_escopo <- unique(dados$municipios[, c("sigla_uf", "uf")])
  ufs_escopo <- ufs_escopo[order(ufs_escopo$uf), ]
  stats::setNames(
    c("nacional", ufs_escopo$sigla_uf),
    c("Brasil (nacional)", paste0(ufs_escopo$uf, " (", ufs_escopo$sigla_uf, ")"))
  )
})
medir("nome_uf(\"SP\")", nome_uf("SP"))

# Desenho pronto dos municípios e dados compactos do mapa
medir("carregar_desenho_municipios() (1a leitura)", desenho <- carregar_desenho_municipios())
medir("dados_mapa(2024, indice_final)", base_mapa <- dados_mapa(dados, 2024L, "indice_final"))
medir("mensagem_mapa(...)", mensagem <- mensagem_mapa("mapa", base_mapa, "indice_final"))

# Payload enviado na primeira carga do mapa (desenho + dados compactos)
mensagem$pgons <- desenho$pgons
mensagem$layers <- desenho$layers
tempo_json <- system.time(json <- jsonlite::toJSON(
  mensagem, auto_unbox = TRUE, force = TRUE, digits = 16
))
cat(sprintf(
  "%-42s %.3f s | %.2f MB\n",
  "serialização do mapa (mensagem)",
  tempo_json[["elapsed"]],
  nchar(json) / 1024^2
))
