/* =============================================================================
   FUNÇÕES JAVASCRIPT DO PAINEL VIDAS
   Reúne os handlers do mapa (desenho, atualização de cores e tooltips e ajuste
   do canvas à resolução da tela), a abertura animada das duas colunas de
   comparação e a marcação da seção visível na barra de navegação.
   ============================================================================= */

/* Abrindo e fechando as duas colunas quando a comparação é ligada ou desligada */
Shiny.addCustomMessageHandler("ibisma_comparacao", function (mensagem) {
  /* Aplicando a classe que o CSS usa para animar os palcos lado a lado */
  var el = document.getElementById(mensagem.palcos);
  if (el) el.classList.toggle("dupla--comparando", !!mensagem.ativa);
});

/* =============================================================================
   DESENHO E ATUALIZAÇÃO DO MAPA
   O desenho dos municípios chega pronto do servidor, como texto JSON gerado no
   ETL; o binding do próprio leaflet cria as camadas e as cores são atualizadas
   a cada troca de ano ou de medida. O hover usa um único tooltip do mapa, que
   lê os dados do município sob o cursor, em vez de um tooltip por município.
   ============================================================================= */
(function () {
  /* Definindo o estilo das camadas de município e do realce de hover */
  var ESTILO_MUNICIPIO = {
    color: "#FFFFFF",
    weight: 0.25,
    opacity: 0.65,
    fillOpacity: 0.95,
    smoothFactor: 0
  };
  var REALCE_MUNICIPIO = {
    weight: 1.2,
    color: "#0A1E3C",
    fillOpacity: 0.95,
    bringToFront: true
  };
  /* Definindo as opções do tooltip único, posicionado a cada evento do cursor */
  var OPCOES_TOOLTIP = {
    direction: "auto",
    opacity: 1,
    className: "tooltip-ibisma"
  };

  /* Guardando a ordem das camadas e os dados de cada mapa do painel */
  var camadasPorMapa = {};
  var dadosPorMapa = {};

  /* =============================================================================
     CANVAS NA RESOLUÇÃO DA TELA
     O Leaflet multiplica o canvas por um fator fixo de 2 quando detecta tela de
     alta densidade; em telas com DPR maior (celulares 3x) o desenho é ampliado e
     fica borrado. O ajuste abaixo usa a densidade real da tela arredondada para
     um fator inteiro: em telas com DPR fracionário (125%/150% do Windows e zoom
     do navegador), o canvas desenhado na própria fração é reamostrado pelo
     navegador e fica macio, enquanto um fator inteiro o mantém nítido. O Leaflet
     refaz o canvas a cada resize, o que cobre o zoom do navegador e a troca de
     monitor.
     Em escalas fracionárias, o redesenho parcial do hover também precisa alinhar
     o recorte aos pixels da tela, senão uma linha clara fica na borda do
     retângulo recortado.
     ============================================================================= */
  (function () {
    if (!window.L || !L.Canvas || !L.Renderer) return;

    /* Redefinindo a atualização do canvas com a densidade real da tela */
    L.Canvas.include({
      _update: function () {
        if (this._map._animatingZoom && this._bounds) return;
        this._drawnLayers = {};
        L.Renderer.prototype._update.call(this);
        var caixa = this._bounds;
        var tamanho = caixa.getSize();
        /* Arredondando a densidade para um fator inteiro de pixels por pixel de CSS */
        var fator = Math.max(1, Math.ceil(window.devicePixelRatio || 1));
        var largura = fator * tamanho.x;
        var altura = fator * tamanho.y;
        L.DomUtil.setPosition(this._container, caixa.min);
        this._container.width = largura;
        this._container.height = altura;
        this._container.style.width = tamanho.x + "px";
        this._container.style.height = tamanho.y + "px";
        this._ctx.scale(fator, fator);
        this._ctx.translate(-caixa.min.x, -caixa.min.y);
        this.fire("update");
      },

      /* Alinhando o recorte do redesenho parcial aos pixels da tela */
      _redraw: function () {
        this._redrawRequest = null;
        if (this._redrawBounds) {
          this._redrawBounds.min._floor();
          this._redrawBounds.max._ceil();
          /* Levando o recorte para pixels da tela e arredondando para fora */
          var matriz = this._ctx.getTransform();
          var min = this._redrawBounds.min;
          var max = this._redrawBounds.max;
          var x0 = Math.floor(matriz.a * min.x + matriz.e);
          var y0 = Math.floor(matriz.d * min.y + matriz.f);
          var x1 = Math.ceil(matriz.a * max.x + matriz.e);
          var y1 = Math.ceil(matriz.d * max.y + matriz.f);
          /* Voltando o recorte já alinhado para as coordenadas do desenho */
          min.x = (x0 - matriz.e) / matriz.a;
          min.y = (y0 - matriz.f) / matriz.d;
          max.x = (x1 - matriz.e) / matriz.a;
          max.y = (y1 - matriz.f) / matriz.d;
        }
        this._clear();
        this._draw();
        this._redrawBounds = null;
      },

      /* Limpando o canvas inteiro em pixels da tela quando não há recorte */
      _clear: function () {
        var recorte = this._redrawBounds;
        if (recorte) {
          var tamanho = recorte.getSize();
          this._ctx.clearRect(recorte.min.x, recorte.min.y, tamanho.x, tamanho.y);
          return;
        }
        /* Com escala menor que 1 (zoom out do navegador), a limpeza nas
           coordenadas do desenho não alcançaria a borda direita e a de baixo */
        var ctx = this._ctx;
        ctx.save();
        ctx.setTransform(1, 0, 0, 1, 0, 0);
        ctx.clearRect(0, 0, this._container.width, this._container.height);
        ctx.restore();
      }
    });
  })();

  /* Montando o HTML do tooltip de um município a partir da mensagem compacta */
  function montarTooltip(mensagem, i) {
    /* Categoria ausente vira a entrada cinza de "Sem dados" */
    var categoria = mensagem.categorias[i] || 0;
    var cor = categoria ? mensagem.paleta[categoria - 1] : mensagem.cor_sem_dados;
    var corTexto = categoria
      ? mensagem.cores_texto[categoria - 1]
      : mensagem.cor_texto_sem_dados;
    var rotulo = categoria ? mensagem.rotulos[categoria - 1] : "Sem dados";
    return '<div class="tooltip-mapa">' +
      '<div class="tooltip-mapa__titulo">' + mensagem.municipios[i] +
        ' <span>(' + mensagem.ufs[i] + ')</span></div>' +
      '<div class="tooltip-mapa__linha">' +
        '<span class="tooltip-mapa__rotulo">' + mensagem.medida + '</span>' +
        '<span class="tooltip-mapa__valor">' + mensagem.valores[i] + '</span>' +
      '</div>' +
      '<div class="tooltip-mapa__categoria" ' +
        'style="--cor-cat:' + cor + ';color:' + corTexto + '">' +
        rotulo + '</div>' +
      '</div>';
  }

  /* Repintando as camadas e guardando os dados que o tooltip único consulta */
  function aplicarDados(mapa, mensagem, layers) {
    var camadas = mapa.layerManager._byLayerId;
    if (!camadas) return;
    /* Guardando a mensagem do mapa para o hover montar o tooltip do município */
    dadosPorMapa[mensagem.id] = mensagem;
    /* As camadas dos municípios guardam o ID após o caractere de quebra de linha */
    for (var i = 0; i < layers.length; i++) {
      var camada = camadas["shape\n" + layers[i]];
      if (!camada || typeof camada.setStyle !== "function") continue;
      var categoria = mensagem.categorias[i] || 0;
      var cor = categoria ? mensagem.paleta[categoria - 1] : mensagem.cor_sem_dados;
      /* Repintando apenas o preenchimento, já que a divisa branca é fixa */
      camada.setStyle({ fillColor: cor, fillOpacity: 0.95 });
      /* Anotando o índice do município para o hover achar os dados sem busca */
      camada._ibisma_indice = i;
      /* Fazendo os eventos da camada subirem ao mapa, como no FeatureGroup */
      camada.addEventParent(mapa);
    }
  }

  /* Distinguindo dispositivos com mouse e hover dos dispositivos de toque */
  var PODE_HOVER = !!(window.matchMedia &&
    window.matchMedia("(hover: hover) and (pointer: fine)").matches);

  /* Criando um único tooltip por mapa, atualizado pelo município sob o cursor */
  function prepararTooltip(mapa, id) {
    /* Criando o tooltip apenas na primeira vez em que o mapa é desenhado */
    if (mapa._ibismaTooltip) return;
    var tooltip = L.tooltip(OPCOES_TOOLTIP);
    var mostrando = false;

    /* Mostrando o tooltip de um município na posição indicada */
    function mostrar(indice, latlng) {
      var dados = dadosPorMapa[id];
      if (typeof indice !== "number" || !dados) return;
      /* No toque o lado do tooltip segue a metade visível da tela, porque o
         mapa pode continuar abaixo da dobra e cortar o balão */
      if (!PODE_HOVER) {
        var ponto = mapa.latLngToContainerPoint(latlng);
        var topoTela = mapa.getContainer().getBoundingClientRect().top + ponto.y;
        tooltip.options.direction =
          topoTela > window.innerHeight / 2 ? "top" : "bottom";
      }
      tooltip.setContent(montarTooltip(dados, indice));
      tooltip.setLatLng(latlng);
      if (!mapa.hasLayer(tooltip)) mapa.addLayer(tooltip);
      mostrando = true;
    }

    /* Escondendo o tooltip e interrompendo o acompanhamento do cursor */
    function esconder() {
      mostrando = false;
      if (mapa.hasLayer(tooltip)) mapa.removeLayer(tooltip);
    }

    /* Mostrando o tooltip do município que o cursor acabou de encontrar */
    mapa.on("mouseover", function (e) {
      if (!PODE_HOVER) return;
      mostrar(e.layer && e.layer._ibisma_indice, e.latlng);
    });

    /* Acompanhando o cursor enquanto o tooltip estiver à mostra */
    mapa.on("mousemove", function (e) {
      if (PODE_HOVER && mostrando) tooltip.setLatLng(e.latlng);
    });

    /* Escondendo o tooltip ao sair do município com o mouse */
    mapa.on("mouseout", function (e) {
      if (!PODE_HOVER) return;
      if (!e.layer || typeof e.layer._ibisma_indice !== "number") return;
      esconder();
    });

    /* Anotando quando o clique do mapa veio de um município desenhado */
    var cliqueEmMunicipio = false;

    /* Mostrando o tooltip do município tocado, que fica fixo no ponto do toque */
    mapa.on("click", function (e) {
      /* O Leaflet fecha o tooltip no preclick dos dispositivos de toque, então
         o clique reexibe o tooltip tanto no toque quanto no mouse */
      if (e.propagatedFrom) {
        cliqueEmMunicipio = true;
        mostrar(e.layer && e.layer._ibisma_indice, e.latlng);
        return;
      }
      /* Clicando fora de um município, o tooltip fixado se fecha */
      if (!cliqueEmMunicipio) esconder();
      cliqueEmMunicipio = false;
    });

    /* Fechando o tooltip fixado quando o mapa se move de posição no toque */
    mapa.on("movestart", function () {
      if (!PODE_HOVER) esconder();
    });

    /* Guardando a instância para não criar um segundo tooltip no mesmo mapa */
    mapa._ibismaTooltip = tooltip;
  }

  /* Criando as camadas dos municípios com o binding do leaflet e os dados iniciais */
  Shiny.addCustomMessageHandler("ibisma_mapa_desenha", function (mensagem) {
    var widget = window.HTMLWidgets && HTMLWidgets.find("#" + mensagem.id);
    if (!widget || typeof widget.getMap !== "function") return;
    var mapa = widget.getMap();
    if (!mapa || !mapa.layerManager) return;

    /* O texto JSON vem pronto do ETL e é lido de uma vez pelo navegador */
    var poligonos = JSON.parse(mensagem.pgons);
    var opcoes = Object.assign({}, ESTILO_MUNICIPIO, {
      fillColor: mensagem.categorias.map(function (categoria) {
        return categoria ? mensagem.paleta[categoria - 1] : mensagem.cor_sem_dados;
      })
    });
    window.LeafletWidget.methods.addPolygons.call(
      mapa, poligonos, mensagem.layers, null, opcoes,
      null, null, null, null, REALCE_MUNICIPIO
    );

    /* Guardando a ordem das camadas e preenchendo as cores dos municípios */
    camadasPorMapa[mensagem.id] = mensagem.layers;
    aplicarDados(mapa, mensagem, mensagem.layers);

    /* Ligando o tooltip único do mapa, que lê os dados sob o cursor */
    prepararTooltip(mapa, mensagem.id);
  });

  /* Atualizando as cores dos municípios já desenhados no mapa */
  Shiny.addCustomMessageHandler("ibisma_mapa_atualiza", function (mensagem) {
    var widget = window.HTMLWidgets && HTMLWidgets.find("#" + mensagem.id);
    if (!widget || typeof widget.getMap !== "function") return;
    var mapa = widget.getMap();
    if (!mapa || !mapa.layerManager) return;
    var layers = camadasPorMapa[mensagem.id];
    if (!layers) return;
    aplicarDados(mapa, mensagem, layers);
  });
})();

