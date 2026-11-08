# Registro de alterações

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
