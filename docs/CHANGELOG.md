# Registro de alterações

## v0.5 — Fase 5: sons, efeitos e menus (2026-11-09)
- 14 sons sintetizados por código (sem recursos externos): pneus, corrente, catraca livre, freio, vento,
  queda, encostão, poça, bipes, largada, checkpoint, fanfarra, derrota e trovões distantes.
- Sons posicionais para cada ciclista (você ouve os rivais se aproximando).
- Efeitos: poeira e folhas nas quedas, respingos nas poças, folhas de outono caindo, tremor de câmera,
  linhas de velocidade no turbo.
- Menu inicial, pausa no Esc (antes saía do jogo) e configurações (qualidade, sombras, tela cheia, volume).
- 105 testes automatizados.

## v0.4.1 — Correções após o teste da Fase 4 (2026-11-09)
- Energia justa e visível: pedalar gasta pouco e não recupera; só o pedal solto recupera.
  Seta "recuperando" no HUD e aviso na primeira vez que a energia fica baixa. Penalidade só abaixo de 25%.
- Rivais soltam o pedal visivelmente para recuperar, ficam "cansados" (pedalada pesada, corpo curvado)
  e mostram o estado sobre o nome.
- Pelotão equilibrado (rivais entre 3:13 e 3:19): Lucienne hesita menos e acelera mais nas retas;
  Mint varia o ritmo entre corridas; corrigidos sprint final e "zona morta" de energia da IA.
- Russ persegue o jogador: espera, fecha, empurra, devolve ultrapassagens e corta esquinas; provocações visíveis.
- Empurrões limitados (antes podiam acumular velocidade extra).
- 89 testes automatizados.

## v0.4 — Fase 4: adversários e regras (2026-11-09)
- Lucienne, Russ e Mint controlados por IA, com a mesma física do jogador e visual provisório próprio
  (cores, cabelo — maria-chiquinhas, espetado, black puff —, bicicleta, altura).
- Personalidades configuráveis em `resources/ai_*.tres`; ultrapassagens; Russ fecha e empurra.
- Contato entre ciclistas (empurrão / queda), grid de largada 2×2, nomes sobre os rivais.
- Classificação ao vivo, rivais no minimapa, quadro final com posições e tempos.
- Recuperação automática da IA (sem bloqueios permanentes); ciclistas que chegam viram "fantasmas".
- Energia recalibrada: pedalada normal sustentável (recupera abaixo de 60%); turbo é o recurso a administrar.
- 84 testes automatizados (corrida completa com 4 ciclistas: Mint 3:20, Russ 3:37, Lucienne 3:38).

## v0.3 — Fase 3: bairro de Red City (2026-11-09)
- Bairro residencial do interior americano: grade de ruas, ~280 casas baixas (varanda, garagem, chaminé,
  janelas acesas), gramados, calçadas, entradas de carro, árvores de outono, arbustos, cercas, caixas de correio,
  picapes estacionadas, postes com fios, 2 praças, cinturão de árvores, caixa d'água e placa de Red City.
- Circuito de 1.470 m com 12 checkpoints + largada/chegada, contagem regressiva, cronômetro, recorde,
  aviso de contramão, seta para o próximo checkpoint e minimapa giratório.
- Barreiras fecham as ruas fora da rota; poças de baixa aderência em pontos do circuito.
- Malhas agrupadas para desempenho (~90 malhas para todo o cenário).
- Pista de testes da física preservada em `scenes/test_track.tscn`.
- 70 testes automatizados (incluindo uma volta completa com piloto automático: 4:03 sem turbo).

## v0.1 — Protótipo Fase 1–2 (2026-11-08)
- Projeto Godot 4 (renderizador Mobile), estrutura de pastas e documentação.
- Controlador da bicicleta com física híbrida: aceleração progressiva, inércia, resistência do ar e de
  rolamento, freio progressivo, rampas, curvas com equilíbrio assistido, inclinação até 30°.
- Aderência por piso (asfalto, grama, asfalto molhado) com derrapagem e queda.
- Energia (resistência física) com consumo, recuperação, cansaço e perda de desempenho.
- Quedas (colisão forte, perda de controle, aterrissagem), recuperação em 2,5 s, 3 corações.
- Modelo provisório do Andrew-Mike na BMX com pedalada animada (IK), rodas, guidão, inclinação e queda.
- Câmera de costas mostrando o ciclista inteiro, suavizada, sem atravessar paredes (SpringArm3D).
- HUD: retrato, corações, energia, velocidade, turbo, piso, mensagens, FPS, ajuda de controles.
- Pista de testes: avenida com prédios e postes, slalom, rampa, zonas de piso, praça, placa e caixa d'água de Red City.
- Shaders: Cel Shading, contorno de quadrinho, céu vermelho tempestuoso com relâmpagos.
- 41 testes automatizados (unidade + integração), todos passando na Godot 4.3 (headless, Linux).

**Não verificado ainda:** desempenho real (FPS) no Mac M4 e sensação de controle — dependem do seu teste.