/* =============================================================================
   ESQUELETOS DE CARREGAMENTO
   Mantém os esqueletos apenas no carregamento inicial da página; depois da
   primeira fila de recálculos concluída, eles deixam de aparecer.
   ============================================================================= */
(function () {
  /* Marcando a página como carregada quando o servidor fica ocioso */
  function concluir() {
    /* Esperando eventuais recálculos atrasados do próprio carregamento */
    if (document.querySelectorAll(".recalculating").length) {
      setTimeout(concluir, 250);
      return;
    }
    document.documentElement.classList.add("pagina-carregada");
  }

  /* O primeiro idle acontece quando o carregamento inicial termina */
  if (window.jQuery) {
    jQuery(document).one("shiny:idle", function () {
      setTimeout(concluir, 700);
    });
  }
})();

/* Inicializando as tooltips das pétalas e dos campos territoriais cortados */
(function () {
  /* Reunindo pétalas e campos que revelam o próprio texto no hover */
  var SELETOR_PETALAS = '.grupo-petala[data-bs-toggle="tooltip"]';
  var SELETOR_METRICAS = '.metrica-tooltip[data-tooltip-texto]';

  /* Executando a função imediatamente quando a página já estiver pronta */
  function quandoPronto(fn) {
    if (document.readyState === "loading") {
      document.addEventListener("DOMContentLoaded", fn);
    } else {
      fn();
    }
  }

  /* Ativando o tooltip do Bootstrap no elemento quando ainda não houver um */
  function criarTooltip(el, rico) {
    if (!window.bootstrap || !bootstrap.Tooltip) return;
    if (bootstrap.Tooltip.getInstance(el)) return;
    var opcoes = {
      placement: "top",
      customClass: "tooltip-ibisma",
      container: "body",
      delay: { show: 80, hide: 40 }
    };
    if (rico) {
      /* As pétalas usam HTML com cores gerado pelo servidor */
      opcoes.html = true;
      /* A sanitização removeria os estilos em linha com as cores da dimensão */
      opcoes.sanitize = false;
    } else {
      /* Os campos territoriais usam o texto completo guardado em data */
      opcoes.title = el.getAttribute("data-tooltip-texto");
    }
    new bootstrap.Tooltip(el, opcoes);
  }

  /* Ativando as tooltips das pétalas, que nunca são cortadas */
  function inicializarPetalas() {
    document.querySelectorAll(SELETOR_PETALAS).forEach(function (el) {
      if (el.dataset.tooltipIniciado) return;
      el.dataset.tooltipIniciado = "sim";
      criarTooltip(el, true);
    });
  }

  /* Ativando a tooltip dos campos territoriais somente quando há corte */
  function atualizarMetricas() {
    if (!window.bootstrap || !bootstrap.Tooltip) return;
    document.querySelectorAll(SELETOR_METRICAS).forEach(function (el) {
      var cortado = el.scrollWidth > el.clientWidth;
      var instancia = bootstrap.Tooltip.getInstance(el);
      if (cortado && !instancia) {
        el.setAttribute("tabindex", "0");
        criarTooltip(el, false);
      } else if (!cortado && instancia) {
        instancia.dispose();
        el.removeAttribute("tabindex");
      }
    });
  }

  /* Reavaliando os cortes depois de a janela mudar de tamanho */
  var reagendado = false;
  function agendarAtualizacao() {
    if (reagendado) return;
    reagendado = true;
    window.requestAnimationFrame(function () {
      reagendado = false;
      atualizarMetricas();
    });
  }

  quandoPronto(function () {
    inicializarPetalas();
    atualizarMetricas();
    window.addEventListener("resize", agendarAtualizacao);

    /* Reavaliando depois que a fonte institucional terminar de carregar */
    if (document.fonts && document.fonts.ready) {
      document.fonts.ready.then(function () {
        atualizarMetricas();
      });
    }

    /* Reinicializando sempre que o Shiny inserir novos elementos na página */
    var observador = new MutationObserver(function (mutacoes) {
      for (var i = 0; i < mutacoes.length; i++) {
        var adicionados = mutacoes[i].addedNodes;
        for (var j = 0; j < adicionados.length; j++) {
          var no = adicionados[j];
          if (no.nodeType !== 1) continue;
          var temPetala =
            (no.matches && no.matches(SELETOR_PETALAS)) ||
            (no.querySelector && no.querySelector(SELETOR_PETALAS));
          var temMetrica =
            (no.matches && no.matches(SELETOR_METRICAS)) ||
            (no.querySelector && no.querySelector(SELETOR_METRICAS));
          if (temPetala) inicializarPetalas();
          if (temMetrica) atualizarMetricas();
          if (temPetala || temMetrica) return;
        }
      }
    });
    observador.observe(document.body, { childList: true, subtree: true });
  });
})();

/* Posicionando o dropdown do slim select dentro da janela e afastado do input */
(function () {
  /* Definindo a margem de segurança em relação às bordas da janela */
  var MARGEM = 10;
  /* Definindo o respiro entre o input e o cartão do dropdown */
  var ESPACO = 6;

  /* Verificando se o dropdown está aberto em uma das direções */
  function estaAberto(el) {
    return (
      el.classList.contains("ss-open-below") ||
      el.classList.contains("ss-open-above")
    );
  }

  /* Ajustando o dropdown aberto sem sobrescrever a posição calculada pelo plugin */
  function ajustarDropdown(el) {
    /* Usando a propriedade translate para deslocar sem brigar com o plugin */
    var largura = el.offsetWidth;
    /* O left inline é gravado pelo plugin em coordenadas do documento */
    var baseX = parseFloat(el.style.left || "0") - window.scrollX;
    /* Reservando a margem dos dois lados antes de limitar a posição */
    var limite = window.innerWidth - MARGEM - largura;
    /* Centralizando o dropdown quando ele for maior que a janela disponível */
    var destinoX =
      largura > window.innerWidth - 2 * MARGEM
        ? MARGEM - baseX
        : Math.min(Math.max(baseX, MARGEM), Math.max(limite, MARGEM));
    /* Invertendo o respiro quando o dropdown abre acima do input */
    var deslocamentoY = el.classList.contains("ss-open-above")
      ? -ESPACO
      : ESPACO;
    /* Evitando reescrever o valor quando o ajuste já está aplicado */
    var valor = Math.round(destinoX - baseX) + "px " + deslocamentoY + "px";
    if (el.style.translate !== valor) el.style.translate = valor;
  }

  /* Reposicionando todos os dropdowns abertos, por exemplo após um resize */
  function ajustarAbertos() {
    document.querySelectorAll(".ss-content").forEach(function (el) {
      if (estaAberto(el)) ajustarDropdown(el);
    });
  }

  /* Reagendando um ajuste por quadro para não recalcular a cada mutação */
  var agendado = false;
  function agendarAjuste() {
    if (agendado) return;
    agendado = true;
    window.requestAnimationFrame(function () {
      agendado = false;
      ajustarAbertos();
    });
  }

  document.addEventListener("DOMContentLoaded", function () {
    /* Observando abertura, virada de direção e reposicionamento do plugin */
    var observador = new MutationObserver(function (mutacoes) {
      for (var i = 0; i < mutacoes.length; i++) {
        var el = mutacoes[i].target;
        if (!(el instanceof Element)) continue;
        if (!el.classList.contains("ss-content")) continue;
        if (estaAberto(el)) agendarAjuste();
      }
    });
    observador.observe(document.body, {
      attributes: true,
      attributeFilter: ["class", "style"],
      subtree: true
    });

    /* Reavaliando quando a busca filtra as opções e muda a largura do cartão */
    document.addEventListener("input", function (evento) {
      var alvo = evento.target;
      if (!alvo || alvo.type !== "search") return;
      var el = alvo.closest(".ss-content");
      if (el) setTimeout(function () { ajustarDropdown(el); }, 220);
    });

    /* Reavaliando os dropdowns abertos quando a janela muda de tamanho */
    window.addEventListener("resize", agendarAjuste);
  });
})();

/* =============================================================================
   BUSCA DOS SELETORES
   Ignorando maiúsculas, acentos e sinais nas buscas dos slimSelect e realçando
   o trecho encontrado, no mesmo padrão usado pelas demais buscas do painel.
   ============================================================================= */
(function () {
  /* Normalizando o texto como na busca do ranking */
  function normalizar(texto) {
    return String(texto)
      .normalize("NFD")
      .replace(/[\u0300-\u036f]/g, "")
      .toLowerCase()
      .replace(/[^a-z0-9]+/g, "");
  }

  /* Normalizando o texto e guardando de onde cada letra veio no original */
  function normalizarComMapa(texto) {
    var normalizado = "";
    var mapa = [];
    for (var i = 0; i < texto.length; i++) {
      var letra = texto[i]
        .normalize("NFD")
        .replace(/[\u0300-\u036f]/g, "")
        .toLowerCase();
      normalizado += letra;
      for (var j = 0; j < letra.length; j++) mapa.push(i);
    }
    return { texto: normalizado, mapa: mapa };
  }

  /* Realçando no texto original o trecho que o filtro normalizado encontrou */
  function destacar(texto, busca, classe) {
    var alvo = normalizarComMapa(String(busca).trim());
    if (alvo.texto === "") return null;
    var fonte = normalizarComMapa(texto);
    var posicao = fonte.texto.indexOf(alvo.texto);
    if (posicao === -1) return null;
    /* Convertendo as posições normalizadas de volta para o texto original */
    var inicio = fonte.mapa[posicao];
    var fim = fonte.mapa[posicao + alvo.texto.length - 1] + 1;
    return (
      texto.slice(0, inicio) +
      '<mark class="' + classe + '">' + texto.slice(inicio, fim) + "</mark>" +
      texto.slice(fim)
    );
  }

  /* Trocando o filtro padrão do slimSelect pelo filtro normalizado */
  function ajustar(select) {
    if (select.dataset.buscaNormalizada === "sim") return;
    var instancia = select.slim;
    if (!instancia || !instancia.events) return;
    instancia.events.searchFilter = function (opcao, busca) {
      return normalizar(opcao.text).indexOf(normalizar(busca)) !== -1;
    };
    /* Substituindo o realce cru do plugin pelo realce sem acento do painel */
    var render = instancia.render;
    if (render && typeof render.highlightText === "function") {
      var realcarOriginal = render.highlightText.bind(render);
      render.highlightText = function (texto, busca, classe) {
        /* Preservando o realce do plugin quando a opção trouxer HTML */
        if (String(texto).indexOf("<") !== -1) {
          return realcarOriginal(texto, busca, classe);
        }
        var destacado = destacar(texto, busca, classe);
        return destacado === null ? texto : destacado;
      };
    }
    select.dataset.buscaNormalizada = "sim";
  }

  /* Percorrendo os seletores e contando quantos ainda não foram ajustados */
  function ajustarTodos() {
    document.querySelectorAll("select.slim-select").forEach(ajustar);
    return document.querySelectorAll(
      "select.slim-select:not([data-busca-normalizada])"
    ).length;
  }

  /* Repetindo algumas vezes até o Shiny criar todas as instâncias do plugin */
  var tentativas = 0;
  (function tentar() {
    var pendentes = ajustarTodos();
    if (pendentes > 0 && tentativas < 20) {
      tentativas += 1;
      setTimeout(tentar, 250);
    }
  })();

  /* Garantindo o ajuste quando a página terminar de carregar */
  window.addEventListener("load", ajustarTodos);
})();

/* =============================================================================
   BUSCA DO RANKING
   Avisando o servidor quando o campo de busca da tabela é esvaziado, para a
   tabela voltar à página do município em foco.
   ============================================================================= */
document.addEventListener("input", function (evento) {
  var alvo = evento.target;
  if (!alvo || !alvo.classList || !alvo.classList.contains("rt-search")) return;
  if (alvo.value !== "") return;
  /* O nome do input segue o namespace do módulo Onde? do painel */
  Shiny.setInputValue("onde-ranking_busca_limpa", Date.now(), {
    priority: "event"
  });
});

/* Posicionando as seções exatamente abaixo da navbar ao clicar nas âncoras */
(function () {
  var navbar = document.querySelector(".navbar-ibisma");
  if (!navbar) return;

  /* Gravando a altura real da navbar para o CSS compensar o scroll */
  function medirNavbar() {
    var altura = Math.round(navbar.getBoundingClientRect().height);
    document.documentElement.style.setProperty("--altura-navbar", altura + "px");
  }

  /* Respeitando quem prefere menos movimento na rolagem */
  function comportamento() {
    return window.matchMedia("(prefers-reduced-motion: reduce)").matches
      ? "auto"
      : "smooth";
  }

  /* Rolando até a seção descontando a altura viva da navbar */
  function rolarAte(secao) {
    var altura = navbar.getBoundingClientRect().height;
    var topo = secao.getBoundingClientRect().top + window.pageYOffset - altura;
    window.scrollTo({ top: Math.max(topo, 0), behavior: comportamento() });
  }

  /* Medindo agora e acompanhando qualquer mudança de tamanho da barra */
  medirNavbar();
  if (window.ResizeObserver) {
    new ResizeObserver(medirNavbar).observe(navbar);
  }
  window.addEventListener("resize", medirNavbar);

  /* Corrigindo a posição quando a página abre já com uma âncora na URL */
  window.addEventListener("load", function () {
    medirNavbar();
    var secao = location.hash && document.querySelector(location.hash);
    if (secao) {
      var altura = navbar.getBoundingClientRect().height;
      var topo = secao.getBoundingClientRect().top + window.pageYOffset - altura;
      window.scrollTo({ top: Math.max(topo, 0), behavior: "auto" });
    }
  });

  /* Interceptando os cliques para fechar o menu antes de calcular a posição */
  document.querySelectorAll('.navbar-ibisma a[href^="#"]').forEach(function (link) {
    link.addEventListener("click", function (evento) {
      var destino = link.getAttribute("href");
      var secao = destino && document.querySelector(destino);
      if (!secao) return;
      evento.preventDefault();
      var menu = document.getElementById("menu-ibisma");
      var menuAberto = menu && menu.classList.contains("show");
      var concluir = function () {
        medirNavbar();
        rolarAte(secao);
        if (window.history && history.pushState) {
          history.pushState(null, "", destino);
        }
      };
      if (menuAberto) {
        /* Aguardando a animação do menu para medir a altura já recolhida */
        bootstrap.Collapse.getOrCreateInstance(menu).hide();
        setTimeout(concluir, 380);
      } else {
        concluir();
      }
    });
  });
})();

/* Marcando na navbar a seção atualmente visível na página */
(function () {
  var links = [];
  var secoes = [];

  /* Reunindo os pares link/âncora existentes na página */
  function coletar() {
    links = Array.prototype.slice.call(
      document.querySelectorAll(".navbar-ibisma .nav-link")
    );
    secoes = [];
    links.forEach(function (link) {
      var destino = link.getAttribute("href");
      if (!destino || destino.charAt(0) !== "#") return;
      var secao = document.querySelector(destino);
      if (secao) secoes.push({ link: link, secao: secao });
    });
  }

  /* Descobrindo qual seção já entrou na área visível pelo alto da janela */
  function atualizar() {
    if (!secoes.length) return;
    var ativa = null;
    secoes.forEach(function (item) {
      var topo = item.secao.getBoundingClientRect().top;
      if (topo <= 200) ativa = item;
    });
    links.forEach(function (link) {
      link.classList.remove("active");
      link.removeAttribute("aria-current");
    });
    if (ativa) {
      ativa.link.classList.add("active");
      ativa.link.setAttribute("aria-current", "true");
    }
  }

  /* Agendando uma única atualização por quadro de animação */
  var agendado = false;
  function agendar() {
    if (agendado) return;
    agendado = true;
    window.requestAnimationFrame(function () {
      agendado = false;
      atualizar();
    });
  }

  document.addEventListener("DOMContentLoaded", function () {
    coletar();
    atualizar();
    window.addEventListener("scroll", agendar, { passive: true });
    window.addEventListener("resize", agendar);

    /* Fechando o menu móvel ao escolher uma seção */
    document.querySelectorAll("#menu-ibisma .nav-link").forEach(function (link) {
      link.addEventListener("click", function () {
        var menu = document.getElementById("menu-ibisma");
        if (menu && menu.classList.contains("show")) {
          var colapso = bootstrap.Collapse.getInstance(menu);
          if (colapso) colapso.hide();
        }
      });
    });
  });
})();
